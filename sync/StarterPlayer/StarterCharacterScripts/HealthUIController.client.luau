local RS = game:GetService("ReplicatedStorage")
local tween = game:GetService("TweenService")

local updateHPBar = RS.RemoteEvents:WaitForChild("UpdateHealthBar")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = player:WaitForChild("PlayerGui"):WaitForChild("HealthGUI")
local barFrame = gui:WaitForChild("Healthbar")
local progressBar = barFrame:WaitForChild("Healthbar")
local percentage = barFrame:WaitForChild("percentage")




local full = Color3.fromRGB(50,255,50)
local mid = Color3.fromRGB(255,200,50)
local low = Color3.fromRGB(255,50,50)

local function updateBar(current,max)
	local ratio = math.clamp(current/max, 0, 1)
	
	progressBar:TweenSize(
		UDim2.new(ratio, 0, 1, 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		0.2,
		true
	)
	
	percentage.Text = tostring(math.floor(ratio * 100)) .. "%"
	
	local color = full
	if ratio < 0.35 then
		color = low
	elseif ratio < 0.65 then
		color = mid
	end
	
	progressBar.BackgroundColor3 = color
end

updateHPBar.OnClientEvent:Connect(updateBar)
