local Enum = require(script.Parent.Parent.Enum)

return {
	data = {
		name = "Root",
		category = Enum.States.Root,
		exclusive = false,
		
		tags = {
			[Enum.Tags.canMove] = false,
		},
		
		visual = {}
	},
	
	callbacks = {}
}