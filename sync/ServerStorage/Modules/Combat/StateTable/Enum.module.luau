enum = {

             --=====ENUM PRINCIPAL=====-

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


    

    --Traits que não podem coexistir (da override uma na outra)
    ExclusiveTraits = {
        --exemplo
        block = {"blocking","parrying","countering"}
    },


    --Fala a qual grupo a trait pertence
    TraitToExclusiveGroup = {
        --exemplo
        blocking = "block",
        parrying = "block",
        countering = "block",
    },




        --====BREAKPOINTS=====--


    reactTags = {
	    onHeal = "OnHeal",              --Ativa o status quando o alvo recebe cura
	    onDamage = "OnDamage",          --Ativa o status quando o alvo recebe dano
	    onDeath = "OnDeath",            --Ativa o status quando o alvo morre
    },


    SkillBreakpoints = {
        onTrigger = "onTriggerAction",
        onRecast = "onRecast",
        onHit = "onHit",
        onEnd = "onEnd"
    },




    --=====TAGS=====--


--tags são dados 
Tags = {
    canMove = "canMove",
    canCast = "canCast",
    canControl = "canControl",
    iFrame = "iFrame",
    block = "block",
    stackable = "stackable",
    exclusive = "exclusive"
},



--fallback pra caso de não declaração dessas tags
 tagsBase = {
	canMove = true,
	canCast = true,
	canControl = true, --impede rotação do player
	iFrame = false,
    block = false,
	stackable = false,
	exclusive = false,

	}
    
}



return enum 