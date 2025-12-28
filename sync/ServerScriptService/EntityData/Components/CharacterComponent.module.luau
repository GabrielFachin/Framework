--[[
	CharacterComponent - Gerencia dados específicos de entidade
	- Stats (MaxHP, Speed, etc)
	- Referências ao modelo
	- Caminhos de dados
]]

local ServerStorage = game:GetService("ServerStorage")

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

	-- Referências ao modelo do Roblox (futuramente irá ser integrado com um wrapper de humanoid/npc custom)
	self.Character = nil
	self.Root = nil
	self.Humanoid = nil

	-- Stats base
	self.BaseSpeed = 16
	self.BaseJump = 50

	-- Caminhos de dados (cache)
	self.charFolder = nil
	self._formFolder = nil

	-- Carrega folders
	self:_LoadFolders()

	return self
end

--=============================================================================
--  FOLDER LOADING
--=============================================================================

--[[
Carrega as pastas de dados do personagem
@return sucesso BOOLEAN
]]
function CharacterComponent:_LoadFolders() : boolean
	local combatComp = self.Entity:GetComponent("Combat")
	if not combatComp then
		warn("[CharacterComponent] entidade não tem componente de skill:", self.Entity)
		return false
	end

	local charFolder = ServerStorage.Modules.CharData:FindFirstChild(combatComp.chosenChar)
	if not charFolder then
		warn("[CharacterComponent] Personagem não encontrado:", combatComp.chosenChar)
		return false
	end

	local formFolder = charFolder:FindFirstChild(combatComp.mode)
	if not formFolder then
		warn("[CharacterComponent] Forma não encontrada:", combatComp.mode)
		return false
	end

	self.charFolder = charFolder
	self._formFolder = formFolder

	return true
end

--=============================================================================
--  STATS
--=============================================================================

--[[
Retorna a tabela de stats do personagem
@return tabela de stats TABLE
]]
function CharacterComponent:GetStats() : {}
	if not self._formFolder then return {} end

	local dataFolder = self._formFolder:FindFirstChild("Data")
	if not dataFolder then return {} end

	local baseModule = dataFolder:FindFirstChild("Base")
	if not baseModule then return {} end

	local success, charData = pcall(require, baseModule)
	if not success then return {} end

	return charData
end

function CharacterComponent:GetStat(statName, default)
	local stats = self:GetStats()
	return stats[statName] or default
end

--=============================================================================
--  CHARACTER MODEL
--=============================================================================

--[[
Setta o characterModel humanoid da entidade
@param characterModel - modelo do personagem MODEL
@return sucesso BOOLEAN
]]
function CharacterComponent:SetCharacter(characterModel) : boolean
	if not characterModel then return false end

	self.Character = characterModel
	self.Root = characterModel:FindFirstChild("HumanoidRootPart")
		or characterModel.PrimaryPart
		or characterModel:FindFirstChildWhichIsA("BasePart")

	self.Humanoid = characterModel:FindFirstChildWhichIsA("Humanoid")

	-- Atualiza referências no Entity também
	self.Entity.Character = characterModel
	self.Entity.Root = self.Root
	self.Entity.Humanoid = self.Humanoid

	-- Carrega stats e aplica
	local stats = self:GetStats()
	self.BaseSpeed = stats.Speed or 16
	self.BaseJump = stats.JumpPower or 50

	if self.Humanoid then
		self.Humanoid.WalkSpeed = self.BaseSpeed
		self.Humanoid.JumpPower = self.BaseJump
	end

	-- Atualiza HP do HealthComponent
	local health = self.Entity:GetComponent("Health")
	if health and stats.MaxHP then
		health.MaxHP = stats.MaxHP
		health:SetHP(stats.MaxHP)
	end

	return true
end

--[[
Retorna o modelo do personagem da entidade
@return modelo do personagem MODEL
]]
function CharacterComponent:GetCharacter()
	return self.Character
end


--[[
Retorna o root part da entidade
]]
function CharacterComponent:GetRoot()
	return self.Root
end

