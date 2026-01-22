enum = {}

             --=====ENUM PRINCIPAL=====-

    --Categoria de status
enum.Categories = {
        Buff = "Buff",          --Buff
        Hybrid = "Hybrid",      --Status relacionado com buff e debuff
        Debuff = "Debuff",      --Debuff
        Player = "PlayerState", --Uso interno
        Internal = "Internal",  --Categoria interna pra impedir interações inesperadas
    }

enum.States = {
        Stun = "Stun",          --Perde todo e qualquer input
        noControl = "noControl",--Perde controle de input de movimentação
        Root = "Root",          --Imobiliza o personagem
        Silence = "Silence",    --Impede de usar skills
    }

    --Traits de status
enum.Traits = {
        DOT = "DamageOverTime",         --Dot
        EffectShield = "EffectShield",  --Escudo de efeito (ignora pre entrada)
        TrueHit = "TrueHit",            --Ignora iFrame
        SoftCancel = "lightCancel",     --Cancelamento fraco (TODO)
        HeavyCancel = "heavyCancel",    --Cancelamento forte (TODO)
        BlockBreak = "BlockBreak",      --Quebra o block do adversário (TODO)
        Stackable = "stackable",
    }


        --====BREAKPOINTS=====--


enum.reactTags = {
	    onHeal = "OnHeal",              --Ativa o status quando o alvo recebe cura
	    onDamage = "OnDamage",          --Ativa o status quando o alvo recebe dano
	    onDeath = "OnDeath",            --Ativa o status quando o alvo morre
    }


enum.SkillBreakpoints = {
        onTrigger = "onTrigger",
        onRecast = "onRecast",
        onHit = "onHit",
        onEnd = "onEnd"
    }




    --=====TAGS=====--


--tags são dados binários envolvendo comportamento de status na entidade
enum.Tags = {
    canMove = "canMove",
    canCast = "canCast",
    canRotate = "canRotate",
    iFrame = "iFrame",
    block = "block",
    exclusive = "exclusive"
}



--fallback pra caso de não declaração dessas tags
enum.tagsBase = {
	canMove = true,
	canCast = true,
	canRotate = true,
	iFrame = false,
    block = false,
	}


--====OUTROS====--

enum.Types = {
    Skill = "Skill",
    State = "State",
    Status = "Status"
}


enum.MAX_RECURSION = 50 -- limite de ações recursivas como parrys que ativam parrys


enum.BlockIgnore = {
	enum.Traits.TrueHit,
}

return enum 

