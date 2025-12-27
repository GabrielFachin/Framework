--[[
    StatusComponent.module.lua
    Componente para gerenciar status (buffs, debuffs, estados) em uma entidade.
]]


local ServerStorage = game:GetService("ServerStorage")
local StateTable = require(ServerStorage.Modules.Combat.StateTable)

local StatusComponent = {}
StatusComponent.__index = StatusComponent

function StatusComponent.new(entity, config)
	local self = setmetatable({}, StatusComponent)
	
	self.Entity = entity
	
	-- Statuses ativos
	self.Statuses = {
		status = {}, -- Buffs/debuffs 
		state = {}   -- Estados 
	}
	
	-- Cache de tags combinadas
	self._cachedTags = nil
	self._tagsDirty = true
	
	-- Cache de regras de imunidade
	self._immunityRules = nil
	
	return self
end

--=============================================================================
--  STATUS APPLICATION
--=============================================================================

--[[
Aplica um status à entidade
@param statusData - Dados do status TABLE
@param duration - Duração do status NUMBER (opcional, pode ser definido em statusData)
@param sourceSkill - SkillRunner responsável pela skill que aplicou o status ANY (opcional)
@param ID - ID único do status STRING (opcional)
@return ID do status STRING ou nil se não aplicado]]
function StatusComponent:Apply(statusData : {}, duration : number?, sourceSkill : any?, ID : string?) : string?
	-- Gera ID único se não fornecido
	if not ID then
		ID = self:generateUniqueId(sourceSkill and sourceSkill.skillName or "Generic")
	end
	
	-- Prepara dados
	local data = table.clone(statusData)
	data.ID = ID
	data.StatusComponent = self
	
	local meta = data.data
	if not meta or not meta.name then
		warn("[StatusComponent] Status sem nome ou .data")
		return nil
	end
	
	-- Determina se é estado ou status
	local isState = StateTable:IsState(meta)
	local group = isState and self.Statuses.state or self.Statuses.status
	
	-- Verifica cooldown (se aplicável)
	if meta.cooldown and meta.cooldown > 0 and sourceSkill then
		local sourceEntity = sourceSkill.ED -- EntityData
		if sourceEntity and sourceEntity.hasStatusCooldown then
			if sourceEntity:hasStatusCooldown(meta.name) then
				return nil -- Em cooldown
			end
			sourceEntity:setStatusCooldown(meta.name, meta.cooldown)
		end
	end
	
	-- ===== STACK NA MESMA INSTÂNCIA =====
	if meta.stackable and meta.stackOnSelf then
		local existing = group[meta.name]
		if existing then
			if existing.counter >= (meta.maxStacks or math.huge) then
				return ID -- Limite atingido
			end
			
			if existing.runner then
				existing.runner.elapsedTime = 0 -- Reset timer
				if existing.runner.Recast then
					existing.runner:Recast()
				end
			end
			return ID
		end
		
		-- Cria novo runner
		local runner = self:_CreateRunner(data, meta.name, duration)
		group[meta.name] = {
			data = data,
			counter = 1,
			runner = runner,
			sourceSkill = sourceSkill,
			ID = ID
		}
		
		self:_MarkTagsDirty()
		return ID
	end
	
	-- ===== STACK EM INSTÂNCIAS DIFERENTES =====
	if meta.stackable and not meta.stackOnSelf then
		local list = group[meta.name] or {}
		if #list >= (meta.maxStacks or math.huge) then
			return nil -- Limite atingido
		end
		
		local runner = self:_CreateRunner(data, meta.name, duration)
		table.insert(list, {
			data = data,
			runner = runner,
			sourceSkill = sourceSkill,
			ID = ID
		})
		
		group[meta.name] = list
		self:_MarkTagsDirty()
		return ID
	end
	
	-- ===== EXCLUSIVO (substitui outros da mesma categoria) =====
	if meta.exclusive then
		for name, entry in pairs(group) do
			local entryMeta = entry.data and entry.data.data
			if entryMeta and entryMeta.category == meta.category then
				self:Remove(name)
			end
		end
	end
	
	-- ===== STATUS ÚNICO =====
	local runner = self:_CreateRunner(data, meta.name, duration)
	group[meta.name] = {
		data = data,
		runner = runner,
		sourceSkill = sourceSkill,
		ID = ID
	}
	
	self:_MarkTagsDirty()
	return ID
