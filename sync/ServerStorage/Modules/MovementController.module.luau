--[[
	MovementController - Sistema centralizado de física de movimento
	
	Centro de verdade para todas as restrições de movimento baseadas em tags de status.
	Gerencia automaticamente BodyVelocity/BodyAngularVelocity para congelamento.
	Compatível com Humanoids e entidades customizadas via EntityWrapper.
	
	Funcionalidades:
	- Tracking automático de entidades registradas
	- Aplicação de restrições baseadas em tags (canMove, canControl)
	- Pool de BodyObjects para performance
	- Limpeza automática na remoção de entidades
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local MovementController = {}
MovementController.__index = MovementController

--=============================================================================
--  STATE
--=============================================================================

-- Entidades sendo rastreadas
local trackedEntities = {} -- [EntityCore] = true

-- Pool de BodyObjects por entidade
local bodyObjectsPool = {} -- [EntityCore] = {BodyVelocity, BodyAngularVelocity}

-- Conexão do Heartbeat
local heartbeatConnection = nil

--=============================================================================
--  BODY OBJECTS MANAGEMENT
--=============================================================================

--[[
Cria objetos de física para congelar movimento
@param root - Root part da entidade BASEPART
@return tabela com BodyVelocity e BodyAngularVelocity TABLE
]]
local function createFreezeObjects(root : BasePart) : {Instance}
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.P = 10000
	bodyVelocity.Parent = root

	local bodyAngular = Instance.new("BodyAngularVelocity")
	bodyAngular.MaxTorque = Vector3.new(4000, 4000, 4000)
	bodyAngular.AngularVelocity = Vector3.zero
	bodyAngular.P = 10000
	bodyAngular.Parent = root

	return {bodyVelocity, bodyAngular}
end

--[[
Remove objetos de congelamento de uma entidade
@param entityCore - EntityCore da entidade ENTITYCORE
]]
local function removeFreezeObjects(entityCore)
	local objects = bodyObjectsPool[entityCore]
	if not objects then return end

	for _, obj in ipairs(objects) do
		if obj and obj.Parent then
			obj:Destroy()
		end
	end

	bodyObjectsPool[entityCore] = nil
end

--=============================================================================
--  PHYSICS APPLICATION
--=============================================================================
--[[
Aplica restrições de movimento baseadas nas tags de status
@param entityCore - EntityCore da entidade ENTITYCORE
@param tags - Tags ativas do StatusComponent TABLE
]]
local function applyMovementRestrictions(entityCore, tags : {[string]: any})
	-- Extrai flags de movimento
	local canMove = tags.canMove ~= false
	local canControl = tags.canControl ~= false

	-- Pega wrappers
	local characterWrapper = entityCore:GetCharacterWrapper()
	local movementWrapper = entityCore:GetMovementWrapper()
	
	if not characterWrapper then return end

	local root = characterWrapper:GetRoot()
	if not root then return end

	local humanoid = characterWrapper:GetHumanoid()

	-- ===== HUMANOID =====
	if humanoid then
		-- Controle de rotação
		humanoid.AutoRotate = canControl

		if canMove then
			-- Remove restrições
			removeFreezeObjects(entityCore)

			-- Restaura velocidades via wrapper
			if movementWrapper then
				local baseSpeed = entityCore:GetStat("Speed", 16)
				local baseJump = entityCore:GetStat("JumpForce", 50)
				
				movementWrapper:SetSpeed(baseSpeed)
				movementWrapper:SetJumpForce(baseJump)
			end

			humanoid.PlatformStand = false

		else
			-- Aplica congelamento
			if not bodyObjectsPool[entityCore] then
				bodyObjectsPool[entityCore] = createFreezeObjects(root)
			end

			-- Zera velocidades
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.PlatformStand = true
		end

	-- ===== NPC CUSTOMIZADO =====
	else
		if canMove then
			removeFreezeObjects(entityCore)
			
			-- Restaura velocidade via wrapper
			if movementWrapper then
				local baseSpeed = entityCore:GetStat("Speed", 16)
				movementWrapper:SetSpeed(baseSpeed)
			end

		else
			-- Aplica congelamento
			if not bodyObjectsPool[entityCore] then
				bodyObjectsPool[entityCore] = createFreezeObjects(root)
			end
		end
	end
end

--=============================================================================
--  UPDATE LOOP
--=============================================================================

--[[
Loop principal de atualização (Heartbeat)
]]
local function onHeartbeat()
	for entityCore in pairs(trackedEntities) do
		-- Valida existência
		if not entityCore.Active then
			MovementController.Untrack(entityCore)
			continue
		end

		-- Pega StatusComponent
		local statusComp = entityCore:GetComponent(entityCore.ComponentKey.Status)
		if not statusComp then continue end

		-- Pega tags ativas
		local tags = statusComp:GetActiveTags()

		-- Aplica restrições
		applyMovementRestrictions(entityCore, tags)
	end
end

--=============================================================================
--  PUBLIC API
--=============================================================================

--[[
Registra uma entidade para tracking de movimento
@param entityCore - EntityCore da entidade ENTITYCORE
]]
function MovementController.Track(entityCore)
	if trackedEntities[entityCore] then return end

	trackedEntities[entityCore] = true

	-- Inicia Heartbeat se não estiver rodando
	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
		print("[MovementController] Iniciado")
	end
end

--[[
Remove uma entidade do tracking
@param entityCore - EntityCore da entidade ENTITYCORE
]]
function MovementController.Untrack(entityCore)
	trackedEntities[entityCore] = nil
	removeFreezeObjects(entityCore)

	-- Desconecta se não há mais entidades
	if not next(trackedEntities) and heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
		print("[MovementController] Parado (sem entidades)")
	end
end

--[[
Remove todas as entidades e para o controller
]]
function MovementController.StopAll()
	for entityCore in pairs(trackedEntities) do
		removeFreezeObjects(entityCore)
	end

	table.clear(trackedEntities)

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	print("[MovementController] Parado manualmente")
end

--[[
Força atualização imediata de uma entidade específica
@param entityCore - EntityCore da entidade ENTITYCORE
]]
function MovementController.ForceUpdate(entityCore)
	if not trackedEntities[entityCore] then
		warn("[MovementController] Tentativa de atualizar entidade não rastreada")
		return
	end

	local statusComp = entityCore:GetComponent(entityCore.ComponentKey.Status)
	if not statusComp then return end

	local tags = statusComp:GetActiveTags()
	applyMovementRestrictions(entityCore, tags)
end

--[[
Retorna estatísticas de debug
@return tabela com estatísticas TABLE
]]
function MovementController.GetStats() : {[string]: any}
	local totalEntities = 0
	local entitiesFrozen = 0

	for entityCore in pairs(trackedEntities) do
		totalEntities += 1
		if bodyObjectsPool[entityCore] then
			entitiesFrozen += 1
		end
	end

	return {
		totalTracked = totalEntities,
		frozen = entitiesFrozen,
		active = totalEntities - entitiesFrozen,
		isRunning = heartbeatConnection ~= nil
	}
end

--[[
Retorna se uma entidade está sendo rastreada
@param entityCore - EntityCore da entidade ENTITYCORE
@return está sendo rastreada BOOLEAN
]]
function MovementController.IsTracking(entityCore) : boolean
	return trackedEntities[entityCore] == true
end

--=============================================================================
--  CLEANUP
--=============================================================================

-- Limpeza quando jogador sai
Players.PlayerRemoving:Connect(function(player)
	local playerID = player:GetAttribute("EntityID")
	if not playerID then return end

	-- Busca EntityCore do jogador
	local DataManager = require(game.ServerScriptService.EntityData.DataManager)
	local entityCore = DataManager.Get(playerID)

	if entityCore then
		MovementController.Untrack(entityCore)
	end
end)

--=============================================================================
--  DEBUG
--=============================================================================

function MovementController.PrintStats()
	local stats = MovementController.GetStats()
	print("=== MovementController Stats ===")
	print("Total Tracked:", stats.totalTracked)
	print("Frozen:", stats.frozen)
	print("Active:", stats.active)
	print("Is Running:", stats.isRunning)
	print("===============================")
end

return MovementController