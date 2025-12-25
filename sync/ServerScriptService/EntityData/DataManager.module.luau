local Players = game:GetService("Players")
local EntityData = require(script.Parent.EntityData)

local DataManager = {}
local entityMap = {
	players = {},
	NPCs = {}
}

--Cria o EntityData do jogador

--[[
DataManager.Create(Entity)
Caso Player, passar o Player inteiro, caso NPC, passar o modelo da entidade
@param Entity - Player ou entidade genérica
@return void
]]
function DataManager.Create(Entity)

	--Gera um ID único pra entidade
	local id = DataManager.CreateID(Entity)

	--Salva esse ID no mapa de entidades
	local data = EntityData.new(Entity,id)

	--Salva o EntityData no mapa correto
	if Entity:IsA("Player") then
		entityMap.players[id] = data

		-- Se o personagem já estiver carregado (ex: F5 ou respawn instantâneo)
		if Entity.Character then
		data:setPlayer(Entity.Character)
		end

		-- Monitorar respawn
		Entity.CharacterAdded:Connect(function(char)
			data:setPlayer(char)
		end)
		
	else
		entityMap.NPCs[id] = data
	end

	Instance.new("StringValue", Entity).Name = "ID"
	Entity.ID.Value = id
	return data

end


--Recupera o EntityData do jogador
function DataManager.Get(Entity)

	if Entity:IsA("Player") then
	   return entityMap.players[Entity.ID.Value]
	end

	return entityMap.NPCs[Entity.ID.Value]

end

--Remove o EntityData do jogador
function DataManager.Remove(Entity)
	
		if Entity:IsA("Player") then
			entityMap.players[Entity.ID.Value] = nil
		else
			entityMap.NPCs[Entity.ID.Value] = nil
		end
end


--Monitorar fluxo de jogadores, removendo e adicionando EntityData conforme necessário
Players.PlayerAdded:Connect(function(player)
	task.delay(0.1, function()
		local ED = DataManager.Get(player)
		if not ED then
			warn("[Main] ED nil:", player.Name)
			return
		end
		print("[Main] ED gerado:", ED.Entity)
		ED:setPlayer(player.Character) 
		print("Table: ", ED)
	end)
end)
Players.PlayerRemoving:Connect(function(player)
	DataManager.Remove(player)
end)



--Cria os IDS pra redirecionamento ao ED
function DataManager.CreateID(Entity)
	
	--Se não existir uma entidade, saia da função e retorne nil
	if not Entity then return nil end

	--Se a entidade for um player, então:
	if Entity:IsA("Player") then

		--Gera um ID baseado no UserID do Player
		local id = "Player_" .. Entity.UserId
			if entityMap[Entity.UserId] then
				warn("[DataManager]ID já existe para o jogador:", Entity.Name)
				return nil
			end
		return id
			

		--Se for uma entidade genérica, então:
	else
		--Gera um ID único baseado no DebugId da entidade
		local id = "Entity_" .. tostring(Entity:GetDebugId())

			--Se o ID já existir, gere um novo até achar um único
		   while entityMap[id] do
			   id = "Entity_" .. tostring(math.random(100000,999999))
		   end
		return id
	end
end

return DataManager