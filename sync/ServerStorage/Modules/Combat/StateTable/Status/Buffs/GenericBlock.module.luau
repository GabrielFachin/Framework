local Enum = require(script.Parent.Parent.Parent.Enum)

return {
	data = {
		name = "GenericBlock",

		category = Enum.Categories.Internal,
		
		tags = {
			[Enum.Tags.block] = true
		},
		
		-- Define o que ignora esse buff (TrueHit ignora iFrame)
		bypassBy = {Enum.Traits.BlockBreak},
        
        ShieldsFromType = {Enum.Types.Skill, Enum.Types.Status},

        --dados especificos de shield, como apenas dano fisico, só DOT, etc...
        ShieldsFrom = {}
	},
	
    --função de exemplo, mas ela pode ser injetada pela skill que aplica o block e redirecionar o trigger pra si mesma
	callbacks = {
        onTriggerAction = function(runner,context)  warn("block atingido:",context.data.name)end
    }
}