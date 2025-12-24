local Players = game:GetService("Players")
local EntityData = require(script.Parent.EntityData)

local DataManager = {}
local playerMap = {}

function DataManager.Create(player)
	local data = EntityData.new(player)
	playerMap[player.UserId] = data

	-- Se o personagem já estiver carregado (ex: F5 ou respawn instantâneo)
	if player.Character then
		data:setPlayer(player.Character)
	end

	-- Monitorar respawn
	player.CharacterAdded:Connect(function(char)
		data:setPlayer(char)
	end)

	return data
end

function DataManager.Get(player)
	return playerMap[player.UserId]
end

function DataManager.Remove(player)
	playerMap[player.UserId] = nil
end


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


-- Inicialização para jogadores que já estão na sessão (quando dá F5 no Studio)
for _, player in ipairs(Players:GetPlayers()) do
	DataManager.Create(player)
end

return DataManager