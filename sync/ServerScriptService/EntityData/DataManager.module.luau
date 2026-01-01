local EntityCore = require(script.Parent.EntityCore)

local DataManager = {}
local entityMap = {
	players = {},
	NPCs = {}
}

--Cria o EntityCore do jogador

--[[
DataManager.Create(Entity)
Caso Player, passar o Player Character (modelo do player), caso NPC, passar o modelo da entidade
@param Entity - Player.Character ou modelo de entidade MODEL
@param components - tabela de componentes a serem adicionados {}
@return void
]]
function DataManager.Create(Entity,components : {})

	if not Entity then
		warn("[DataManager] Entidade não recebida, func Create")
		return nil
	end
	if not components then
		warn("[DataManager] Componentes não recebidos, func Create")
		return nil
	end

	--Gera um ID único pra entidade
	local id,entityType = DataManager.CreateID(Entity)
	
	warn(entityType,"Registrado, ID:",id)

	--Salva esse ID no mapa de entidades
	local core = EntityCore.new(Entity,entityType,id)


	--Adiciona os componentes recebidos como argumento
	for _,comp in pairs(components) do
		core:AddComponent(comp)
		local compList = {}
		compList[#compList + 1] = comp
		print("[DataManager] Componentes adicionados:", compList)
	end
	core:ComponentsLoaded()

	--Salva o EntityCore no mapa correto
	if Entity.Player then
		entityMap.players[id] = core
	elseif Entity:IsA("Model") then
		entityMap.NPCs[id] = core
	else
		warn("[DataManager] Entidade inválida, func Create")
		return nil
	end

	-- inicializa o wrapper e guarda o modelo/character da entidade
	core:SetCharacter(Entity)

	--inicializa o wrapper de movimentação
	core:SetMovement()

	Instance.new("StringValue", Entity.Model).Name = "ID"
	Entity.Model.ID.Value = id
	
	return core

end


--[[
Retorna o EntityCore da entidade
@param Entity - Player ou entidade
]]
function DataManager.Get(Entity)

	if Entity.Player then
	   return entityMap.players[Entity.ID.Value]
	end

	if Entity:IsA("Model") then
		return entityMap.NPCs[Entity.ID.Value] 
	end

	warn("[DataManager] Entidade inválidam, func Get")
	return nil 


end

--[[
Remove o EntityCore da entidade
@param Entity - Player ou entidade
]]
function DataManager.Remove(Entity)
	
		if Entity.Player then
			entityMap.players[Entity.ID.Value].destroy()
			entityMap.players[Entity.ID.Value] = nil
		else
			entityMap.NPCs[Entity.ID.Value].destroy()
			entityMap.NPCs[Entity.ID.Value] = nil
		end
end

--Cria os IDS pra redirecionamento ao ED
function DataManager.CreateID(Entity)
	
	--Se não existir uma entidade, saia da função e retorne nil
	if not Entity then return nil end

	--Se a entidade for um player, então:
	if Entity.Player:IsA("Player") then

		--Gera um ID baseado no UserID do Player
		local id = "Player_" .. Entity.Player.UserId
			if entityMap.players[id] then
				warn("[DataManager]ID já existe para o jogador:", Entity.Player.Name)
				return nil
			end
		return id,"Player"
			

		--Se for uma entidade genérica, então:
	else
		--Gera um ID único baseado no DebugId da entidade
		local id = "Entity_" ..  tostring(math.random(100000,999999))

			--Se o ID já existir, gere um novo até achar um único
		   while entityMap.NPCs[id] do
			   id = "Entity_" .. tostring(math.random(100000,999999))
		   end
		return id,"Entity"
	end
end

return DataManager