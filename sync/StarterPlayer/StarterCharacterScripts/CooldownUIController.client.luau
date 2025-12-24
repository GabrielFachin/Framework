local ReplicatedStorage = game:GetService("ReplicatedStorage")
local event = ReplicatedStorage.RemoteEvents.SkillFired

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = player:WaitForChild("PlayerGui"):WaitForChild("CooldownGUI")
 local list = gui:WaitForChild("Attacks")

local skillCooldowns = {}
local activeTweens = {}  

local TweenService = game:GetService("TweenService")


event.OnClientEvent:Connect(function(name,cooldown)
	local skill = list:WaitForChild(name)
	local bar = skill:WaitForChild("Frame")
	
	bar.Size = UDim2.new(1,0,1,0)
	
	skillCooldowns[skill] = cooldown
	
	
	bar:TweenSize(
		UDim2.new(1, 0,0, 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Linear,
		skillCooldowns[skill],
		true
	)
	
end)


--[[

	bar:TweenSize(
		UDim2.new(ratio, 0, 1, 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		0.2,
		true
	)

]]