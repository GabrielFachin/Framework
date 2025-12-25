local Weapon = {}
Weapon.__index = Weapon

function Weapon.new(entity, characterModule)
	local self = setmetatable({}, Weapon)
	
	self.Entity = entity
	self.Character = characterModule
	self.Weapon = nil
	self.hitOrigin = nil
	
	return self
end

-- Dá attach da arma à entidade
function Weapon:setWeapon(modelName)
	if self.Weapon then return end

	local RS = game:GetService("ReplicatedStorage")
	local char = self.Character.Character
	local charStats = self.Character:getCharStats()
	local chosenChar = self.Character.ChosenChar

	if not char or not charStats then return end

	local weaponFolder = RS.Assets.Weapons:FindFirstChild(chosenChar)
	if not weaponFolder then return end
	
	local weaponModel = weaponFolder:FindFirstChild(modelName)
	if not weaponModel then return end

	local weaponClone = weaponModel:Clone()
	weaponClone.Name = weaponModel.Name
	weaponClone.Parent = char

	local handle = weaponClone:FindFirstChild("Handle")
	if not handle then return end

	-- Busca o membro de attach na arma
	local attach = weaponModel.AttachTo and weaponModel.AttachTo.value or charStats.attachTo
	if not attach then attach = "Right Arm" end

	local charAttach = char:FindFirstChild(attach)
	local CFrameValue = weaponClone:FindFirstChild("Value")

	-- Motor 6D
	local motor = Instance.new('Motor6D')
	motor.Part0 = charAttach
	motor.part1 = handle
	motor.C1 = CFrameValue.Value
	motor.Parent = handle

	self.hitOrigin = weaponClone:FindFirstChild("hitOrigin")
	self.Weapon = weaponClone

	return weaponClone
end

function Weapon:getWeapon()
	return self.Weapon
end

function Weapon:getHitOrigin()
	return self.hitOrigin
end

return Weapon
