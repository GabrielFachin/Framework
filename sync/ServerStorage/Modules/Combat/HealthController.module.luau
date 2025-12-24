local HealthController = {}
HealthController.__index = HealthController

function HealthController.new(maxHP)
	local self = setmetatable({}, HealthController)
	self.MaxHP = maxHP or 100
	self.HP = self.MaxHP
	self.IsDead = false
	return self
end

function HealthController:ApplyDamage(amount)
	self.HP = math.max(0, self.HP - amount)
end

function HealthController:GetHP()
	return self.HP
end

function HealthController:GetMaxHP()
	return self.MaxHP
end

function HealthController:SetHP(value)
	self.HP = math.clamp(value, 0, self.MaxHP)
end

function HealthController:IsAlive()
	return not self.IsDead
end

return HealthController
