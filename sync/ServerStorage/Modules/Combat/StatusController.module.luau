local Server = game:GetService("ServerScriptService")
local Storage = game:GetService("ServerStorage")

local SkillRunner = require(Server.Modules.SkillRunner)
local StateTable = require(Storage.Modules.Combat.StateTable)

local StatusController = {}
StatusController.__index = StatusController

local runnerType = "status" --Informa o SkillRunner/SkillScheduler que é um status

function StatusController.new(cd)
	local self = setmetatable({}, StatusController)
	self.CD = cd

	self.statuses = {
		status = {}, -- tabela de status (permite multiplos)
		state = {},  -- tabela de estado (permite multiplos da mesma categoria)
	}

	return self
end


--Lida com o pedido do CombatData, enviando pro StatusHandler pra preparar injeções e sanitização de dados
function StatusController:HandleApplication(Data, targetTPD, duration, sourceSkill, ID)
	
	
	local Handler = require(game.ServerScriptService.Modules.StatusHandler)
	local treatedStatus = Handler:HandleStatus(Data, targetTPD, duration, sourceSkill, ID)
	

	if treatedStatus then
		return self:Apply(treatedStatus, targetTPD, duration, sourceSkill, ID)
	end
end



--Aplica Status e/ou Estados
function StatusController:Apply(data, targetTPD, duration, sourceSkill,ID)
	
	data = table.clone(data)
	
	if not data.ID then
		data.ID = ID or generateUniqueId(sourceSkill and sourceSkill.skillName)
	end
	
	
	data.StatusController = self
	
	if not sourceSkill then
		warn("[StatusController] SourceSkill não encontrado, usando ID genérico")
	end

	local meta = data.data	

	if not meta.name then
		warn("Status sem nome")
	end
	if not meta.category then
		warn("Status sem categoria")
	end

	--Confere se é estado ou status
	local isState = StateTable:IsState(meta)

	--Prepara a table referente ao tipo de dado recebido
	local group = isState and self.statuses.state or self.statuses.status


	-- == STACK DE STATUS SOB A  MESMA INSTÂNCIA == --

	-- Se stackavel e se stacka em si mesmo, ou seja, uma unica instância recebendo aumento de contagem:
	if meta.stackable and meta.stackOnSelf then
		local existing = group[meta.name]
		if existing then
			if existing.counter >= (meta.maxStacks or math.huge) then return end --Estoura o limite de stacks? se sim, saia da função

			if existing.runner then
				existing.runner.elapsedTime = 0 --Reseta o timer de duração de skill
				
				existing.runner:Recast() --Chama o Recast do runner, responsável de rodar o onRecast da skill caso tenha (mas não rodando diretamente)
			end
			return data.ID
		end

		warn("Aplicado", data.data.name, "em:", targetTPD.Player)

		local runner = SkillRunner.new(data, targetTPD, meta.name,runnerType)
		
		runner.onFinish = function()
		self:_OnRunnerFinished(meta.name, runner)
		end
		
		runner:start() --Inicializa o runner

		--Guarda as informações
		group[meta.name] = {
			data = data,     --Números/Lógica do efeito
			counter = 1,
			runner = runner, --Runner própio
			sourceSkill = sourceSkill, --Ponteiro pro runner da skill que iniciou
			sourcePlayer = self.CD.Player, --Origem do efeito
			ID = data.ID
		}
		

		return data.ID
	
	end

	-- == STACK DE STATUS SOB INSTÂNCIAS DIFERENTES == --

	-- Se for stackavel mas forem instâncias diferentes:
	if meta.stackable and not meta.stackOnSelf then
		local list = group[meta.name] or {} --Prepara uma lista/table pra guardar as instâncias
		if #list >= (meta.maxStacks or math.huge) then return end --Testa se passou do limite
		
		print("Aplicado: ", data.data.name, "; Em: ", targetTPD.Player)

		local runner = SkillRunner.new(data, targetTPD, meta.name,runnerType)  --Cria o runner recebendo o TPD do alvo
		
			runner.onFinish = function()
			self:_OnRunnerFinished(meta.name, runner)
			end
			
		print("[APPLY]", data, data.data, data.callbacks)

			
		runner:start()									 --Inicia o runner

		--Coloca os dados na lista
		table.insert(list, {
			data = data,     --Números/Lógica do efeito
			runner = runner, --Runner própio
			sourceSkill = sourceSkill, --Ponteiro pro runner da skill que iniciou
			sourcePlayer = self.CD.Player, --Origem do efeito
			ID = data.ID
		})

		group[meta.name] = list
		return data.ID
	end

	-- == DADOS EXCLUSIVOS == --

	--Se for exclusivo
	if meta.exclusive then
		for name, entry in pairs(group) do --Roda um for no grupo de dados presente
			if entry.data.data.category == meta.category then --Se a categoria for igual, então:
				self:Remove(name) --Remove o efeito antigo
			end
		end
	end
	
	warn("Aplicado:", data.data.name, "Em:", targetTPD.Player)

	local runner = SkillRunner.new(data, targetTPD, meta.name,runnerType)
	
		runner.onFinish = function()
		self:_OnRunnerFinished(meta.name, runner)
		end

	runner:start()
	



	group[meta.name] = {
		data = data,				--Números/Lógica do efeito
		runner = runner,			--Runner própio
		sourceSkill = sourceSkill, --Ponteiro pro runner da skill que iniciou o status
		sourcePlayer = self.CD.Player, --Origem do efeito
		ID = data.ID
	}
	return data.ID
	

