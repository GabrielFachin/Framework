enum = {

             --=====ENUM PRINCIPAL=====-

    --Categoria de status
    Categories = {
        Buff = "Buff",          --Buff
        Hybrid = "Hybrid",      --Status relacionado com buff e debuff
        Debuff = "Debuff",      --Debuff
        Player = "PlayerState", --Uso interno
        Internal = "Internal",  --Categoria interna pra impedir interações inesperadas
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
        Stackable = "stackable",
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


--tags são dados binários envolvendo comportamento de status na entidade
Tags = {
    canMove = "canMove",
    canCast = "canCast",
    canRotate = "canRotate",
    iFrame = "iFrame",
    block = "block",
    exclusive = "exclusive"
},



--fallback pra caso de não declaração dessas tags
 tagsBase = {
	canMove = true,
	canCast = true,
	canRotate = true,
	iFrame = false,
    block = false,
	},
    

--====OUTROS====--

Types = {
    Skill = "Skill",
    State = "State",
    Status = "Status"
}

BlockIgnore = {
    self.Traits.TrueHit,
}

MAX_RECURSION = 20, -- limite de ações recursivas como parrys que ativam parrys

} return enum 