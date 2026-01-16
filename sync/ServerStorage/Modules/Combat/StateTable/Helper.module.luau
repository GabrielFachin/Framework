--[[
	StateTable/Helpers.module.luau
	Funções utilitárias para manipulação e carregamento de estados.
]]

local Helpers = {}

-- Requer Enums para acessar os Defaults
local Enums = require(script.Parent.Enums)

-- ============================================================================
-- LOADER
-- ============================================================================

function Helpers.LoadModules(rootScript, folderName, targetTable)
	local folder = rootScript:FindFirstChild("Definitions") 
		and rootScript.Definitions:FindFirstChild(folderName)
	
	if not folder then 
		-- Warn opcional, as vezes a pasta só não existe mesmo e tudo bem
		return 
	end

	for _, module in ipairs(folder:GetChildren()) do
		if module:IsA("ModuleScript") then
			local success, data = pcall(require, module)
			
			if success then
				targetTable[module.Name] = data
				
				-- Injeção automática de nome se faltar
				if data.data and not data.data.name then
					data.data.name = module.Name
				end
			else
				warn("[StateTable] Erro ao carregar " .. module.Name .. ": " .. tostring(data))
			end
		end
	end
end

-- ============================================================================
-- Lógica de estados
-- ============================================================================

function Helpers.GetTags(stateTable, stateName)
	-- Busca em States ou Status
	local state = stateTable.States[stateName] or stateTable.Status[stateName]
	
	if not state or not state.data.tags then 
		return Enums.Defaults 
	end

	return setmetatable(state.data.tags, { __index = Enums.Defaults })
end

function Helpers.IsState(stateTable, meta)
	if not meta or not meta.name then return false end
	
	-- 1. Verifica se está na tabela de States (Controle)
	if stateTable.States[meta.name] then return true end
	
	-- 2. Verifica se é PlayerState (Itera pelas subcategorias Self/Out)
	for _, group in pairs(stateTable.PlayerStates) do
		if type(group) == "table" then
			for _, state in pairs(group) do
				if state.data and state.data.name == meta.name then
					return true
				end
			end
		-- Caso a estrutura seja direta sem subcategorias
		elseif group.data and group.data.name == meta.name then
			return true
		end
	end

	-- 3. Fallback por categoria
	if meta.category == Enums.Categories.PlayerState then
		return true
	end
	
	return false
end

-- ============================================================================
-- INJEÇÃO
-- ============================================================================

--[[
	Cria uma cópia de um Status existente e injeta um callback customizado.
	Utilizado por Skills para criar escudos reativos dinâmicos.
]]
function Helpers.BuildShield(baseStatus, callbackName, actionFunc)
	if not baseStatus then return nil end
	
	-- Clona a tabela principal do status
	local newStatus = table.clone(baseStatus)
	
	-- Clona a tabela de callbacks para não afetar o original
	if newStatus.callbacks then
		newStatus.callbacks = table.clone(newStatus.callbacks)
	else
		newStatus.callbacks = {}
	end
	
	-- Injeta a nova função (ex: injetar um onBlock que dispara um contra-ataque específico da skill)
	newStatus.callbacks[callbackName] = actionFunc
	
	return newStatus
end

return Helpers