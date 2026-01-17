local Enum = require(script.Parent.Parent.Parent.Enum)

return {
	data = {
		name = "StatusShield",
		category = Enum.Categories.Buff,
		exclusive = false,
		
		ShieldsFrom = {Enum.Traits.DOT}
	},
	
	callbacks = {}
}