--[[
Retorna o Humanoid da entidade
]]
function CharacterComponent:GetHumanoid()
	return self.Humanoid
end

--=============================================================================
--  FORM CHANGE
--=============================================================================

--[[
Altera a forma (mode) do personagem
@param newMode - nova forma STRING
]]
function CharacterComponent:ChangeForm(newMode : string) : boolean
	if self.Mode == newMode then return false end

	self.Mode = newMode

	-- Recarrega folders
	if not self:_LoadFolders() then
		return false
	end

	-- Recarrega skills se tiver CombatComponent
	local combatComp = self.Entity:GetComponent("Combat")
	if combatComp then
		combatComp:LoadSkillsData()
	end

	-- Atualiza stats
	local stats = self:GetStats()
	self.BaseSpeed = stats.Speed or 16
	self.BaseJump = stats.JumpPower or 50

	if self.Humanoid then
		self.Humanoid.WalkSpeed = self.BaseSpeed
		self.Humanoid.JumpPower = self.BaseJump
	end

	-- Atualiza HP
	local health = self.Entity:GetComponent("Health")
	if health and stats.MaxHP then
		local ratio = health:GetHealthRatio()
		health.MaxHP = stats.MaxHP
		health:SetHP(stats.MaxHP * ratio) -- Mantém proporção
	end

	return true
end

--=============================================================================
--  VELOCITY 
--=============================================================================
--[[
Define a velocidade de caminhada da entidade
@param speed - nova velocidade NUMBER
]]
function CharacterComponent:SetWalkSpeed(speed : number)
	if self.Humanoid then
		self.baseSpeed = speed
		self.Humanoid.WalkSpeed = speed
	end
end


--[[
Retorna a velocidade de caminhada do humanoid
@return velocidade de caminhada NUMBER
]]
function CharacterComponent:GetWalkSpeed() : number
	return self.Humanoid and self.Humanoid.WalkSpeed or self.BaseSpeed
end

--[[
Define o poder de pulo da entidade
]]
function CharacterComponent:SetJumpPower(power : number)
	if self.Humanoid then
		self.JumpPower = power
		self.Humanoid.JumpPower = power
	end
end

--[[
Retorna o poder de pulo da entidade
@return poder de pulo NUMBER
]]
function CharacterComponent:GetJumpPower() : number
	return self.Humanoid and self.Humanoid.JumpPower or self.BaseJump
end

--[[
Reseta as velocidades do humanoid para os valores padrão
]]
function CharacterComponent:ResetVelocities()
	if self.Humanoid then
		self.Humanoid.WalkSpeed = self.BaseSpeed
		self.Humanoid.JumpPower = self.BaseJump
	end
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
	self.charFolder = nil
	self._formFolder = nil
end

--=============================================================================
--  API EXPOSE
--=============================================================================

local ExposeAPI = {
	-- Stats
	GetStats = function(component) return component:GetStats() end,
	GetStat = function(component, ...) return component:GetStat(...) end,

	-- Character Model
	SetCharacter = function(component, ...) return component:SetCharacter(...) end,
	GetCharacter = function(component) return component:GetCharacter() end,
	GetRoot = function(component) return component:GetRoot() end,
	GetHumanoid = function(component) return component:GetHumanoid() end,

	-- Form
	ChangeForm = function(component, ...) return component:ChangeForm(...) end,

	-- Velocity
	SetWalkSpeed = function(component, ...) return component:SetWalkSpeed(...) end,
	GetWalkSpeed = function(component) return component:GetWalkSpeed() end,
	SetJumpPower = function(component, ...) return component:SetJumpPower(...) end,
	GetJumpPower = function(component) return component:GetJumpPower() end,
	ResetVelocities = function(component) return component:ResetVelocities() end,

	-- Utility
	GetPosition = function(component) return component:GetPosition() end,
	GetCFrame = function(component) return component:GetCFrame() end,
	Teleport = function(component, ...) return component:Teleport(...) end,
}

return {
	new = CharacterComponent.new,
	ExposeAPI = ExposeAPI
}