end

--[[
Cria um SkillRunner para o status
@param data - Dados do status TABLE
@param name - Nome do status STRING
@param duration - Duração do status NUMBER (opcional)
@return SkillRunner criado SkillRunner
]]
function StatusComponent:_CreateRunner(data : {[string]: any}, name : string, duration : number?)
	local SkillRunner = require(game.ServerScriptService.Modules.SkillRunner)
	
	-- Injeta duração se fornecida
	if duration then
		data.data.duration = duration
	end
	
	-- Cria runner (precisa de TPD/Entity - compatibilidade)
	local targetEntity = self.Entity._core and self.Entity or self.Entity.Entity
	local runner = SkillRunner.new(data, targetEntity, name)
	
	-- Callback de finalização
	runner.onFinish = function()
		self:_OnRunnerFinished(name, runner)
	end
	
	runner:start()
	return runner
end

--=============================================================================
--  STATUS REMOVAL
--=============================================================================

--[[
Remove um status completamente pelo nome
@param name - Nome do status STRING
]]
function StatusComponent:Remove(name : string)
	for _, group in pairs(self.Statuses) do
		local entry = group[name]
		if not entry then continue end
		
		-- Single runner
		if entry.runner then
			entry.runner:endSkill(true)
		-- Multiple runners
		elseif type(entry) == "table" then
			for _, item in ipairs(entry) do
				if item.runner then
					item.runner:endSkill(true)
				end
			end
		end
		
		group[name] = nil
		self:_MarkTagsDirty()
	end
end


--[[
RemoveAmount
@param name - Nome do status
@param amount - Quantidade de instâncias a serem removidas
Remove uma quantidade específica de instâncias de um status por nome
]]

