--[[
	SkillComponent - Gerencia skills, cooldowns, runners ativos
	
	RESPONSABILIDADES:
	- Lista de skills disponíveis
	- Cooldowns de skills
	- Runners ativos
	- Validação de cast
	
	NÃO FAZ:
	- Lógica de skills (SkillRunner)
	- Stats de personagem (CharacterComponent)
	- Tags de cast (StatusComponent)
]]

local ServerStorage = game:GetService("ServerStorage")

local SkillComponent = {}
SkillComponent.__index = SkillComponent

function SkillComponent.new(entity, config)
	local self = setmetatable({}, SkillComponent)

	self.Entity = entity

	-- Skills disponíveis (carregadas depois)
	self.SkillsData = config.SkillsData or nil

	-- Cooldowns
	self.Cooldowns = {} -- [skillName] = timestamp
	self.StatusCooldowns = {} -- [statusName] = timestamp

	-- Skills ativas (runners)
	self.ActiveSkills = {} -- [skillName] = {runner1, runner2, ...}

	-- Configuração
	self.ChosenChar = config.ChosenChar or "Schema"
	self.Mode = config.Mode or "Base"

	return self
end

--=============================================================================
--  SKILL DATA LOADING
--=============================================================================

function SkillComponent:LoadSkillsData()
	local charComp = self.Entity:GetComponent("Character")
	if not charComp then
		warn("[SkillComponent] Precisa de CharacterComponent pra carregar skills")
		return false
	end

	local charFolder = ServerStorage.Modules.CharData:FindFirstChild(charComp.ChosenChar)
	if not charFolder then return false end

	local formFolder = charFolder:FindFirstChild(charComp.Mode)
	if not formFolder then return false end

	local skillsModule = formFolder:FindFirstChild("Skills")
		and formFolder.Skills:FindFirstChild("Skills")

	if not skillsModule then return false end

	local success, skillsData = pcall(require, skillsModule)
	if not success then return false end

	self.SkillsData = skillsData

	-- Inicializa cooldowns
	for _, skillName in pairs(skillsData) do
		self.Cooldowns[skillName] = 0
	end

	return true
end

--=============================================================================
--  SKILL GETTERS
--=============================================================================

function SkillComponent:GetSkillName(index)
	if not self.SkillsData then
		warn("[SkillComponent] SkillsData não carregado")
		return nil
	end

	return self.SkillsData[index]
end

function SkillComponent:GetSkillScript(index)
	local charComp = self.Entity:GetComponent("Character")
	if not charComp then return nil end

	local skillName = self:GetSkillName(index)
	if not skillName then return nil end

	local skillScript = charComp._formFolder:FindFirstChild("Script")
		and charComp._formFolder.Script:FindFirstChild(skillName)

	return skillScript
end

function SkillComponent:GetSkillData(skillName)
	local charComp = self.Entity:GetComponent("Character")
	if not charComp or not charComp._formFolder then return nil end

	local skillScript = charComp._formFolder:FindFirstChild("Script")
		and charComp._formFolder.Script:FindFirstChild(skillName)

	if not skillScript then return nil end

	local success, skillModule = pcall(require, skillScript)
	if not success or not skillModule then return nil end

	return skillModule
end

--=============================================================================
--  COOLDOWN SYSTEM
--=============================================================================

function SkillComponent:HasCooldown(skillName)
	return (self.Cooldowns[skillName] or 0) > tick()
end

function SkillComponent:SetCooldown(skillName, customCooldown)
	local cd = customCooldown

	-- Se não forneceu cooldown customizado, busca no módulo
	if not cd then
		local skillData = self:GetSkillData(skillName)
		if skillData and skillData.data then
			cd = skillData.data.cooldown
		end
	end

	if cd then
		self.Cooldowns[skillName] = tick() + cd
	end
end

function SkillComponent:GetCooldown(skillName)
	return math.max(0, (self.Cooldowns[skillName] or 0) - tick())
end

function SkillComponent:ResetCooldown(skillName)
	self.Cooldowns[skillName] = 0
end

function SkillComponent:ResetAllCooldowns()
	for skillName in pairs(self.Cooldowns) do
		self.Cooldowns[skillName] = 0
	end
end

--=============================================================================
--  STATUS COOLDOWN
--=============================================================================

