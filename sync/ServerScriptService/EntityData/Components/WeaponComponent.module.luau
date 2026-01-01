--[[
	- Equipar/desequipar armas
	- Hitbox wrapper
	- HitOrigin
]]

local RS = game:GetService("ReplicatedStorage")
local Storage = game:GetService("ServerStorage")
local HitboxWrapper = require(Storage.Modules.Combat.HitboxWrapper)

local WeaponComponent = {}
WeaponComponent.__index = WeaponComponent

--[[
Inicializa o componente de arma na entidade
@param entity - Entidade dona do componente Entity, enviar EntityData
@param config - Configurações iniciais do componente TABLE { WeaponName: string }
@return nova instância do WeaponComponent WeaponComponent
]]
function WeaponComponent.new(entity, config)
	local self = setmetatable({}, WeaponComponent)

	self.Entity = entity

	-- Arma atual
	self.Weapon = nil
	self.WeaponName = config.WeaponName or nil

	-- Hitbox
	self.HitOrigin = nil
	self.Hitbox = nil

	-- Equipa arma se fornecida
	if self.WeaponName then
		task.defer(function()
			self:EquipWeapon(self.WeaponName)
		end)
	end

	return self
end

--=============================================================================
--  WEAPON EQUIP
--=============================================================================

--[[
Equipar uma arma ao personagem
@param weaponName - nome da arma a ser equipada STRING
@return sucesso BOOLEAN
]]
function WeaponComponent:EquipWeapon(weaponName : string) : boolean
	-- Remove arma antiga
	self:UnequipWeapon()

	-- Busca personagem
	local charComp = self.Entity:GetComponent("Character")
	if not charComp or not charComp.Character then
		warn("[WeaponComponent] entidade sem CharacterModule, EquipWeapon falhou")
		return false
	end

	local char = charComp.Character
	local chosenChar = charComp.ChosenChar

	-- Busca arma na pasta de assets
	local weaponFolder = RS.Assets.Weapons:FindFirstChild(chosenChar)
	if not weaponFolder then
		warn("[WeaponComponent] Pasta de armas não encontrada:", chosenChar)
		return false
	end

	local weaponModel = weaponFolder:FindFirstChild(weaponName)
	if not weaponModel then
		warn("[WeaponComponent] Arma não encontrada:", weaponName)
		return false
	end

	-- Clona arma
	local weaponClone = weaponModel:Clone()
	weaponClone.Name = weaponModel.Name
	weaponClone.Parent = char

	local handle = weaponClone:FindFirstChild("Handle")
	if not handle then
		warn("[WeaponComponent] Arma sem Handle")
		weaponClone:Destroy()
		return false
	end

	-- Determina ponto de attach
	local attachTo = self:_GetAttachPoint(weaponModel, charComp)
	local charAttach = char:FindFirstChild(attachTo)

	if not charAttach then
		warn("[WeaponComponent] Ponto de attach não encontrado:", attachTo)
		weaponClone:Destroy()
		return false
	end

	-- CFrame da arma
	local cframeValue = weaponClone:FindFirstChild("Value")
	local weaponCFrame = cframeValue and cframeValue.Value or CFrame.identity

	-- Cria Motor6D
	local motor = Instance.new("Motor6D")
	motor.Part0 = charAttach
	motor.Part1 = handle
	motor.C1 = weaponCFrame
	motor.Parent = handle

	-- Salva referências
	self.Weapon = weaponClone
	self.WeaponName = weaponName
	self.HitOrigin = weaponClone:FindFirstChild("hitOrigin")

	-- Cria wrapper de hitbox
	self.Hitbox = HitboxWrapper.new(self.Entity)

	return true
end

--[[
Retorna o ponto de attach para a arma seguindo a prioridade:
Arma > Personagem > fallback default (right arm)
@param weaponModel - modelo da arma
@param charComp - componente de personagem
@return nome do ponto de attach STRING
]]
function WeaponComponent:_GetAttachPoint(weaponModel : Instance, charComp) : string
	-- Prioridade: Arma > Personagem > Padrão

	-- 1. Busca na arma
	local attachValue = weaponModel:FindFirstChild("AttachTo")
	if attachValue and attachValue.Value then
		return attachValue.Value
	end

	-- 2. Busca no personagem
	local Stats = charComp:GetStats()
	if Stats.attachTo then
		return Stats.attachTo
	end

	-- 3. Padrão
	return "Right Arm"
end

--[[
Desequipar a arma atual
]]
function WeaponComponent:UnequipWeapon()
	if self.Weapon then
		self.Weapon:Destroy()
		self.Weapon = nil
	end

	self.WeaponName = nil
	self.HitOrigin = nil
	self.Hitbox = nil
end

--=============================================================================
--  GETTERS
--=============================================================================

--[[
Retorna o modelo da arma equipada
]]
function WeaponComponent:GetWeapon()
	return self.Weapon
end

--[[
Retorna o nome da arma equipada
]]
function WeaponComponent:GetWeaponName()
	return self.WeaponName
end


--[[
Retorna a origem do hitbox da arma equipada
]]
function WeaponComponent:GetHitOrigin()
	return self.HitOrigin
end

--[[
Retorna o hitbox da arma equipada
]]
function WeaponComponent:GetHitbox()
	return self.Hitbox
end

--[[
Verifica se a entidade possui uma arma equipada
@return possui arma BOOLEAN
]]
function WeaponComponent:HasWeapon()
	return self.Weapon ~= nil
end

--=============================================================================
--  UTILITY
--=============================================================================

--[[
Retorna a posição da arma equipada
@return posição VECTOR3
]]
function WeaponComponent:GetWeaponPosition() : Vector3
	return self.Weapon and self.Weapon:GetPivot().Position or Vector3.zero
end

--[[
Retorna o CFrame da arma equipada
@return CFrame
]]
function WeaponComponent:GetWeaponCFrame() : CFrame
	return self.Weapon and self.Weapon:GetPivot() or CFrame.identity
end

--=============================================================================
--  LIFECYCLE
--=============================================================================

--[[
Destrói o componente de armas, removendo a arma equipada e limpando referências
]]
function WeaponComponent:Destroy()
	self:UnequipWeapon()
	self.Entity = nil
end

--=============================================================================
--  API EXPOSE
--=============================================================================

local ExposeAPI = {
	EquipWeapon = function(component, ...) return component:EquipWeapon(...) end,
	UnequipWeapon = function(component) return component:UnequipWeapon() end,
	GetWeapon = function(component) return component:GetWeapon() end,
	GetWeaponName = function(component) return component:GetWeaponName() end,
	GetHitOrigin = function(component) return component:GetHitOrigin() end,
	GetHitbox = function(component) return component:GetHitbox() end,
	HasWeapon = function(component) return component:HasWeapon() end,
}

return {
	new = WeaponComponent.new,
	ExposeAPI = ExposeAPI
}