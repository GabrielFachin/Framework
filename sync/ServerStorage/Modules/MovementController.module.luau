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
-- Estrutura: [entityCore] = { LinearVelocity, AngularVelocity, Attachment }
local physicsCache = {} 

local LAST_POSITIONS = {} -- [entityCore] = {Pos = Vector3, Time = tick()}
local TOLERANCE_MULTIPLIER = 1.2 -- 20% de tolerância para lag

local heartbeatConnection = nil

-- Constantes de Configuração
local CONSTRAINT_ATTACHMENT_NAME = "MovementControllerAtt"
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

	-- LinearVelocity 
	-- Impede/zera movimento
	local lv = root:FindFirstChild("FreezeLinearVelocity")
	if not lv then
		lv = Instance.new("LinearVelocity")
		lv.Name = "FreezeLinearVelocity"
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.VectorVelocity = Vector3.zero 
		lv.MaxForce = INFINITE_FORCE
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Attachment0 = att
		lv.Enabled = false -- Começa desligado
		lv.Parent = root
	end

	-- AngularVelocity 
	-- Impede rotação
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

	-- Flags de controle
	local canMove = tags.canMove ~= false
	local canControl = tags.canControl ~= false

	-- Wrappers (apenas pra validação de existênia de funções)
	local characterWrapper = entityCore:GetCharacterWrapper()
	local movementWrapper = entityCore:GetMovementWrapper()
	
	if not characterWrapper then return end
	local humanoid = entityCore:GetHumanoid()

	-- Aplicação Lógica
	if humanoid then
		-- Controle de Rotação
		humanoid.AutoRotate = canControl

		-- Controle de Movimento
		if canMove then
			-- LIBERA MOVIMENTO
			if physicsObjs.LinearVelocity.Enabled then
				physicsObjs.LinearVelocity.Enabled = false
				physicsObjs.AngularVelocity.Enabled = false
				humanoid.PlatformStand = false
				
				-- Restaura valores originais
				if movementWrapper then
					local baseSpeed = entityCore.GetStat("Speed", 16)
					local baseJump = entityCore.GetStat("JumpForce", 50)
					entityCore.SetSpeed(baseSpeed)
					entityCore.SetJumpForce(baseJump)
				end
			end
		else
			-- BLOQUEIA MOVIMENTO
			if not physicsObjs.LinearVelocity.Enabled then
				-- Zera inputs
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
				-- PlatformStand
				humanoid.PlatformStand = true 
				
				-- Ativa as constraints para ancorar artificialmente
				physicsObjs.LinearVelocity.Enabled = true
				physicsObjs.AngularVelocity.Enabled = true
			end
		end
	else
		-- NPCS
		if canMove then
			physicsObjs.LinearVelocity.Enabled = false
			physicsObjs.AngularVelocity.Enabled = false
			if movementWrapper then
				local baseSpeed = entityCore.GetStat("Speed", 16)
				entityCore.SetSpeed(baseSpeed)
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
        return true -- ignora primeiro frame
    end


    local distanceTraveled = (currentPos - lastData.Pos).Magnitude
    local maxSpeed = entityCore.GetStat("Speed", 16)
    
    -- Calcula a distância máxima que o player poderia andar nesse tempo
    local maxDistanceAllowed = (maxSpeed * (currentTime - lastData.Time)) * TOLERANCE_MULTIPLIER + 5 
    
    -- Se ele andou mais do que o permitido
    if distanceTraveled > maxDistanceAllowed then
        -- Tem tag de permissão? 
        local statusComp = entityCore:GetComponent(entityCore.ComponentKey.Status)
        local tags = statusComp and entityCore:GetActiveTags() or {}
        
		--Se não tem tag, então:
        if not tags.isDashing then
            warn("[AntiCheat] Comportamento suspeito:", entityCore)
            
        	--Rubberband
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

local function onHeartbeat(dt)
	for entityCore, _ in pairs(physicsCache) do
		if not entityCore.Active then
			MovementController.Untrack(entityCore)
			continue
		end

			local root = entityCore:GetRoot()
            if root then
                validateMovement(entityCore, root, dt) -- Valida antes de aplicar física
            end

			local tags = entityCore.GetActiveTags()
			applyMovementRestrictions(entityCore, tags)

	end
end

--=============================================================================
--  PUBLIC API
--=============================================================================

function MovementController.Track(entityCore)
	if physicsCache[entityCore] then return end

	local wrapper = entityCore:GetCharacterWrapper()
	if not wrapper then return end
	
	local root = entityCore:GetRoot()
	if not root then return end

	-- Armazena o ID ao iniciar tracker
	physicsCache[entityCore] = getOrCreatePhysicsObjects(root)

	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		onHeartbeat(dt)
		end)
	end
end

function MovementController.Untrack(entityCore)
	if physicsCache[entityCore] then
		destroyPhysicsObjects(physicsCache[entityCore])
		physicsCache[entityCore] = nil
	end

	-- Desliga o loop se não existem entidades para dar track
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
	-- A lógica de remover via DataManager.Remove já chama o Destroy do componente,
	-- que por sua vez deve chamar MovementController.Untrack.
	-- Mantemos isso apenas como fallback de segurança.
end)

return MovementController