function SkillComponent:HasStatusCooldown(name)
	return (self.StatusCooldowns[name] or 0) > tick()
end

function SkillComponent:SetStatusCooldown(name, duration)
	self.StatusCooldowns[name] = tick() + duration
end

function SkillComponent:GetStatusCooldown(name)
	return math.max(0, (self.StatusCooldowns[name] or 0) - tick())
end

--=============================================================================
--  ACTIVE SKILLS (Runners)
--=============================================================================

function SkillComponent:AddActiveSkill(skillName, runner)
	if not self.ActiveSkills[skillName] then
		self.ActiveSkills[skillName] = {}
	end
	table.insert(self.ActiveSkills[skillName], runner)
end

function SkillComponent:RemoveActiveSkill(skillName, runner)
	local list = self.ActiveSkills[skillName]
	if not list then return end

	for i = #list, 1, -1 do
		if list[i] == runner then
			table.remove(list, i)
			break
		end
	end

	-- Remove lista se vazia
	if #list == 0 then
		self.ActiveSkills[skillName] = nil
	end
end

function SkillComponent:GetActiveSkills(skillName)
	if skillName then
		return self.ActiveSkills[skillName] or {}
	end
	return self.ActiveSkills
end

function SkillComponent:GetActiveSkillCount(skillName)
	local list = self.ActiveSkills[skillName]
	return list and #list or 0
end

function SkillComponent:HasActiveSkill(skillName)
	return self:GetActiveSkillCount(skillName) > 0
end

function SkillComponent:StopAllActiveSkills(cancel)
	for skillName, runners in pairs(self.ActiveSkills) do
		for _, runner in ipairs(runners) do
			if runner.Stop then
				runner:Stop(cancel or false)
			elseif runner.endSkill then
				runner:endSkill(cancel or false)
			end
		end
	end
	table.clear(self.ActiveSkills)
end

--=============================================================================
--  VALIDATION
--=============================================================================

function SkillComponent:CanCastSkill(skillName)
	-- Checa cooldown
	if self:HasCooldown(skillName) then
		return false, "cooldown"
	end

	-- Checa se pode castar (via StatusComponent)
	local status = self.Entity:GetComponent("Status")
	if status and not status:CanPerformAction("Cast") then
		return false, "silenced"
	end

	return true
end

--=============================================================================
--  LIFECYCLE
--=============================================================================

function SkillComponent:OnAdded()
	-- Tenta carregar skills automaticamente
	task.defer(function()
		self:LoadSkillsData()
	end)
end

function SkillComponent:Destroy()
	self:StopAllActiveSkills(true)
	table.clear(self.Cooldowns)
	table.clear(self.StatusCooldowns)
	table.clear(self.ActiveSkills)
	self.Entity = nil
end

--=============================================================================
--  API EXPOSE
--=============================================================================

local ExposeAPI = {
	-- Skills
	GetSkillName = function(component, ...) return component:GetSkillName(...) end,
	GetSkillScript = function(component, ...) return component:GetSkillScript(...) end,
	GetSkillData = function(component, ...) return component:GetSkillData(...) end,

	-- Cooldowns
	HasCooldown = function(component, ...) return component:HasCooldown(...) end,
	SetCooldown = function(component, ...) return component:SetCooldown(...) end,
	GetCooldown = function(component, ...) return component:GetCooldown(...) end,
	ResetCooldown = function(component, ...) return component:ResetCooldown(...) end,

	-- Status Cooldowns
	HasStatusCooldown = function(component, ...) return component:HasStatusCooldown(...) end,
	SetStatusCooldown = function(component, ...) return component:SetStatusCooldown(...) end,
	GetStatusCooldown = function(component, ...) return component:GetStatusCooldown(...) end,

	-- Active Skills
	AddActiveSkill = function(component, ...) return component:AddActiveSkill(...) end,
	RemoveActiveSkill = function(component, ...) return component:RemoveActiveSkill(...) end,
	GetActiveSkills = function(component, ...) return component:GetActiveSkills(...) end,
	HasActiveSkill = function(component, ...) return component:HasActiveSkill(...) end,
	StopAllActiveSkills = function(component, ...) return component:StopAllActiveSkills(...) end,

	-- Validation
	CanCastSkill = function(component, ...) return component:CanCastSkill(...) end,
}

return {
	new = SkillComponent.new,
	ExposeAPI = ExposeAPI
}