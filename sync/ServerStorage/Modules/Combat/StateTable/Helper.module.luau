
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

return Helper