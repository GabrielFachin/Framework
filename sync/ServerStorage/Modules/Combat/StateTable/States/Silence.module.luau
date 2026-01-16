local Enum = require(script.Parent.Parent.Enum)

return {
	data = {
		name = "Silence",
		category = Enum.Categories.Silence,
		exclusive = false,
		
		tags = {
			[Enum.Tags.CanMove] = false,
			[Enum.Tags.CanCast] = true, -- Verifique se essa lógica está correta para seu jogo
		},
		
		visual = {}
	},
	
	callbacks = {}
}