local Enum = require(script.Parent.Parent.Enum)

return {
	data = {
		name = "Root",
		category = Enum.Categories.Root,
		exclusive = false,
		
		tags = {
			[Enum.Tags.CanMove] = false,
		},
		
		visual = {}
	},
	
	callbacks = {}
}