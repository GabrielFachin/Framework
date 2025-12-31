local StarterPlayer = game:GetService("StarterPlayer")
local TouchJump = require(StarterPlayer.StarterPlayerScripts.PlayerModule.ControlModule.TouchJump)
-- ============================= SCRIPT USADO PRA ABSTRAÇÃO ENTRE CUSTOM MODELS E HUMANOIDS =====================================


local EntityWrapper = {}

-- ========== INTERFACES (Contratos) ========== --

--[[
    IMovement - Interface para movimento
]]
local IMovement = {}

function IMovement:SetSpeed(speed) end
function IMovement:GetSpeed() end
function IMovement:SetJumpPower(power) end

-- ========== IMPLEMENTAÇÕES ========== --

--[[
    HumanoidMovement - Implementação para Humanoids
]]
local HumanoidMovement = {}
HumanoidMovement.__index = HumanoidMovement

function HumanoidMovement.new(humanoid, baseSpeed, baseJumpPower)
	local self = setmetatable({}, HumanoidMovement)

	self._humanoid = humanoid
	self._baseSpeed = baseSpeed or 16
	self._baseJumpPower = baseJumpPower or 50


	return self
end

function HumanoidMovement:SetSpeed(speed)
	if not self._frozen then
		self._humanoid.WalkSpeed = speed
	end
end

function HumanoidMovement:GetSpeed()
	return self._humanoid.WalkSpeed
end

function HumanoidMovement:SetJumpPower(power)
		self._humanoid.JumpPower = power
end

--[[
    NPCMovement - Implementação para NPCs sem Humanoid
    Usa BodyVelocity/AlignPosition para movimento
]]

local NPCMovement = {}
NPCMovement.__index = NPCMovement

function NPCMovement.new(root, baseSpeed, jumpPower)
	local self = setmetatable({}, NPCMovement)

	self._root = root
	self._baseSpeed = baseSpeed or 16
	self._currentSpeed = baseSpeed
	self._jumpPower = jumpPower or 50

	return self
end

function NPCMovement:SetSpeed(speed)
	self._currentSpeed = speed
end

function NPCMovement:GetSpeed()
	return self._currentSpeed
end

function NPCMovement:SetJumpPower(power)
	self._jumpPower = power
end

function NPCMovement:Destroy()
	self._alignPos:Destroy()
end


-- ========== FACTORY ========== --

EntityWrapper.CreateMovement = function(entity)
	if entity.Humanoid then
		local stats = entity.Character:FindFirstChild("_Stats")
		local baseSpeed = stats and stats:GetAttribute("Speed") or 16
		local baseJump = stats and stats:GetAttribute("JumpPower") or 50

		return HumanoidMovement.new(entity.Humanoid.Parent:FindFirstChild("HumanoidRootPart"), baseSpeed, baseJump)
	else
		-- NPC sem Humanoid
		local baseSpeed = entity:GetSpeed() or 16
		local baseJump = entity:GetJumpPower() or 50
		return NPCMovement.new(entity.Root, baseSpeed, baseJump)
	end
end
-- ========== EXPORTS ========== --
EntityWrapper.IMovement = IMovement

return EntityWrapper