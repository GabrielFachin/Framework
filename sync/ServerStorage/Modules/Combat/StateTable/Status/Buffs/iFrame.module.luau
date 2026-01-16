local Enum = require(script.Parent.Parent.Enum)

return {
	data = {
		name = "iFrame",
		category = Enum.Categories.Buff,
		exclusive = false,
		
		tags = {
			[Enum.Tags.IFrame] = true
		},
		
		-- Define o que ignora esse buff (TrueHit ignora iFrame)
		bypassBy = {Enum.Traits.TrueHit}
	},
	
	callbacks = {}
}