end


-- Função de remoção, isso vai ser injetado no oEnd e onCancel(?) de todos os status (e talvez estados?) pelo skillFactory no handler, assim não precisamos "lembrar" o status de chamar isso toda vez no final
function StatusController:_OnRunnerFinished(name, runner)
	local list = self.statuses.status[name]
	if not list then return end --Se não encontrar a lista, retorna

	--Se for stack de uma instância única	
	if list.runner then
		self:Remove(name)
		return
	end

	-- Se for stacks de multiplas instâncias
	local newList = {}
	for _, entry in ipairs(list) do
		if entry.runner ~= runner then
			table.insert(newList, entry)
		end
	end

	if #newList > 0 then
		self.statuses.status[name] = newList
	else
		self.statuses.status[name] = nil
	end
	
end


function StatusController:Remove(name)
	for _, group in pairs(self.statuses) do  --Roda um loop no statuses
		local entry = group[name] --Entry = dado que estamos trabalhando
		if entry then			  --Se encontrar um equivalente ao dado atual, então:
			if entry.runner then
				entry.runner:endSkill(true) --Chama o endSkill do runner com cancelamento true
			elseif type(entry) == "table" then --Se o dado for uma table (instâncias multiplas)
				for _, item in ipairs(entry) do --Pega os itens existentes na tabela
					if item.runner then   	   --Se encontrar o runner da skill recebida, então cancele
						item.runner:endSkill(true)
					end
				end
			end
			group[name] = nil
		end
	end
end


-- == GETTERS == --

--Retorna uma lista de status/estados com o nome fornecido
function StatusController:GetStatus(name) 
	local entry = self.statuses.status[name] or self.statuses.state[name]
	if not entry then return nil end
	if entry.runner or entry.data then
		return { entry } -- devolve uma lista
	end
	return entry -- é uma lista
end


function StatusController:GetCounter(name)
	local list = self:GetStatus(name)
	if not list then return 0 end

	local entry = list[1]
	if entry.runner and entry.data.data.stackOnSelf then
		return entry.runner.counter  -- stackOnSelf = true
	else
		return #list -- stackOnSelf = false
	end
end


function StatusController:GetActiveTags() --Pega as tags ativas de todos os status e estados, retornando o que o player pode ou não fazer
	local merged = {}
	for _, group in pairs(self.statuses) do --Primeiro for, busca entre as 2 tables de statuses (estados e status)
		for _, entry in pairs(group) do		--Roda dentro da tabela atual
			local entries = (entry.runner or entry.data) and {entry} or entry
			for _, e in ipairs(entries) do 		--Roda dentro da tabela do status especifico (multiplas instancias)
				local tags = e.data.data.tags or {}  --Busca as tags
				for k, v in pairs(tags) do      --Loop pela tabela de tags
					if v == false then			--Se não existir a chave (k = key), se encontrar, então o index da chave (k), guarda o valor (v, ou value)
						merged[k] = false
					elseif merged[k] ~= false then
						merged[k] = v
					end
				end
			end
		end
	end
	 --Retorna as tags obtidas como uma lista
	 return merged
	--return {iFrame = true}
end


--Pega o playerState atual do player
function StatusController:GetActivePlayerState()
	for name, state in pairs(self.statuses.state) do
		if state and state.data.data then
			if state.data.data.category == "PlayerState" then
				return state
			end
		end
	end
	return nil
end

--Usado pra retornar o playerState, mas pode buscar qualquer estado por nome
function StatusController:GetPlayerState(stateName)
	local state = self.statuses.state[stateName]
	if not state then
		--warn("[StatusController] Estado não encontrado:", stateName)
	else
		--print("[StatusController] Estado encontrado:", stateName, "Runner:", state.runner)
	end
	return state
end


--Limpa todos os status e estados
function StatusController:ClearAll()
	for _, group in pairs(self.statuses) do
		for name in pairs(group) do
			self:Remove(name)
		end
	end
end





--Gera um id único pra novos estados e status serem criados pra evitar problemas de remoção de status sem ser o dono (a não ser que explicitamente falado que quer remover mesmo sem ser o dono)
   function generateUniqueId(sourceName)
	sourceName = sourceName or "Generic"
	return sourceName .. "_" .. tostring(tick()):gsub("%.", "") .. "_" .. math.random(1000, 999999)
end





function StatusController:RemoveById(id)
	local removed = false
	for groupName, group in pairs(self.statuses) do
		if groupName == "state" then
			for name, entry in pairs(group) do
				if entry.ID == id then
					self:Remove(name)
					removed = true
				end
			end
		elseif groupName == "status" then
			for name, list in pairs(group) do
				for i = #list, 1, -1 do
					local entry = list[i]
					if entry.ID == id then
						if entry.runner then
							entry.runner:Stop(true)
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
	return removed
end


return StatusController
