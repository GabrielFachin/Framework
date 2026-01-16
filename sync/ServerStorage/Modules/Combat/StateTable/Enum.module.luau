--==[ INFORMAÇÕES EXTRAS ]==--

--categoria: tipo do efeito

--exclusivo: Substitui outros efeitos da mesma categoria (default false)

--stackavel: Permite stacks como bleed x5 (default false)

--Flags: Flags relacionadas ao comportamento da skill no alvo

--Visual: Efeitos, animação e afins


--Estados de casos específicos podem (E DEVEM) ser declarados dentro dos dados base do personagem, seguindo um padrão parecido com o que temos aqui, isso também vale pra modifiers!


enum = {

    --Categoria de status
    Categories = {
        Buff = "Buff",          --Buff
        Hybrid = "Hybrid",      --Status relacionado com buff e debuff
        Debuff = "Debuff",      --Debuff
        Player = "PlayerState", --Uso interno
    },

    States = {
        Stun = "Stun",          --Perde todo e qualquer input
        noControl = "noControl",--Perde controle de input de movimentação
        Root = "Root",          --Imobiliza o personagem
        Silence = "Silence",    --Impede de usar skills
    },

    --Traits de status
    Traits = {
        DOT = "DamageOverTime",         --Dot
        EffectShield = "EffectShield",  --Escudo de efeito (ignora pre entrada)
        TrueHit = "TrueHit",            --Ignora iFrame
        SoftCancel = "lightCancel",     --Cancelamento fraco (TODO)
        HeavyCancel = "heavyCancel",    --Cancelamento forte (TODO)
        BlockBreak = "BlockBreak",      --Quebra o block do adversário (TODO)
    },


    reactTags = {
	    onHeal = "OnHeal",              --Ativa o status quando o alvo recebe cura
	    onDamage = "OnDamage",          --Ativa o status quando o alvo recebe dano
	    onDeath = "OnDeath",            --Ativa o status quando o alvo morre
    },



Tags = {
    canMove = "canMove",
    canCast = "canCast",
    canControl = "canControl",
    iFrame = "iFrame",
    stackable = "stackable",
    exclusive = "exclusive"
},



--fallback pra caso de não declaração dessas tags
 tagsBase = {
	canMove = true,
	canCast = true,
	canControl = true, --impede rotação do player
	iFrame = false,
	stackable = false,
	exclusive = false,

	}
    
}



return enum 