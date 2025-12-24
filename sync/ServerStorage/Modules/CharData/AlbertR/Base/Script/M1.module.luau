local Skill = {

	data = {
		cooldown = 1,
		duration = 1,
		castTime = 0,
		anim = "anim",
	},

	callbacks = {
		onStart = function(self)
			print("M1 rodando!")
		end,

		onStep = function(self, dt)
		end,

		onEnd = function(self)
		end,
	}

}

return Skill