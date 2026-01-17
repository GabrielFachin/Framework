--[[
	- Lista de skills disponíveis
	- Cooldowns de skills
	- Runners ativos
	- Validação de cast
]]
	


local ServerStorage = game:GetService("ServerStorage")
local StateTable = require(ServerStorage.Modules.Combat.StateTable)

local CombatComponent = {}
CombatComponent.__index = CombatComponent

--[[
Inicializa o componente de combate na entidade
@param entity - Entidade dona do componente Entity, enviar EntityData
@param config - Configurações iniciais do componente TABLE { ChosenChar: string, Mode: string }
@return nova instância do CombatComponent CombatComponent
]]
function CombatComponent.new(entity, config)
	local self = setmetatable({}, CombatComponent)

	self.Entity = entity

	-- Skills disponíveis (carregadas depois)
	self.SkillsData = nil

	-- Cooldown de skills
	self.Cooldowns = {} -- [skillName] = timestamp

	-- Skills ativas (runners)
	self.ActiveSkills = {} -- [skillName] = {runner1, runner2, ...}

	-- Personagem e modo
	self.ChosenChar = config.ChosenChar or "Schema"
	self.Mode = config.Mode or "Base"

	--Estado de cast
	self.PlayerState = {
		name = nil,
		runner = nil
	}

	return self
end

--=============================================================================
--  SKILL DATA LOADING
--=============================================================================

--[[
Inicializa a pasta de skills, carrega dados e inicializa cooldowns
@return sucesso BOOLEAN
]]
function CombatComponent:LoadSkillsData() : boolean

	if not self:_LoadFolders() then return false end

	local skillsModule = self._formFolder:FindFirstChild("Skills")
		and self._formFolder.Skills:FindFirstChild("Skills")

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

--[[
Carrega as pastas de dados do personagem
@return sucesso BOOLEAN
]]
function CombatComponent:_LoadFolders() : boolean

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
--  SKILL GETTERS
--=============================================================================

--[[
Devolve o nome da skill no índice fornecido
@param index - índice da skill NUMBER
@return nome da skill STRING ou nil se não encontrada
]]
function CombatComponent:GetSkillName(index : number) : string?
	if not self.SkillsData then
		warn("[CombatComponent] SkillsData não carregado")
		return nil
	end

	return self.SkillsData[index]
end

--[[
Devevolve o script (não requirido) da skill no índice fornecido
@param index - índice da skill (opcional se fornecer name) NUMBER
@param name - nome da skill STRING (opcional, se fornecido, ignora index)
]]
function CombatComponent:GetSkillScript(index : number?, name : string?) : Instance?
	local charComp = self.Entity:GetComponent(self.Entity.ComponentKey.Character)
	if not charComp then return nil end

		local skillName = name or self:GetSkillName(index)
		if not skillName then 
			warn("[CombatComponent] GetSkillScript não recebeu um parametro!")
			 return nil end


	local skillScript = self._formFolder:FindFirstChild("Script")
		and self._formFolder.Script:FindFirstChild(skillName)

	return skillScript
end


--[[
Devevolve o módulo (requirido) da skill pelo nome ou index
@param skillName - nome da skill (opcional, se fornecer index) STRING
@param index - índice da skill NUMBER (opcional se fornecer name)
@return módulo da skill TABLE ou nil se não encontrado
]]
function CombatComponent:GetSkillData(skillName : string, index : number?) : any?
	local charComp = self.Entity:GetComponent(self.Entity.ComponentKey.Character)
	if not charComp or not charComp._formFolder then return nil end

	skillName = skillName or self:GetSkillName(index)
	if not skillName then
		warn("[CombatComponent] GetSkillData não recebeu um parametro!")
		return nil end

	local skillScript = charComp._formFolder:FindFirstChild("Script")
		and charComp._formFolder.Script:FindFirstChild(skillName)

	if not skillScript then return nil end

	local success, skillModule = pcall(require, skillScript)
	if not success or not skillModule then return nil end

	return skillModule
end

--=============================================================================
--  COOLDOWN
--=============================================================================


--[[
Checa se a skill está em cooldown
@param skillName - nome da skill STRING
@return está em cooldown BOOLEAN
]]
function CombatComponent:HasCooldown(skillName : string) : boolean
	return (self.Cooldowns[skillName] or 0) > tick()
end

--[[
Define o cooldown de uma skill
@param skillName - nome da skill STRING
@param customCooldown - cooldown customizado NUMBER (opcional, se não fornecido, busca no módulo da skill)
]]
function CombatComponent:SetCooldown(skillName : string, customCooldown : number?)
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

