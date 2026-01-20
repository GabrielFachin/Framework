local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
local DataManager = require(Server.EntityData.DataManager)

local TrackedPlayers = {}

function AntiCheat.Init()
    if not connection then
		connection = RunService.Heartbeat:Connect(function(dt)
			AntiCheat._Update(dt)
		end)
	print("[AntiCheat] Iniciado")
	end
end

--=====REGISTRO DE PLAYERS=====--

function AntiCheat.Register(Player)
    local ID = player.Character and player.Character:GetAttribute("EntityID")
    if not ID then continue end
    local entityCore = DataManager.Get(ID)
    if not entityCore then continue end

    TrackedPlayers[Player] = {
        LastMoveTime = 0,
        LastSkillTime = 0,
        LastPosition = nil,
        ID = ID
    }

end

function AntiCheat.Unregister(Player)
    TrackedPlayers[Player] = nil
end

--=====FUNÇÕES UTILITARIAS=====--

function AntiCheat.CheckMovementInput()

end


--=====FUNÇÕES INTERNAS=====--

function AntiCheat.CheckPosition()

end

function AntiCheat.CheckNoClip()

end

--=====HEARTBEAT=====--

function AntiCheat._Update(dt)
    --w
end


AntiCheat.Init()