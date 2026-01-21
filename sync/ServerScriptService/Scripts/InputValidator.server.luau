local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
local DataManager = require(Server.EntityData.DataManager)
local AntiCheat = require(Server.Modules.GlobalAntiCheat)

local RemoteEventSkill = ReplicatedStorage.RemoteEvents.RequestSkill
local RemoteEventDir = ReplicatedStorage.RemoteEvents.RequestDir
local RemoteEventSkillFired = ReplicatedStorage.RemoteEvents.SkillFired
local SkillHandler = require(Server.Modules.SkillHandler)

local Players = game:GetService("Players")

LastMovementTime = {}
LastSkillTime = {}

local function skillRequest(Player,ID,skillIndex)

    local entityCore = DataManager.Get(ID)
    if not entityCore:HasComponent(entityCore.ComponentKey.Combat) then return false end
    local success,skillName,maxCooldown = SkillHandler.HandleSkillInput(ID,skillIndex)
    if success then RemoteEventSkillFired:FireClient(Player,skillName,maxCooldown) end

    return success

end

Players.PlayerRemoving:Connect(function(Player)
    LastMovementTime[Player] = nil
    LastSkillTime[Player] = nil
end)

Players.PlayerAdded:Connect(function(Player)
    LastMovementTime[Player] = tick()
    LastSkillTime[Player] = tick()
end)


RemoteEventDir.OnServerEvent:Connect(function(Player,dir)

    local ID = AntiCheat.CheckMovementInput(Player,LastMovementTime[Player])
    if not ID then return end 

    LastMovementTime[Player] = tick()
    SkillHandler.HandleMovementInput(ID,dir)
end)

RemoteEventSkill.OnServerEvent:Connect(function(Player,skillIndex)

    local ID = AntiCheat.CheckSkillInput(Player,LastSkillTime[Player])
    if not ID then return end

    LastSkillTime[Player] = tick()
    skillRequest(Player,ID,skillIndex)

end)