--[[
Devolve o tempo restante do cooldown de uma skill
@param skillName - nome da skill STRING
@return tempo restante do cooldown NUMBER
]]
function CombatComponent:GetCooldown(skillName : string) : number
	return math.max(0, (self.Cooldowns[skillName] or 0) - tick())
end


--[[
Reseta o cooldown de uma skill
@param skillName - nome da skill STRING
]]
function CombatComponent:ResetCooldown(skillName : string)
	self.Cooldowns[skillName] = 0
end

--[[
Reseta todos os cooldowns de skills registrados
]]
function CombatComponent:ResetAllCooldowns()
	for skillName in pairs(self.Cooldowns) do
		self.Cooldowns[skillName] = 0
	end
end

--=============================================================================
--  PLAYER STATE (Cast, GlobalCast, SelfCast, LockedCast)
--=============================================================================

--[[
Retorna o PlayerState atual
]]
function CombatComponent:GetPlayerState()
	return self.PlayerState
end

function CombatComponent:SetPlayerState(name,runner)

	if not self.PlayerState then self.PlayerState = {name = name, runner, runner} end

	self.PlayerState.name = name
	self.PlayerState.runner = runner
end

function CombatComponent:RemovePlayerState()
	self.PlayerState = nil
end


--[[
Cancelamento interno de skills buscando por estados do tipo SelfCast
@return sucesso BOOLEAN
]]
function CombatComponent:TrySelfCancel() : boolean
		
		if self.PlayerState and #self.PlayerState > 0 then
			-- Checa se é Self
			for _, v in pairs(StateTable.PlayerStates.Self) do
				if self.PlayerState.name == v.data.name then
					local runner = self.PlayerState.runner 
					if runner and typeof(runner) == "table" and runner.Stop then
						runner:Stop(true)
						return true
					end
				end
				return false -- Encontrou PlayerState mas não é Self
			end
		end
	
	return true -- Nenhum PlayerState ativo
end


--=============================================================================
--  VALIDAÇÃO
--=============================================================================

--[[
valida se a entidade pode continuar a ação
@return sucesso BOOLEAN
]]
function CombatComponent:CanContinue() : boolean

	--Busca por tag de impedimento
	local statusComp = self.Entity:HasComponent(self.Entity.ComponentKey.Status)
	
	--existem estados ativos?
	if statusComp then
		local rawState = self.Entity:GetActiveStates()
			if #rawState == 0 then
				return true 
			end

		--Existe alguma tag de silence?
		local tags = self.Entity.GetActiveTags()
		if tags["canCast"] == false then
			return false
		end
	end
	-- Checa se o estado de player atual é selfCancel
	for _, stateDef in pairs(StateTable.PlayerStates.Self) do
		if self.PlayerState.name == stateDef.data.name then
			return true
		end
	end
	
	return false
end


--=============================================================================
--  SKILLS E RUNNERS
--=============================================================================

--[[
Adiciona uma skill pra lista de habilidades ativas
@param skillName - nome da skill STRING
@param runner - instância do runner da skill TABLE
]]
function CombatComponent:AddActiveSkill(skillName : string, runner)
	
assert(typeof(skillName) == "string","[CombatComponent] skillName precisa ser string, recebeu " .. typeof(skillName))

	if not self.ActiveSkills[skillName] then
		self.ActiveSkills[skillName] = {}
	end
	table.insert(self.ActiveSkills[skillName], runner)
end

--[[
Remove uma skill da lista de habilidades ativas
@param skillName - nome da skill STRING
@param runner - instância do runner da skill TABLE
]]
function CombatComponent:RemoveActiveSkill(skillName : string, runner)
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

--[[
Retorna uma ou várias habilidades ativas, junto de seus runners responsáveis
@param skillName - nome da skill STRING (opcional, se fornecido, devolve só essa skill)
@return lista de runners TABLE ou tabela com todas as skills ativas TABLE
]]
function CombatComponent:GetActiveSkills(skillName : string?)
	if skillName then
		return self.ActiveSkills[skillName] or {}
	end
	return self.ActiveSkills
end

--[[
Retorna a quantidade de runners ativos para uma skill específica
@param skillName - nome da skill STRING
@return quantidade de runners NUMBER
]]
function CombatComponent:GetActiveSkillCount(skillName : string) : number
	print(skillName)
	local list = self.ActiveSkills[skillName]
	print(self.ActiveSkills)
	return list and #list or 0
