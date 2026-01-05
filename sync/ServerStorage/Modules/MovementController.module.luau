--[[
	MovementController - Sistema centralizado de física de movimento
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local MovementController = {}
MovementController.__index = MovementController

--=============================================================================
--  STATE
--=============================================================================

-- Entidades rastreadas e seus objetos de física
-- Estrutura: [EntityCore] = { LinearVelocity, AngularVelocity, Attachment }
local physicsCache = {} 

local LAST_POSITIONS = {} -- [EntityCore] = {Pos = Vector3, Time = tick()}
local TOLERANCE_MULTIPLIER = 1.2 -- 20% de tolerância para lag

local heartbeatConnection = nil

-- Constantes de Configuração
local CONSTRAINT_ATTACHMENT_NAME = "MovementControllerAtt"
local MAX_FORCE_VEC = Vector3.new(100000, 100000, 100000) -- Força alta para garantir imobilização
local INFINITE_FORCE = math.huge


--=============================================================================
--  PHYSICS OBJECTS MANAGEMENT
--=============================================================================

--[[
Cria ou recupera os objetos de física (desativados por padrão)
]]
local function getOrCreatePhysicsObjects(root: BasePart)
	-- Verifica se já temos um attachment dedicado para evitar conflitos com outros sistemas
	local att = root:FindFirstChild(CONSTRAINT_ATTACHMENT_NAME)
	if not att then
		att = Instance.new("Attachment")
		att.Name = CONSTRAINT_ATTACHMENT_NAME
		att.Parent = root
	end

	-- LinearVelocity (Substituto moderno do BodyVelocity)
	-- Usado para zerar o movimento (Freeze)
	local lv = root:FindFirstChild("FreezeLinearVelocity")
	if not lv then
		lv = Instance.new("LinearVelocity")
		lv.Name = "FreezeLinearVelocity"
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.VectorVelocity = Vector3.zero -- Queremos parar o player
		lv.MaxForce = INFINITE_FORCE
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Attachment0 = att
		lv.Enabled = false -- Começa desligado
		lv.Parent = root
	end

	-- AngularVelocity (Substituto moderno do BodyAngularVelocity)
	-- Usado para impedir rotação física indesejada
	local av = root:FindFirstChild("FreezeAngularVelocity")
	if not av then
		av = Instance.new("AngularVelocity")
		av.Name = "FreezeAngularVelocity"
		av.AngularVelocity = Vector3.zero
		av.MaxTorque = INFINITE_FORCE
		av.RelativeTo = Enum.ActuatorRelativeTo.World
		av.Attachment0 = att
		av.Enabled = false -- Começa desligado
		av.Parent = root
	end

	return {
		LinearVelocity = lv,
		AngularVelocity = av,
		Attachment = att
	}
end

--[[
Limpa os objetos físicos da memória (usado no Untrack)
]]
local function destroyPhysicsObjects(cacheEntry)
	if not cacheEntry then return end
	
	if cacheEntry.LinearVelocity then cacheEntry.LinearVelocity:Destroy() end
	if cacheEntry.AngularVelocity then cacheEntry.AngularVelocity:Destroy() end
	if cacheEntry.Attachment then cacheEntry.Attachment:Destroy() end
end

--=============================================================================
--  PHYSICS APPLICATION
--=============================================================================

local function applyMovementRestrictions(entityCore, tags: {[string]: any})
	local physicsObjs = physicsCache[entityCore]
	if not physicsObjs then return end

	-- 1. Flags de controle
	local canMove = tags.canMove ~= false
	local canControl = tags.canControl ~= false

	-- 2. Wrappers
	local characterWrapper = entityCore:GetCharacterWrapper()
	local movementWrapper = entityCore:GetMovementWrapper()
	
	if not characterWrapper then return end
	local humanoid = entityCore:GetHumanoid()

	-- 3. Aplicação Lógica
	if humanoid then
		-- A. Controle de Rotação (AutoRotate do Humanoid é mais eficiente que física)
		humanoid.AutoRotate = canControl

		-- B. Controle de Movimento
		if canMove then
			-- LIBERA MOVIMENTO
			if physicsObjs.LinearVelocity.Enabled then
				physicsObjs.LinearVelocity.Enabled = false
				physicsObjs.AngularVelocity.Enabled = false
				humanoid.PlatformStand = false
				
				-- Restaura valores originais via wrapper
				if movementWrapper then
					local baseSpeed = entityCore:GetStat("Speed", 16)
					local baseJump = entityCore:GetStat("JumpForce", 50)
					entityCore:SetSpeed(baseSpeed)
					entityCore:SetJumpForce(baseJump)
				end
			end
		else
			-- BLOQUEIA MOVIMENTO (STUN/ROOT)
			if not physicsObjs.LinearVelocity.Enabled then
				-- Zera inputs do humanoid para evitar que ele tente lutar contra a física
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
				-- PlatformStand previne animações de "cair" ou física estranha de pulo
				humanoid.PlatformStand = true 
				
				-- Ativa as constraints para "ancorar" fisicamente no ar/chão sem usar Anchored=true
				physicsObjs.LinearVelocity.Enabled = true
				physicsObjs.AngularVelocity.Enabled = true
			end
		end
	else
		-- Lógica para NPCs sem Humanoid (Custom Physics)
		if canMove then
			physicsObjs.LinearVelocity.Enabled = false
			physicsObjs.AngularVelocity.Enabled = false
			if movementWrapper then
				local baseSpeed = entityCore:GetStat("Speed", 16)
				entityCore:SetSpeed(baseSpeed)
			end
		else
			physicsObjs.LinearVelocity.Enabled = true
			physicsObjs.AngularVelocity.Enabled = true
		end
	end
end

--=============================================================================
--  ANTI TP/SUPER SPEED
--=============================================================================

local function validateMovement(entityCore, root, dt)
    local lastData = LAST_POSITIONS[entityCore]
    local currentPos = root.Position
    local currentTime = tick()
    
    if not lastData then
        LAST_POSITIONS[entityCore] = {Pos = currentPos, Time = currentTime}
        return true -- Primeiro frame, ignora
    end

    -- 1. Validação de Speed/Teleport
    local distanceTraveled = (currentPos - lastData.Pos).Magnitude
    local maxSpeed = entityCore:GetStat("Speed", 16)
    
    -- Calcula a distância máxima teórica que ele poderia andar neste intervalo de tempo
    local maxDistanceAllowed = (maxSpeed * (currentTime - lastData.Time)) * TOLERANCE_MULTIPLIER + 5 
    
    -- Se ele andou muito mais do que o permitido
    if distanceTraveled > maxDistanceAllowed then
        -- É um dash legítimo? (Verifica se tem a tag de isDashing ou similar)
        local statusComp = entityCore:GetComponent(entityCore.ComponentKey.Status)
        local tags = statusComp and statusComp:GetActiveTags() or {}
        
        if not tags.isDashing and not tags.wasKnockedBack then
            warn("[AntiCheat] Speed/Teleport detectado em:", entityCore.ID)
            
            -- Punição: Rubberband (volta pra posição anterior válida)
            root.CFrame = CFrame.new(lastData.Pos)
            return false
        end
    end

    -- Atualiza última posição válida
    LAST_POSITIONS[entityCore] = {Pos = currentPos, Time = currentTime}
    return true
end

--=============================================================================
--  UPDATE LOOP
--=============================================================================

local function onHeartbeat()
	for entityCore, _ in pairs(physicsCache) do
		if not entityCore.Active then
			MovementController.Untrack(entityCore)
			continue
		end

			local root = entityCore:GetRoot()
            if root then
                validateMovement(entityCore, root, dt) -- Valida antes de aplicar física
            end

		local statusComp = entityCore:GetComponent(entityCore.ComponentKey.Status)
		if statusComp then
			-- Só recalcula se as tags mudaram (otimização sugerida)
			-- Idealmente o StatusComponent avisaria quando mudou, mas por polling:
			local tags = statusComp:GetActiveTags()
			applyMovementRestrictions(entityCore, tags)
		end

	end
end

--=============================================================================
--  PUBLIC API
--=============================================================================

function MovementController.Track(entityCore)
	if physicsCache[entityCore] then return end

	local wrapper = entityCore:GetCharacterWrapper()
	if not wrapper then return end
	
	local root = wrapper:GetRoot()
	if not root then return end

	-- Cria/Cacheia os objetos físicos imediatamente ao rastrear
	physicsCache[entityCore] = getOrCreatePhysicsObjects(root)

	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
		print("[MovementController] Loop iniciado")
	end
end

function MovementController.Untrack(entityCore)
	if physicsCache[entityCore] then
		destroyPhysicsObjects(physicsCache[entityCore])
		physicsCache[entityCore] = nil
	end

	-- Desliga o loop se vazio para economizar recursos
	if next(physicsCache) == nil and heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
		print("[MovementController] Loop parado (vazio)")
	end
end

function MovementController.GetStats()
	local count = 0
	for _ in pairs(physicsCache) do count += 1 end
	return { TotalTracked = count, Running = heartbeatConnection ~= nil }
end

-- Limpeza automática ao sair
Players.PlayerRemoving:Connect(function(player)
	-- A lógica de remover via DataManager.Remove já deve chamar o Destroy do componente,
	-- que por sua vez deve chamar MovementController.Untrack.
	-- Mantemos isso apenas como fallback de segurança.
end)

return MovementController