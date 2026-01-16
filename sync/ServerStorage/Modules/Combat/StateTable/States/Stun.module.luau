local Enum = require(script.Parent.Parent.Enum)

return {
	data = {
		name = "Stun",
		category = Enum.States.Stun,
		exclusive = false,
		
		tags = {
			[Enum.Tags.canMove] = false,
			[Enum.Tags.canControl] = false,
			[Enum.Tags.canCast] = false
		},
		
		visual = {}
	},
	
	callbacks = {}
}