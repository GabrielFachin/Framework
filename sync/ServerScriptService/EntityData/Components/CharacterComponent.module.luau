--[[                           COMPONENTE VITAL                                                      ]]

local ServerScript = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local EntityWrapper = require(ServerScript.EntityData.EntityWrapper)
local DB = require(ServerStorage.DataBase.CharacterDatabase)

local CharacterComponent = {}
CharacterComponent.__index = CharacterComponent
--[[
Inicializa o componente de personagem na entidade
@param entity - Entidade dona do componente Entity, enviar EntityData
@param config - desnecessário, mantido por consistência com outros componentes TABLE
@return nova instância do CharacterComponent CharacterComponent
]]
function CharacterComponent.new(entity, config)
	local self = setmetatable({}, CharacterComponent)

	self.Entity = entity
	self.Instance = entity.Instance

	self.CharacterWrap = nil

	return self
end

--=============================================================================
--  STATS
--=============================================================================

--[[
Retorna a tabela de Stats do personagem
@return tabela de Stats TABLE
]]
function CharacterComponent:GetStats() : {}
	if not self.Entity:HasComponent(self.Entity.ComponentKey.Combat) then return {Speed = 16, JumpForce = 20} end
	local char = self.Entity:GetChosenChar()
	local mode = self.Entity:GetCharMode()
	local charData = DB[char][mode]

	return charData
end

--[[
Retorna um status especifico do char sendo usado
@param statName STRING
]]
function CharacterComponent:GetStat(statName : string, default)
	local charData = self:GetStats()

	local result = charData["Stats"][statName] or charData[statName] or default
	return result
end
--=============================================================================
--  CHARACTER MODEL
--=============================================================================

--[[
Setta o characterModel humanoid da entidade
@param characterModel - modelo do personagem MODEL
@return sucesso BOOLEAN
]]
function CharacterComponent:SetEntity(Entity) : boolean

	if self.CharacterWrap then return false end

	local model 
	local root
	local humanoid

	if typeof(Entity) == "table"  then
		model = Entity.Model
		humanoid = model.Humanoid
		root = model:FindFirstChild("HumanoidRootPart") or Entity
	else
		model = Entity
		root = model:FindFirstChildWhichIsA("BasePart") or model.PrimaryPart
		humanoid = nil
	end

	self.CharacterWrap = EntityWrapper.CreateCharacter({
	humanoid,
	root,
	})

	return true
end

--[[
Retorna o modelo da entidade
@return modelo do personagem MODEL
]]
function CharacterComponent:GetModel()
	return self.entity.Instance
end

--[[
Retorna o wrapper de dados de char da entidade
@return Wrapper, tabela de funcs, TABLE
]]
function CharacterComponent:GetCharacterWrapper()
	return self.CharacterWrap
end


--[[
Retorna o root part da entidade
]]
function CharacterComponent:GetRoot()
	return self.CharacterWrap and self.CharacterWrap:GetRoot()

end

--[[
Retorna o Humanoid da entidade
]]
function CharacterComponent:GetHumanoid()
	return self.CharacterWrap and self.CharacterWrap.GetHumanoid and self.CharacterWrap:GetHumanoid()
end



--=============================================================================
--  UTILITY
--=============================================================================

--[[
Devolve a posição do root part da entidade
@return posição VECTOR3
]]
function CharacterComponent:GetPosition() : Vector3
	return self.Root and self.Root.Position or Vector3.zero
end

--[[
Devolve o CFrame do root part da entidade
@return CFrame do root part CFRAME
]]
function CharacterComponent:GetCFrame()
	return self.Root and self.Root.CFrame or CFrame.identity
end

--[[
Teleporta o personagem para uma posição específica
@param position - posição para teleportar VECTOR3
]]
function CharacterComponent:Teleport(position : Vector3) 
	if self.Root then
		self.Root.CFrame = CFrame.new(position)
	end
end

--=============================================================================
--  LIFECYCLE
--=============================================================================

--[[
Função de destruição do componente, limpa referências
]]
function CharacterComponent:Destroy()
	self.Entity = nil
	self.Character = nil
	self.Root = nil
	self.Humanoid = nil
end



function CharacterComponent:OnAdded()
	
end

--=============================================================================
--  API EXPOSE
--=============================================================================

local ExposeAPI = {
	-- Stats
	GetStats = function(component) return component:GetStats() end,
	GetStat = function(component, ...) return component:GetStat(...) end,

	-- Character Model
	SetEntity = function(component, ...) return component:SetEntity(...) end,
	GetCharacterWrapper = function(component, ...) return component:GetCharacterWrapper(...) end,
	GetModel = function(component,...) return component:GetModel (...) end,
	GetRoot = function(component) return component:GetRoot() end,
	GetHumanoid = function(component) return component:GetHumanoid() end,

	-- Utility
	GetPosition = function(component) return component:GetPosition() end,
	GetCFrame = function(component) return component:GetCFrame() end,
	Teleport = function(component, ...) return component:Teleport(...) end,
}

return {
	new = CharacterComponent.new,
	ExposeAPI = ExposeAPI
}