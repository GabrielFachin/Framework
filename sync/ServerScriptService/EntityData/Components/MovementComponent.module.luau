--[[
	MovementComponent - Gerencia movimento e direção
	
	RESPONSABILIDADES:
	- Direção atual
	- Integração com MovementController
	
	NÃO FAZ:
	- Tags de movimento (StatusComponent)
	- Velocidades base (CharacterComponent)
	- Aplicação física (MovementController global)
]]

local MovementComponent = {}
MovementComponent.__index = MovementComponent

function MovementComponent.new(entity, config)
	local self = setmetatable({}, MovementComponent)

	self.Entity = entity

	-- Direção
	self.Direction = Vector3.zero
	self.LastDirection = Vector3.zero

	-- Tracking
	self._tracked = false

	return self
end

--=============================================================================
--  DIRECTION
--=============================================================================

function MovementComponent:SetDirection(direction)
	if direction.Magnitude > 0 then
		self.LastDirection = self.Direction
		self.Direction = direction.Unit
	else
		self.Direction = Vector3.zero
	end
end

function MovementComponent:GetDirection()
	return self.Direction
end

function MovementComponent:GetLastDirection()
	return self.LastDirection
end

function MovementComponent:IsMoving()
	return self.Direction.Magnitude > 0.01
end

--=============================================================================
--  MOVEMENT CONTROLLER INTEGRATION
--=============================================================================

function MovementComponent:StartTracking()
	if self._tracked then return end

	local Storage = game:GetService("ServerStorage")
	local MovementController = require(Storage.Modules.MovementController)

	-- MovementController espera um objeto com estrutura específica
	-- Vamos criar um wrapper compatível
	local wrapper = {
		CombatData = {
			Status = self.Entity:GetComponent("Status")
		},
		Root = self.Entity.Root,
		Humanoid = self.Entity.Humanoid,
		BaseWalkSpeed = 16,
		BaseJumpPower = 50
	}

	-- Pega velocidades do CharacterComponent se existir
	local charComp = self.Entity:GetComponent("Character")
	if charComp then
		wrapper.BaseWalkSpeed = charComp.BaseWalkSpeed
		wrapper.BaseJumpPower = charComp.BaseJumpPower
	end

	MovementController.Track(wrapper)
	self._tracked = true
	self._wrapper = wrapper
end

function MovementComponent:StopTracking()
	if not self._tracked then return end

	local Storage = game:GetService("ServerStorage")
	local MovementController = require(Storage.Modules.MovementController)

	MovementController.Untrack(self._wrapper)
	self._tracked = false
	self._wrapper = nil
end

--=============================================================================
--  UTILITY
--=============================================================================

function MovementComponent:CanMove()
	local status = self.Entity:GetComponent("Status")
	if not status then return true end

	return status:CanPerformAction("Move")
end

function MovementComponent:GetSpeed()
	local charComp = self.Entity:GetComponent("Character")
	if charComp then
		return charComp:GetWalkSpeed()
	end
	return 16
end

--=============================================================================
--  LIFECYCLE
--=============================================================================

function MovementComponent:OnAdded()
	-- Inicia tracking automaticamente
	task.defer(function()
		self:StartTracking()
	end)
end

function MovementComponent:Destroy()
	self:StopTracking()
	self.Entity = nil
end

--=============================================================================
--  API EXPOSE
--=============================================================================

local ExposeAPI = {
	SetDirection = function(component, ...) return component:SetDirection(...) end,
	GetDirection = function(component) return component:GetDirection() end,
	GetLastDirection = function(component) return component:GetLastDirection() end,
	IsMoving = function(component) return component:IsMoving() end,
	CanMove = function(component) return component:CanMove() end,
	GetSpeed = function(component) return component:GetSpeed() end,
}

return {
	new = MovementComponent.new,
	ExposeAPI = ExposeAPI
}