end

--[[
Verifica se a skill especificada está ativa
@param skillName - nome da skill STRING
@return está ativa BOOLEAN
]]
function CombatComponent:HasActiveSkill(skillName : string) : boolean
	return self:GetActiveSkillCount(skillName) > 0
end


--[[
Para cada skill ativa, para todos os runners, chama o método Stop ou endSkill
@param cancel - se true, indica que a skill foi cancelada (opcional, padrão false) BOOLEAN
]]
function CombatComponent:StopAllActiveSkills(cancel : boolean?)
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
--  CHARACTER E FORMAS
--=============================================================================

function CombatComponent:SetChosenChar(Char)
 if self.ChosenChar == Char then return false end

    self.ChosenChar = Char

    -- Recarrega folders
    if not self:_LoadFolders() then
        return false
    end

    self:LoadSkillsData()

    -- Atualiza stats
    local stats = self.Entity.GetStats()
    self.Entity.SetSpeed(stats.Speed or 16)
    self.Entity.SetJumpForce(stats.JumpPower or 50)

    -- Atualiza HP
    local health = self.Entity:GetComponent(self.Entity.ComponentKey.Health)
    if health and stats.MaxHP then
        local ratio = health:GetHealthRatio()
        health.MaxHP = stats.MaxHP
        health:SetHP(stats.MaxHP * ratio) -- Mantém proporção
    end

    return true
end


function CombatComponent:GetChosenChar()
	return self.ChosenChar
end


function CombatComponent:SetCharMode(Mode)

    if self.Mode == Mode then return false end

    self.Mode = Mode

    -- Recarrega folders
    if not self:_LoadFolders() then
        return false
    end

    self:LoadSkillsData()

    -- Atualiza stats
    local stats = self.Entity.GetStats()
    self.Entity.SetSpeed(stats.Speed or 16)
    self.Entity.SetJumpForce(stats.JumpPower or 50)

    -- Atualiza HP
    local health = self.Entity:GetComponent(self.Entity.ComponentKey.Health)
    if health and stats.MaxHP then
        local ratio = health:GetHealthRatio()
        health.MaxHP = stats.MaxHP
        health:SetHP(stats.MaxHP * ratio) -- Mantém proporção
    end

    return true
end


function CombatComponent:GetCharMode()
	return self.Mode
end


--[[
Retorna as postas de forma e dados do personagem escolhido.
@return FormFolder, CharFolder
]]
function CombatComponent:GetCharFolders()
	return self._formFolder,self.charFolder
end

--=============================================================================
--  LIFECYCLE
--=============================================================================

--[[
Função de inicialização do componente, tenta carregar skills automaticamente
]]
function CombatComponent:OnAdded()
	-- Tenta carregar skills automaticamente
		self:LoadSkillsData()
end


--[[
Função de destruição do componente, para todas as skills ativas e limpa tabelas
]]
function CombatComponent:Destroy()
	self:StopAllActiveSkills(true)
	table.clear(self.Cooldowns)
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

	-- Active Skills
	AddActiveSkill = function(component, ...) return component:AddActiveSkill(...) end,
	RemoveActiveSkill = function(component, ...) return component:RemoveActiveSkill(...) end,
	GetActiveSkills = function(component, ...) return component:GetActiveSkills(...) end,
	GetActiveSkillCount = function(component,...) return component:GetActiveSkillCount(...) end,
	HasActiveSkill = function(component, ...) return component:HasActiveSkill(...) end,
	StopAllActiveSkills = function(component, ...) return component:StopAllActiveSkills(...) end,

	--Personagem/modo
	GetChosenChar = function(component,...) return component:GetChosenChar(...) end,
	SetChosenChar = function(component,...) return component:SetChosenChar(...) end,
	GetCharMode = function(component,...) return component:GetCharMode(...) end,
	SetCharMode = function(component,...) return component:SetCharMode(...) end,

	--Validação
	CanContinue = function(component,...) return component:CanContinue(...) end,
	TrySelfCancel = function(component,...) return component:TrySelfCancel(...) end,     

	--PlayerState
	GetPlayerState = function(component,...) return component:GetPlayerState(...)end,
	SetPlayerState = function(component,...) return component:SetPlayerState(...)end,
	RemovePlayerState = function(component,...) return component:RemovePlayerState(...)end,

	GetCharFolders = function(component,...) return component:GetCharFolders(...)end,

}

return {
	new = CombatComponent.new,
	ExposeAPI = ExposeAPI
}