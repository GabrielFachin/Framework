--[[
	CharacterComponent - Gerencia dados específicos de personagem
	
	RESPONSABILIDADES:
	- Personagem escolhido (Schema, Ashley, etc)
	- Forma/Mode (Base, Awakened, etc)
	- Stats (MaxHP, Speed, etc)
	- Referências ao modelo
	- Caminhos de dados
	
	NÃO FAZ:
	- Skills (SkillComponent)
	- Status (StatusComponent)
	- Armas (WeaponComponent)
]]

local ServerStorage = game:GetService("ServerStorage")

local CharacterComponent = {}
CharacterComponent.__index = CharacterComponent

function CharacterComponent.new(entity, config)
	local self = setmetatable({}, CharacterComponent)

	self.Entity = entity

	-- Personagem
	self.ChosenChar = config.ChosenChar or "Schema"
	self.Mode = config.Mode or "Base"

	-- Referências ao modelo do Roblox
	self.Character = nil
	self.Root = nil
	self.Humanoid = nil

	-- Stats base
	self.BaseWalkSpeed = 16
	self.BaseJumpPower = 50

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

function CharacterComponent:_LoadFolders()
	local charFolder = ServerStorage.Modules.CharData:FindFirstChild(self.ChosenChar)
	if not charFolder then
		warn("[CharacterComponent] Personagem não encontrado:", self.ChosenChar)
		return false
	end

	local formFolder = charFolder:FindFirstChild(self.Mode)
	if not formFolder then
		warn("[CharacterComponent] Forma não encontrada:", self.Mode)
		return false
	end

	self.charFolder = charFolder
	self._formFolder = formFolder

	return true
end

--=============================================================================
--  STATS
--=============================================================================

function CharacterComponent:GetStats()
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

function CharacterComponent:SetCharacter(characterModel)
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
	self.BaseWalkSpeed = stats.Speed or 16
	self.BaseJumpPower = stats.JumpPower or 50

	if self.Humanoid then
		self.Humanoid.WalkSpeed = self.BaseWalkSpeed
		self.Humanoid.JumpPower = self.BaseJumpPower
	end

	-- Atualiza HP do HealthComponent
	local health = self.Entity:GetComponent("Health")
	if health and stats.MaxHP then
		health.MaxHP = stats.MaxHP
		health:SetHP(stats.MaxHP)
	end

	return true
end

function CharacterComponent:GetCharacter()
	return self.Character
end

function CharacterComponent:GetRoot()
	return self.Root
end

function CharacterComponent:GetHumanoid()
	return self.Humanoid
end

--=============================================================================
--  FORM CHANGE
--=============================================================================

function CharacterComponent:ChangeForm(newMode)
	if self.Mode == newMode then return false end

	self.Mode = newMode

	-- Recarrega folders
	if not self:_LoadFolders() then
		return false
	end

	-- Recarrega skills se tiver SkillComponent
	local skillComp = self.Entity:GetComponent("Skills")
	if skillComp then
		skillComp:LoadSkillsData()
	end

	-- Atualiza stats
	local stats = self:GetStats()
	self.BaseWalkSpeed = stats.Speed or 16
	self.BaseJumpPower = stats.JumpPower or 50

	if self.Humanoid then
		self.Humanoid.WalkSpeed = self.BaseWalkSpeed
		self.Humanoid.JumpPower = self.BaseJumpPower
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
--  VELOCITY (wrapper do Humanoid)
--=============================================================================

function CharacterComponent:SetWalkSpeed(speed)
	if self.Humanoid then
		self.Humanoid.WalkSpeed = speed
	end
end

function CharacterComponent:GetWalkSpeed()
	return self.Humanoid and self.Humanoid.WalkSpeed or self.BaseWalkSpeed
end

function CharacterComponent:SetJumpPower(power)
	if self.Humanoid then
		self.Humanoid.JumpPower = power
	end
end

function CharacterComponent:GetJumpPower()
	return self.Humanoid and self.Humanoid.JumpPower or self.BaseJumpPower
end

function CharacterComponent:ResetVelocities()
	if self.Humanoid then
		self.Humanoid.WalkSpeed = self.BaseWalkSpeed
		self.Humanoid.JumpPower = self.BaseJumpPower
	end
end

--=============================================================================
--  UTILITY
--=============================================================================

function CharacterComponent:IsAlive()
	return self.Humanoid and self.Humanoid.Health > 0
end

function CharacterComponent:GetPosition()
	return self.Root and self.Root.Position or Vector3.zero
end

function CharacterComponent:GetCFrame()
	return self.Root and self.Root.CFrame or CFrame.identity
end

function CharacterComponent:Teleport(position)
	if self.Root then
		self.Root.CFrame = CFrame.new(position)
	end
end

--=============================================================================
--  LIFECYCLE
--=============================================================================

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