local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
local DataManager = require(Server.EntityData.DataManager)

local RemoteEventSkill = ReplicatedStorage.RemoteEvents.RequestSkill
local RemoteEventDir = ReplicatedStorage.RemoteEvents.RequestDir
local RemoteEventSkillFired = ReplicatedStorage.RemoteEvents.SkillFired
local SkillHandler = require(Server.Modules.SkillHandler)

requestList = {}
requestQueue = {}
requestMovelist = {}

RemoteEventDir.OnServerEvent:Connect(function(player,dir)
        if requestMoveList[player] then
        local lastRequestTime = requestMoveList[player]
        if tick() - lastRequestTime < 0.05 then
            return
        end
    
    local ID = player.Character:GetAttribute("EntityID")

    SkillHandler.HandleMovementInput(ID,dir)
    requestMoveList[player] = tick()
end)

RemoteEventSkillFired.OnServerEvent:Connect(function(player,skillIndex)
    if requestList[player] then
        local lastRequestTime = requestList[player]
        if tick() - lastRequestTime < 0.2 then
            requestQueue[player] = skillIndex
            return
        end
    end
    skillRequest(player,skillIndex)

end)


local function skillRequest(player,skillIndex)
    
    local ID = player.Character:GetAttribute("EntityID")
    local entityCore = DataManager.Get(ID)
    if not entityCore:HasComponent(entityCore.ComponentKey.Combat) then return false end
    success = SkillHandler.HandleSkillInput(player,skillIndex)
    if succes then RemoteEventSkillFired:FireClient(player,skillName,maxCooldown)    
    requestList[player] = tick()
end


for player,_ in pairs(requestQueue) do
    local skillIndex = requestQueue[player]
    skillRequest(player,skillIndex)
    requestQueue[player] = nil
end

task.wait()