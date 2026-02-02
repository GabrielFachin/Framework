--[[










function DataManager.Create(Entity, components)
	if not Entity or not components then
		warn("[DataManager] Entidade ou Componentes inválidos")
		return nil
	end

	-- 1. Preparação Básica
	local id, entityType = DataManager.CreateID(Entity)
	local Model = (typeof(Entity) == "table") and Entity.Model or Entity
	local Player = (typeof(Entity) == "table") and Entity.Player or nil

	local core = EntityCore.new(Model, entityType, id, Player)

	-- ========================================================================
	-- [NOVO] RESOLUÇÃO DE DADOS (DATABASE VS MANUAL)
	-- ========================================================================
	
	local charName = nil
	local modeName = nil
	
	-- A. Verifica se foi passado explicitamente na config dos componentes
	if components.Attributes and components.Attributes.CharName then
		charName = components.Attributes.CharName
		modeName = components.Attributes.ModeName or "Base"
	elseif components.Character and components.Character.CharName then
		charName = components.Character.CharName
		modeName = components.Character.ModeName or "Base"
	end

	-- B. Se não, verifica atributos físicos no Objeto (Funciona pra NPC e Player igual)
	if not charName then
		if Player then
			charName = Player:GetAttribute("SelectedChar") or "Schema" -- Default Player
			modeName = Player:GetAttribute("SelectedMode") or "Base"
		elseif Model then
			charName = Model:GetAttribute("CharName") -- Default NPC (se tiver)
			modeName = Model:GetAttribute("ModeName")
		end
	end

	-- C. Carrega Stats Base do Database (Se houver identidade definida)
	local databaseStats = {}
	local attributesConfig = { BaseAttributes = {} }
	
	if charName then
		local charData = CharacterDatabase[charName] and CharacterDatabase[charName][modeName]
		if charData and charData.Stats then
			databaseStats = charData.Stats
			-- Salva identidade no Core
			core.CharName = charName
			core.ModeName = modeName
		end
	else
		-- D. Fallback: Se não tem identidade, escaneia atributos "crus" no Modelo
		-- (Ex: Uma caixa com MaxHP=50 direto nas properties)
		local attributesToScan = {"MaxHP", "Speed", "JumpForce", "Damage", "Defense"}
		for _, attrName in ipairs(attributesToScan) do
			local val = Model:GetAttribute(attrName)
			if val then
				attributesConfig.BaseAttributes[attrName] = val
			end
		end
		-- Garante mínimo vital
		if not attributesConfig.BaseAttributes.MaxHP then
			attributesConfig.BaseAttributes.MaxHP = 100
		end
	end

	-- 3. Injeção e Criação de Componentes
	for name, originalConfig in pairs(components) do
		local finalConfig = originalConfig or {}

		-- [NOVO] Injeção no AttributesComponent
		if name == "Attributes" then
			finalConfig = {}
			-- 1. Pega do Database
			if databaseStats then
				finalConfig.BaseAttributes = table.clone(databaseStats)
			else
				finalConfig.BaseAttributes = {}
			end
			-- 2. Sobrescreve com atributos manuais do modelo (se houver)
			for k, v in pairs(attributesConfig.BaseAttributes) do
				finalConfig.BaseAttributes[k] = v
			end
			-- 3. Sobrescreve com config passada via script (prioridade máxima)
			if originalConfig.BaseAttributes then
				for k, v in pairs(originalConfig.BaseAttributes) do
					finalConfig.BaseAttributes[k] = v
				end
			end
		end
		
		-- [NOVO] Injeção no HealthComponent (Sincronia inicial)
		if name == "Health" then
			local maxHP = finalConfig.MaxHP 
				or (finalConfig.BaseAttributes and finalConfig.BaseAttributes.MaxHP) -- Se acabou de processar Attributes
				or (databaseStats and databaseStats.MaxHP)
				or 100
			
			if not finalConfig.StartHP then
				finalConfig.StartHP = maxHP
			end
		end

		core:AddComponent(name, finalConfig)
	end

	-- ========================================================================

	if core:HasComponent(core.ComponentKey.Character) then
		core.SetEntity(Entity)
	end
	
	core:ComponentsLoaded()

	-- (Restante do mapeamento de ID mantém igual...)
	if entityType == "Player" then
		entityMap.players[id] = core
		Model:SetAttribute("EntityID", id)
		if Player then Player:SetAttribute("EntityID", id) end
	else
		entityMap.NPCs[id] = core
		Model:SetAttribute("EntityID", id)
	end

	if core:HasComponent(core.ComponentKey.Movement) then
		core.SetMovement()
	end

	return core
end





]]