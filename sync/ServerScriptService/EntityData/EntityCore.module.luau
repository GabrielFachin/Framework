--[[
	EntityCore - Núcleo de toda entidade, componentizado, passar os componentes antes de criar a entidade.)
]]

local EntityCore = {}
EntityCore.ComponentKey = {}

-- Intervém em chamada de função inexistente
local function DummyFunc()
	print("[EntityCore] Tentativa de interação com comp/método inexistente",key)
    return nil 
end


function EntityCore:__index(key)

	--Busca por métodos existentes na própia classe
    local member = EntityCore[key]
    if member then 
        return member 
    end

	--Caso não encontrar nada, retorne a função dummy pra evitar que quem chamou quebre.
    return DummyFunc
end

-- Registry de componentes
local ComponentRegistry = {}

--=============================================================================
--  CONSTRUCTOR
--=============================================================================

--[[
Instancia uma nova entidade
@param instance - Instância Roblox associada à entidade (model para NPCs Custom) Instance
@param entityType - Tipo da entidade ("Player", "NPC") STRING
@param entityID - ID único da entidade STRING 
@return nova instância do EntityCore EntityCore
]]
function EntityCore.new(instance : Instance, entityType : string, entityID : string?,Player : any?)
	local self = setmetatable({}, EntityCore)

	-- Dados mínimos
	self.ID = entityID or ("Entity_" .. tostring(tick()))
	self.Instance = instance
	self.Type = entityType or "Generic"
	self.Components = {}
	self.Player = Player or nil

	-- Lifecycle
	self.Active = true
	self.CreatedAt = tick()

	return self
end

--=============================================================================
--  COMPONENT MANAGEMENT
--=============================================================================

--[[
Adiciona um componente à entidade
@param componentName - Nome do componente registrado STRING
@param config - Configurações iniciais do componente TABLE
@return instância do componente adicionado ANY
]]
function EntityCore:AddComponent(componentName : string, config : {[string]: any}?)
	if self.Components[componentName] then
		warn("[EntityCore] Componente já existe:", componentName)
		return self.Components[componentName]
	end

	if not ComponentRegistry[componentName] then
		warn("[EntityCore] Componente não registrado:", componentName)
		return nil
	end

	-- Cria instância do componente e armazena no ComponentRegistry
	local component = ComponentRegistry[componentName].new(self, config or {})
	self.Components[componentName] = component

	-- Expõe API do componente diretamente na entidade
	if ComponentRegistry[componentName].ExposeAPI then
		for methodName, method in pairs(ComponentRegistry[componentName].ExposeAPI) do
			if not self[methodName] then -- Não sobrescreve métodos existentes
				self[methodName] = function(...)
					return method(component, ...)
				end
				warn("Método com nome duplicado!")
			end
		end
	end

	return component
end

--[[
Função chamada após todos os componentes serem carregados.
]]
function EntityCore:ComponentsLoaded()
	-- Chama OnAdded em todos os componentes
	for name, component in pairs(self.Components) do
		if component.OnAdded then
			component:OnAdded()
		end
	end
end

--[[
Retorna um componente da entidade
@param componentName - Nome do componente STRING
@return instância do componente ANY
]]
function EntityCore:GetComponent(componentName : string) : Instance?
	return self.Components[componentName]
end

--[[
Retorna se a entidade possui um componente específico
@param componentName - Nome do componente STRING
@return possui componente BOOLEAN
]]
function EntityCore:HasComponent(componentName : string) : boolean
	return self.Components[componentName] ~= nil
end

--[[
Remove um componente da entidade
@param componentName - Nome do componente STRING
]]
function EntityCore:RemoveComponent(componentName : string)
	local component = self.Components[componentName]
	if not component then return end

	-- Callback de remoção
	if component.OnRemoved then
		component:OnRemoved()
	end

	if component.Destroy then
		component:Destroy()
	end

	self.Components[componentName] = nil
end

--=============================================================================
--  LIFECYCLE
--=============================================================================

--[[
Destrói a entidade, removendo todos os componentes e limpando referências
]]
function EntityCore:Destroy()
	if not self.Active then return end

	-- Destroi todos os componentes
	for name, component in pairs(self.Components) do
		if component.Destroy then
			component:Destroy()
		end
	end

	self.Active = false
	self.Components = {}
	self.Instance = nil
end

--=============================================================================
--  UTILITY
--=============================================================================

--[[
Retorna se a entidade é um Player
@return é player BOOLEAN
]]
function EntityCore:IsPlayer() : boolean
	return self.Type == "Player"
end

--[[
Retorna se a entidade é um NPC
@return é NPC BOOLEAN
]]
function EntityCore:IsNPC() : boolean
	return self.Type == "NPC"
end

--[[
Retorna a idade da entidade em segundos
@return idade em segundos NUMBER
]]
function EntityCore:GetAge() : number
	return tick() - self.CreatedAt
end

--=============================================================================
--  COMPONENT REGISTRATION
--=============================================================================

--[[
Registra um componente globalmente para uso em entidades
@param name - Nome do componente STRING
@param componentModule - Módulo do componente TABLE
]]
function EntityCore.RegisterComponent(name : string, componentModule : {[string]: any})
	if ComponentRegistry[name] then
		warn("[EntityCore] Componente já registrado:", name)
		return
	end


	ComponentRegistry[name] = {
		new = componentModule.new,
		ExposeAPI = componentModule.ExposeAPI,
	}

	print("[EntityCore] Componente registrado:", name)
end

--[[
Retorna a lista de nomes de componentes registrados
@return lista de nomes de componentes TABLE {STRING, STRING, ...}
]]
function EntityCore.GetRegisteredComponents() : {string}
	local names = {}
	for name in pairs(ComponentRegistry) do
		table.insert(names, name)
	end
	return names
end

--=============================================================================
--  DEBUG
--=============================================================================

--[[
Função de debug, printa: ID, Type, Active, Components
]]
function EntityCore:PrintComponents()
	print("=== EntityCore:", self.ID, "===")
	print("Type:", self.Type)
	print("Active:", self.Active)
	print("Components:")
	for name, component in pairs(self.Components) do
		print("  -", name)
	end
	print("==================")
end

--=============================================================================
--  AUTO-REGISTER COMPONENTS
--=============================================================================

--[[
Registra componentes automaticamente quando o módulo carrega
]]
local function AutoRegisterComponents()
	local componentsFolder = script.Parent:FindFirstChild("Components")
	if not componentsFolder then
		warn("[EntityCore] Pasta Components não encontrada")
		return
	end

																			--Pra cada módulo na pasta de componentes, registra automaticamente
	for _, componentModule in ipairs(componentsFolder:GetChildren()) do
		if componentModule:IsA("ModuleScript") then                         --Se for um modulo
			local success, component = pcall(require, componentModule)		--Tenta requerer o módulo
			if success then													--Se conseguiu
				local name = componentModule.Name:gsub("Component", "")		--Pega o nome do componente sem o sufixo "Component" (gsub substitui a string)
				EntityCore.RegisterComponent(name, component)				--Registra o componente no EntityCore
				EntityCore.ComponentKey[name] = name							--Adiciona o nome do componente no enum  EntityCore.Components
			else
				warn("[EntityCore] Erro ao carregar componente:", componentModule.Name)
			end
		end
	end
	EntityCore.ComponentKey = table.freeze(EntityCore.ComponentKey)				--Freeze o enum pra eviltar alterações em runtime
end

-- Chama auto-registro
AutoRegisterComponents()

return EntityCore