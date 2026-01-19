
local Helper = {}

local Enum = require(script.Parent.Enum)



function Helper.LoadModules(rootScript, folderName, targetTable)
	local folder = rootScript:FindFirstChild(folderName) 

	
	for _, module in ipairs(folder:GetChildren()) do
		if module:IsA("ModuleScript") then
			local success, data = pcall(require, module)
			
			if success then
				targetTable[module.Name] = data
				
				if data.data and not data.data.name then
					data.data.name = module.Name
				end
			else
				warn("[StateTable] Erro ao carregar " .. module.Name .. ": " .. tostring(data))
			end
		else
			for _,Folder in ipairs(folder:GetChildren()) do
				for _,module in ipairs(Folder:GetChildren()) do
					if module:IsA("ModuleScript") then
						local success,data = pcall(require,module)

						if success then
							targetTable[module.name] = data

							if data.data and not data.data.name then
								data.data.name = module.name
							end
						else
							warn("[StateTable] Erro ao carregar " .. module.Name .. ": " .. tostring(data))
						end
					end
				end
			end
		end
	end
end

function Helper.GetTags(stateTable, stateName)
	local state = stateTable.States[stateName] or stateTable.Status[stateName]
	
	if not state or not state.data.tags then 
		return Enum.Defaults 
	end

	return setmetatable(state.data.tags, { __index = Enum.Defaults })
end

function Helper.IsState(stateTable, meta)
	if not meta or not meta.name then return false end
	
	if stateTable.States[meta.name] then return true end
	
	for _, group in pairs(stateTable.PlayerStates) do
		if type(group) == "table" then
			for _, state in pairs(group) do
				if state.data and state.data.name == meta.name then
					return true
				end
			end
		elseif group.data and group.data.name == meta.name then
			return true
		end
	end

	if meta.category == Enum.Categories.PlayerState then
		return true
	end
	
	return false
end



function Helper.BuildEffect(baseStatus, callbackName, actionFunc)
	if not baseStatus then return nil end
	
	local newStatus = table.clone(baseStatus)
	
	if newStatus.callbacks then
		newStatus.callbacks = table.clone(newStatus.callbacks)
	else
		newStatus.callbacks = {}
	end
	
	newStatus.callbacks[callbackName] = actionFunc
	
	return newStatus
end



O código que você enviou tem alguns erros de sintaxe e de escopo que farão o script quebrar ou funcionar ao contrário (bloqueando tudo se não tiver filtro definido).

Aqui estão os problemas principais:

Erro de Escopo: Você declarou local typeMatch dentro do bloco if data.ShieldsFromType then. Se o código sair desse bloco (ou seja, se não tiver filtro de tipo), a variável typeMatch deixa de existir. Quando você tenta checar if not typeMatch lá fora, vai dar erro ou considerar nil (que vira true no not, retornando false e cancelando o block indevidamente).

Lógica Invertida (Default Allow): Se data.ShieldsFromType for nil (block genérico), seu código pula o bloco de verificação. Como typeMatch não foi definido como true antes, ele cai no return false lá embaixo. Ou seja: se não tiver filtro, ele não bloqueia nada. O correto é: se não tiver filtro, bloqueia tudo.

Sintaxe do break: break end na mesma linha funciona, mas é perigoso e pouco legível. O break encerra o loop for, mas você precisa garantir que o if foi fechado corretamente.

Aqui está a versão corrigida e blindada:

Lua

function Helper.CheckBlockFilter(runner, context)
    local data = (runner.data and runner.data.data) or (runner.skillData and runner.skillData.data)
    
    if not data then return true end

    local source = context.source
    local incomingTraits = context.traits or {}

    if data.ShieldsFromType then
        local sourceType = source and source.type 
        local typeMatch = false
        
        for _, Type in pairs(data.ShieldsFromType) do
            if sourceType == Type then
                typeMatch = true
                break 
            end
        end
        
        if not typeMatch then
            return false 
        end
    end

    if data.ShieldsFrom then
        local traitMatch = false
        
        for _, requiredTrait in ipairs(data.ShieldsFrom) do
            if table.find(incomingTraits, requiredTrait) then
                traitMatch = true
                break 
            end
        end
        
        if not traitMatch then
            return false 
        end
    end

    return true 
end

return Helper


return Helper