function StatusComponent:RemoveAmount(name: string, amount: number): boolean
	if amount <= 0 then
		return false
	end
	local removed = false

	-- busca por status
	local group = self.Statuses.status
	local entry = group[name]
	if not entry then
		return false
	end

	--Remoção de stacks na mesma instância
	if entry.runner and entry.runner.counter then
		entry.runner.counter -= amount
		removed = true

		if entry.runner.counter <= 0 then
			entry.runner:endSkill(true)
			group[name] = nil
		end

	--Remoção de múltiplas instâncias
	elseif type(entry) == "table" then
		local toRemove = math.min(amount, #entry)

		for i = 1, toRemove do
			local item = table.remove(entry,1)
			if item.runner then
				item.runner:endSkill(true)
			end
		end

		if #entry == 0 then
			group[name] = nil
		end

		removed = toRemove > 0
	end

	if removed then
		self:_MarkTagsDirty()
	end

	return removed
end

--[[
RemoveByID
@param id - ID único do status STRING
@return sucesso BOOLEAN
Remove um status completamente pelo ID único
]]
function StatusComponent:RemoveByID(id : string) : boolean
	local removed = false
	
	for groupName, group in pairs(self.Statuses) do
		if groupName == "state" then
			for name, entry in pairs(group) do
				if entry.ID == id then
					self:Remove(name)
					removed = true
				end
			end
		elseif groupName == "status" then
			for name, list in pairs(group) do
				-- Single entry
				if list.ID == id then
					self:Remove(name)
					removed = true
				-- Multiple entries
				elseif type(list) == "table" and #list > 0 then
					for i = #list, 1, -1 do
						if list[i].ID == id then
							if list[i].runner then
								list[i].runner:Stop(true)
							end
							table.remove(list, i)
							removed = true
						end
					end
					if #list == 0 then
						group[name] = nil
					end
				end
			end
		end
	end
	
	if removed then
		self:_MarkTagsDirty()
	end
	
	return removed
end

--[[
Callback injetavel para a func de limpeza do runner
@param name - Nome do status STRING
@param runner - SkillRunner que finalizou SkillRunner
]]
function StatusComponent:_OnRunnerFinished(name : string, runner)
	local list = self.Statuses.status[name]
	if not list then return end
	
	-- Single runner
	if list.runner then
		self:Remove(name)
		return
	end
	
	-- Multiple runners
	local newList = {}
	for _, entry in ipairs(list) do
		if entry.runner ~= runner then
			table.insert(newList, entry)
		end
	end
	
	if #newList > 0 then
		self.Statuses.status[name] = newList
	else
		self.Statuses.status[name] = nil
	end
	
	self:_MarkTagsDirty()
end

--=============================================================================
--  TAGS SYSTEM
--=============================================================================

--[[
Obtém as tags ativas combinadas da entidade
@return tabela de tags TABLE]]
function StatusComponent:GetActiveTags() : { [string]: any }
	if not self._tagsDirty and self._cachedTags then
		return self._cachedTags
	end
	
	local merged = {}
	
	for _, group in pairs(self.Statuses) do
		for _, entry in pairs(group) do
			local entries = (entry.runner or entry.data) and {entry} or entry
			
			for _, e in ipairs(entries) do
				local tags = e.data.data.tags or {}
				for k, v in pairs(tags) do
					if v == false then
						merged[k] = false
					elseif merged[k] ~= false then
						merged[k] = v
					end
				end
			end
		end
	end
	
	self._cachedTags = merged
	self._tagsDirty = false
	
	return merged
end

function StatusComponent:_MarkTagsDirty()
	self._tagsDirty = true
end

--=============================================================================
--  HIT VALIDATION
--=============================================================================

--[[
Valida se um ataque pode afetar a entidade baseado em suas tags de imunidade
@param source - Fonte do ataque (geralmente um ED) ANY
@param flags - Flags/tags fornecidas para interações envolvendo StatusTable, obrigatório mas pode ser {}
@return sucesso BOOLEAN, razão STRING (nome da imunidade que bloqueou o hit)]]
function StatusComponent:ValidateHit(source : any, flags : {string}) : (boolean, string?)
	local targetTags = self:GetActiveTags()
	local immunityRules = self._immunityRules or self:_InitImmunityRules()
	
	for immunityName, rule in pairs(immunityRules) do
		if targetTags[immunityName] then
			local allowed = false
			
			for _, flag in ipairs(flags or {}) do
				if table.find(rule.bypassableBy, flag) then
					allowed = true
					break
				end
			end
			
			if not allowed then
				return false, immunityName
			end
		end
	end
	
	return true
end

--[[
Função interna!
Inicializa as regras de imunidade baseadas na StateTable
@return tabela de regras TABLE
]]
function StatusComponent:_InitImmunityRules()
	local rules = {}
	
	for name, def in pairs(StateTable.Status) do
		local data = def.data or def
		local tags = data.tags or {}
		
		for tagName, isTrue in pairs(tags) do
			if isTrue and data.bypassBy then
				rules[tagName] = {
					name = name,
					bypassableBy = data.bypassBy,
				}
			end
		end
	end
	
	self._immunityRules = rules
	return rules
end


--=============================================================================
--  PLAYER STATE (Cast, GlobalCast, etc)
--=============================================================================

--[[
Retorna todos ESTADOS ativos
]]
function StatusComponent:GetActivePlayerState()
	for name, state in pairs(self.Statuses.state) do
		if state and state.data.data then
			if state.data.data.category == "PlayerState" then
				return state
			end
		end
	end
	return nil
end

--[[
Busca por um estado especifico
]]
function StatusComponent:GetPlayerState(stateName : string)
	return self.Statuses.state[stateName]
end

--[[
valida se a entidade pode continuar a ação atual (cast, ataque, etc)
@return sucesso BOOLEAN
]]
function StatusComponent:CanContinue() : boolean
	local tags = self:GetActiveTags()
	if tags["canCast"] == false then
		return false
	end
	
	local rawState = self:GetActivePlayerState()
	if not rawState then return true end
	
	local activeState = rawState.data
	
	-- Checa se está em tabela Self (pode cancelar)
	for _, stateDef in pairs(StateTable.PlayerStates.Self) do
		if activeState.data.name == stateDef.data.name then
			return true
		end
	end
	
	return false
end

--[[
Cancelamento interno de skills buscando por estados do tipo SelfCast
@return sucesso BOOLEAN
]]
function StatusComponent:TrySelfCancel() : boolean
	for stateName, _ in pairs(self.Statuses.state) do
		local state = self:GetPlayerState(stateName)
		if not state or not state.data.data then continue end
		
		if state.data.data.category == "PlayerState" then
			-- Checa se é Self
			for _, v in pairs(StateTable.PlayerStates.Self) do
				if v.data.name == stateName then
					local runner = state.sourceSkill or state.sourceRunner or state.runner
					if runner and typeof(runner) == "table" and runner.Stop then
						runner:Stop(true)
						return true
					end
				end
			end
			return false -- Encontrou PlayerState mas não é Self
		end
	end
	
	return true -- Nenhum PlayerState ativo
end

--=============================================================================
--  GETTERS
--=============================================================================

--[[
Retorna um status especifico por nome
@param name - Nome do status STRING
@return lista de entradas do status TABLE ou nil se não encontrado
]]
function StatusComponent:GetStatus(name : string) : {}?
	local entry = self.Statuses.status[name] or self.Statuses.state[name]
	if not entry then return nil end
	
	if entry.runner or entry.data then
		return {entry}
	end
	return entry
end

--[[
Retorna o contador de stacks de um status por nome
@param name - Nome do status STRING
@return contador - NUMBER
]]
function StatusComponent:GetCounter(name : string) : number
	local list = self:GetStatus(name)
	if not list then return 0 end
	
	local entry = list[1]
	if entry.runner and entry.data.data.stackOnSelf then
		return entry.runner.counter
	else
		return #list
	end
end

--[[
Gera um ID único para um status
@param sourceName - Nome da fonte STRING (opcional)
@return ID único STRING
]]
function StatusComponent:generateUniqueId(sourceName : string) : string
	sourceName = sourceName or "Generic"
	return sourceName .. "_" .. tostring(tick()):gsub("%.", "") .. "_" .. math.random(1000, 999999)
end

--=============================================================================
--  LIFECYCLE
--=============================================================================

--[[
Limpa todos os STATUS ativos e devolve quantos foram removidos
@return quantidade de instancias removidas NUMBER
]]
function StatusComponent:ClearAll() : number
	local removed = 0
	for _, group in pairs(self.Statuses) do
		for name in pairs(group) do
			self:Remove(name)
			removed += 1
		end
	end
	return removed
end

--[[
Destroi o componente, limpando referências e parando processos
]]
function StatusComponent:Destroy()
	self:ClearAll()
	self.Entity = nil
	self._cachedTags = nil
	self._immunityRules = nil
end

--=============================================================================
--  API EXPOSE
--=============================================================================

local ExposeAPI = {
	Apply = function(component, ...) return component:Apply(...) end,
	Remove = function(component, ...) return component:Remove(...) end,
	RemoveByID = function(component, ...) return component:RemoveByID(...) end,
	GetStatus = function(component, ...) return component:GetStatus(...) end,
	GetActiveTags = function(component) return component:GetActiveTags() end,               
	ValidateHit = function(component, ...) return component:ValidateHit(...) end,           --??
	GetCounter = function(component, ...) return component:GetCounter(...) end,
	generateUniqueId = function(component, ...) return component:generateUniqueId(...) end,
	CanContinue = function(component) return component:CanContinue() end,                  --??????
	TrySelfCancel = function(component) return component:TrySelfCancel() end,              --?????
}

return {
	new = StatusComponent.new,
	ExposeAPI = ExposeAPI
}