local Stats = {}
Stats.__index = Stats

function Stats.new(entity, characterModule)
	local self = setmetatable({}, Stats)
	
	self.Entity = entity
	self.Character = characterModule
	self.BaseWalkSpeed = 16
	self.BaseJumpPower = 50
	
	return self
end

-- Inicializa velocidade e jump power do humanoid baseado nas stats do personagem
function Stats:Initialize(humanoid)
	if not humanoid then return end
	
	local charStats = self.Character:getCharStats()
	if not charStats then return end
	
	self.BaseWalkSpeed = charStats.Speed or 16
	self.BaseJumpPower = charStats.JumpPower or 50
	
	humanoid.WalkSpeed = self.BaseWalkSpeed
	humanoid.JumpPower = self.BaseJumpPower
end

return Stats
