local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
local DataManager = require(Server.EntityData.DataManager)
local AntiCheat = require(script.Parent.GlobalAntiCheat)

local RemoteEventSkill = ReplicatedStorage.RemoteEvents.RequestSkill
local RemoteEventDir = ReplicatedStorage.RemoteEvents.RequestDir
local RemoteEventSkillFired = ReplicatedStorage.RemoteEvents.SkillFired
local SkillHandler = require(Server.Modules.SkillHandler)

LastMovementTime = {}
LastSkillTime = {}

RemoteEventDir.OnServerEvent:Connect(function(player,dir)

    local ID = AntiCheat.CheckMovementInput(player,LastMovementTime[Player])
    if not ID then return end 

    LastMovementTime[player] = tick()
    SkillHandler.HandleMovementInput(ID,dir)
end)

RemoteEventSkillFired.OnServerEvent:Connect(function(player,skillIndex)

    local ID = AntiCheat.CheckSkillInput(player,LastSkillTime[Player])
    if not ID then return end

    LastSkillTime[player] = tick()
    local succes,skillName,Cooldown = skillRequest(ID,skillIndex) --Guarda se deu ok pra replicar efeitos no cliente

end)


local function skillRequest(ID,skillIndex)
    
    local entityCore = DataManager.Get(ID)
    if not entityCore:HasComponent(entityCore.ComponentKey.Combat) then return false end
    success = SkillHandler.HandleSkillInput(player,skillIndex)
    if succes then RemoteEventSkillFired:FireClient(player,skillName,maxCooldown)    

end

Players.PlayerRemoving:Connect(function(player)
    LastMovementTime[player] = nil
    LastSkillTime[player] = nil
    AntiCheat.Unregister(player)
end)