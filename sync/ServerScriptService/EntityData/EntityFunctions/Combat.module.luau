local Combat = {}
Combat.__index = Combat

function Combat.new(entity, characterModule)
	local self = setmetatable({}, Combat)
	
	self.Entity = entity
	self.Character = characterModule
	self.Cooldowns = {}
	self.StatusCooldowns = {}
	self.ActiveSkills = {}
	
	return self
end

-- Inicializa cooldowns para todas as skills
function Combat:initializeCooldowns(skillsData)
	if not skillsData then return end
	
	for _, skillName in pairs(skillsData) do
		self.Cooldowns[skillName] = 0
	end
end

-- Pega o nome da skill
function Combat:getSkillName(index)
	local skillsData = self.Character.SkillsData
	if not skillsData then
		warn("SkillsData não carregado")
		return nil
	end

	local skillName = skillsData[index]
	if not skillName then
		warn("Skill não encontrada no índice", index)
		return nil
	end
	return skillName
end

-- Pega Skill da entidade usando o index
function Combat:GetSkill(index)
	local skillsData = self.Character.SkillsData
	if not skillsData then
		warn("SkillsData não carregado")
		return nil
	end

	local skillName = self:getSkillName(index)
	local formFolder = self.Character._formFolder

	-- Busca o script da skill na pasta Script
	local skillScript = formFolder:FindFirstChild("Script") and formFolder.Script:FindFirstChild(skillName)

	if not skillScript then
		warn("Script da skill '" .. skillName .. "' não encontrado")
		return nil
	end

	return skillScript
end

-- Adiciona a skill atual na lista de skills/runners ativos
function Combat:addSkill(name, runner)
	if not self.ActiveSkills[name] then
		self.ActiveSkills[name] = {}
	end
	table.insert(self.ActiveSkills[name], runner)
end

-- Remove a skill recebida da lista de skills/runners ativos
function Combat:removeSkill(name, runner)
	local list = self.ActiveSkills[name]
	if not list then return end

	for i = #list, 1, -1 do
		if list[i] == runner then
			table.remove(list)
			break
		end
	end
end

-- Confere o cooldown no módulo da skill
function Combat:getSkillCooldown(skillName)
	local formFolder = self.Character._formFolder
	local skillModuleInstance = formFolder:FindFirstChild("Script") and formFolder.Script:FindFirstChild(skillName)
	if not skillModuleInstance then
		warn("Módulo da skill '" .. skillName .. "' não encontrado na pasta Script")
		return nil
	end

	local success, skillModule = pcall(require, skillModuleInstance)
	if not success or not skillModule or not skillModule.data then
		warn("Erro ao requerer módulo da skill '" .. skillName .. "' ou .data ausente")
		return nil
	end

	local cd = skillModule.data.cooldown
	if not cd then
		warn("Cooldown não definido no .data da skill '" .. skillName .. "'")
		return nil
	end

	return cd
end

function Combat:hasCooldown(skillName)
	local currentTime = tick()
	return (self.Cooldowns[skillName] or 0) > currentTime
end

function Combat:setCooldown(skillName, customCooldown)
	local cd = customCooldown or self:getSkillCooldown(skillName)
	self.Cooldowns[skillName] = tick() + cd
end

-- Mostra o cooldown "limpo" da skill
function Combat:getCooldown(skillName)
	return (self.Cooldowns[skillName] or 0) - tick()
end

function Combat:setStatusCooldown(name, duration)
	self.StatusCooldowns[name] = tick() + duration
end

function Combat:getStatusCooldown(name)
	local cooldownEnd = self.StatusCooldowns[name] or 0
	return math.max(0, cooldownEnd - tick())
end

function Combat:hasStatusCooldown(name)
	return self:getStatusCooldown(name) > 0
end

return Combat
