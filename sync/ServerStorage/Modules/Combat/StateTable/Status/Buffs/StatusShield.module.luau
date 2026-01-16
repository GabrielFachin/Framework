local Enum = require(script.Parent.Parent.Parent.Enum)

return {
	data = {
		name = "StatusShield",
		category = Enum.Categories.Buff,
		exclusive = true,
		
		-- Lista de categorias/traits que este escudo bloqueia
		ShieldsFrom = {Enum.Traits.DOT}
	},
	
	callbacks = {}
}