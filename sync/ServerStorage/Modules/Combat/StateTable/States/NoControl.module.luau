local Enum = require(script.Parent.Parent.Enum)

return {
	data = {
		name = "noControl",
		category = Enum.States.NoControl,
		exclusive = false,
		
		tags = {
			[Enum.Tags.canMove] = false,
			[Enum.Tags.canControl] = false,
		},
		
		visual = {}
	},
	
	callbacks = {}
}