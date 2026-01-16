local Enum = require(script.Parent.Parent.Enum)

return {
	data = {
		name = "Stun",
		category = Enum.Categories.Stun,
		exclusive = false,
		
		tags = {
			[Enum.Tags.CanMove] = false,
			[Enum.Tags.CanControl] = false,
		},
		
		visual = {}
	},
	
	callbacks = {}
}