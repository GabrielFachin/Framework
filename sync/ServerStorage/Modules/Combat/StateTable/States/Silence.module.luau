local Enum = require(script.Parent.Parent.Enum)

return {
	data = {
		name = "Silence",
		category = Enum.States.Silence,
		exclusive = false,
		
		tags = {
			[Enum.Tags.canCast] = false,
		},
		
		visual = {}
	},
	
	callbacks = {}
}