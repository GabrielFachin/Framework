local Enum = require(script.Parent.Parent.Enum)

local Bleed = {
	data = {
		name = "Bleed", 
		category = Enum.Traits.DOT,
		exclusive = false,
		stackable = true,
		stackOnSelf = true, 
		maxStacks = 10,
		duration = 5, 
		tickRate = 0.5, 
		damage = 1,
		
		flags = {Enum.Tags.CanCancel} 
	},
	
	callbacks = {
		onStart = function(self)
			self._tickTimer = 0
		end,

		onStep = function(self, dt)
			self._tickTimer += dt
			local tickRate = self.skillData.data.tickRate or 1 
			
			if self._tickTimer >= tickRate then
				self._tickTimer = 0
				
				local damage = self.skillData.data.damage * self.counter
				self.Entity.TakeDamage(damage, self) 
			end
		end,
	}
}

return Bleed