--[[
	MovementComponent - Gerencia movimento e direção
]]


local Storage = game:GetService("ServerStorage")
local MovementController = require(Storage.Modules.MovementController)
local EntityWrapper = require(Storage.Modules.EntityWrapper)

local MovementComponent = {}
MovementComponent.__index = MovementComponent

--[[[
Inicializa o componente de movimento na entidade
@param entity - Entidade dona do componente Entity, enviar EntityData
@param config - desnecessário, mantido por consistência com outros componentes TABLE
@return nova instância do MovementComponent MovementComponent
]]
function MovementComponent.new(entity, config)
	local self = setmetatable({}, MovementComponent)

	self.Entity = entity

	-- Direção
	self.Direction = Vector3.zero
	self.LastDirection = Vector3.zero

	self.MovementWrap = nil

	-- Tracking
	self._tracked = false

	return self
end

--=============================================================================
--  DIRECTION
--=============================================================================

--[[
Define a direção do movimento 
 - nota, isso não altera diretamente a direção da entidade, apenas atualiza pra direção mais recente em relação entidade/mundo
@param direction - direção do movimento Vector3
]]
function MovementComponent:SetDirection(direction)
	if direction.Magnitude > 0 then
		self.LastDirection = self.Direction
		self.Direction = direction.Unit
	else
		self.Direction = Vector3.zero
	end
end

--[[
Retorna a direção atual do movimento
@return direção do movimento Vector3
]]
function MovementComponent:GetDirection()
	return self.Direction
end

--[[
Retorna a penúltima direção válida do movimento (não a mais recente!)
@return penúltima direção do movimento Vector3
]]
function MovementComponent:GetLastDirection() 
	return self.LastDirection
end

--[[
Verifica se a entidade teve mudanças significativas na direção do movimento
@return está se movendo BOOLEAN
]]
function MovementComponent:IsMoving() : boolean
	return self.Direction.Magnitude > 0.01
end

--=============================================================================
--  MOVEMENT CONTROLLER INTEGRATION
--=============================================================================

--[[
Se inscreve no controller de movimento (responsável por aplicar restrições de movimento)
]]
function MovementComponent:StartTracking()
	if self._tracked then return end

	--Movement controller ainda não foi atualizado pra suportar entidades genéricas, atualizar!
	MovementController.Track(self.Entity)
	self._tracked = true
end

--[[
Se desinscreve do controller de movimento
]]
function MovementComponent:StopTracking()
	if not self._tracked then return end

	local Storage = game:GetService("ServerStorage")
	local MovementController = require(Storage.Modules.MovementController)

	MovementController.Untrack(self.Entity)
	self._tracked = false
end

--=============================================================================
--  UTILITY
--=============================================================================

--[[
Retorna a velocidade de movimento base da entidade
@return velocidade de movimento NUMBER
]]

function MovementComponent:GetSpeed()

end


function MovementComponent:SetSpeed(speed)

end


function MovementComponent:GetJumpForce()

end


function MovementComponent:SetJumpForce(jumpForce)

end


--=============================================================================
--  LIFECYCLE
--=============================================================================

--[[
Função de inicialização do componente, inicia tracking pro MovementController automaticamente
]]
function MovementComponent:OnAdded()

end


function MovementComponent:SetMovement()

	if self.MovementWrap then return false end 
		local wrapper = self.Entity:GetWrapper()
		local speed = self.Entity:GetStat("Speed")
		local jumpForce = self.Entity:GetStat("JumpForce")
		self.CharacterWrap = EntityWrapper.CreateMovement({
		wrapper,
		speed,
		jumpForce
	})

	return true
end

--[[
Função de destruição do componente, para tracking e limpa referências]]
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