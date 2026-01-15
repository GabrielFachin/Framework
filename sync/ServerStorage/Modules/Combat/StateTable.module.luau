-- Categorias (nomes das flags de status, devem ser declaradas aqui e só usar a váriavel pra trabalhar os dados, evitando erros de digitação e centralizando os dados)

-- [ STATUS ] --

Buff = "Buff" --Buff

Movement = "Movement" --Status relacionado a movimentos (como dashing)

Debuff = "Debuff" --Debuff

DOT = "DamageOverTime"




-- [ ESTADOS ] --

Player = "PlayerState" --Estados interno do player

Stun = "Stun"

noControl = "noControl"

Root = "Root"

Silence = "Silence"

PlayerState = "PlayerState"

EffectShield = "EffectShield"

-- [ TAGS DE BYPASS ] --

--[[Essas tags são utilizadas pra ignorar certos comportamentos]]

canCancel = "Cancel"   --Essa tag é mais pra uso interno da skill na hora de conversar com o combatData, não deve ser levada em consideração com as outras tags de bypass

----------------------------------------------

blockBreak = "BlockBreak" --Qubra a defesa do adversario, também vai ser mais tratado como uma tag interna mas pode ser utilizada pra quebrar certos status e ignorar

trueHit = "TrueHit"       --Ignora qualquer tipo de imunidade


-- [Tags de breakpoints pra ativação de status] --
local reactTags = {
	onHeal = "OnHeal",       --Ativa o status quando o alvo recebe cura
	onDamage = "OnDamage",   --Ativa o status quando o alvo recebe dano
	onKill = "OnKill",       --Ativa o status quando o alvo morre
}


--==[ INFORMAÇÕES EXTRAS ]==--

--categoria: tipo do buff/debuff

--exclusivo: Substitui outros efeitos do mesmo tipo, como Stunned podendo substituir frozen, ou frozen tendo a maior prioridade e se mantendo

--stackavel: Permite stacks como bleed x5 (não declarar caso não necessário)

--Flags: Flags relacionadas ao comportamento da skill no alvo

--Visual: Efeitos, animação e afins


--Estados de casos específicos podem (E DEVEM) ser declarados dentro dos dados base do personagem, seguindo um padrão parecido com o que temos aqui, isso também vale pra modifiers!


-- Tags padrão no caso de não declaração
local tagsBase = {
	canMove = true,
	canCast = true,
	canControl = true, --tag utilizada pra impedir player de rotacionar!
	iFrame = false,
	stackable = false,
	exclusive = false,

}




local StateTable = { States = {} }

StateTable.reactTags = reactTags

-- =============[ TABELA DE AÇÕES DO PLAYER ]==================== --

--Essa tabela deve somente conter as ações que o player pode executar, facilitando assim o acesso e teste de flags quando for testar estados no CD (Combat Data), deve ser tratada como enum global

StateTable.PlayerActions = {

	Cast = "CanCast",
	Move = "CanMove",
	Block = "CanBlock",

}



--==[ ESTADOS INTERNOS DO PLAYER ]==--


StateTable.PlayerStates = {
	
	--Estados do player que permitem o cancelamento interno (pelo player)
	Self = { 
		selfCast = {
			data = {
			category = PlayerState,
			exclusive = true,
			name = "SelfCast",
			},
			
			callbacks = {}
			
			},
		globalCast = {
			data = {
			category = PlayerState,
			exclusive = true,
			name = "GlobalCast"
			},
			callbacks = {}

			},
		},
	
		--Estados do player que permitem cancelamento externo (inimigos)
	Out = {
		cast = {
			data = {
			category = PlayerState,
			exclusive = true,
			name = "Cast",
			},
			callbacks = {}
				
			},
		globalCast = {
			data = {
			category = PlayerState,
			exclusive = true,
			name = "GlobalCast",
			},
			callbacks = {}
				
			},
		}, 
	
	LockedCast = {
		data = {
			category = PlayerState,
			exclusive = true,
			name = "LockedCast",
		},
		callbacks = {}
	},
	
	--LockedCast também é um estado, mas como não permite o cancelamento interno nem externo é somente utilizado como flag de controle, bloqueando o casting de outras skills no processo
	
}




--==[ ESTADOS DE CONTROLE ]==--

StateTable.States = {
	
	--Nome do estado
	stun = {
		data = {
		category = Stun, --Categoria de controle, ou seja, altera funções de controle do player
		exclusive = false,   --Garante exclusividade, ou seja, não permite que outro estado do mesmo tipo (no caso, controle) seja aplicado
		name = "Stun", 		--Nome utilizado pra acesso e armazenamento de dados nos gerenciadores
		
		tags = {			--Flags de status que alteram a possibilidade de ações do player (mais informaçõpes na tabela PlayerActions)
			canMove = false, 
			canControl = false,
		},
		
		visual = {
			anim = "StunAnim",
			VFX = "StunEffect",
			particles = "StunParticles"
		},
		},
		callbacks = {}
	},


	root = {
		data = {
		category = Root,
		exclusive = false,
		name = "Root",
		tags = {
			canMove = false,
		},
		visual = {
			anim = "RootAnim"
		}
		},
		callbacks = {}
	},
	
	Silence = {
		data = {
		category = Silence,
		exclusive = false,
		name = "Silence",
		tags = {
			canMove = false,
			canCast = true,
		},
		visual = {
			anim = "RootAnim"
		}
		},
		callbacks = {}
	},	
	
	
	noControl = {					--Estado utilizado pra desativar qualquer ação do player, mais utilizado pra coisas como animações de movimento
		data = {
			category = noControl,
			exclusive = false,
			name = "noControl",
			tags = {
				canMove = false,
				canControl = false,
			},
			visual = {
			}
		},
		callbacks = {},
		}
	
}

StateTable.Status = {
	

	--==[  BUFFS  ]==--
	
	
	iFrame = {
		data = {
			category = Buff,
			exclusive = false,
			name = "iFrame",
			tags = {iFrame = true},
			bypassBy = {trueHit}
		},
		
		callbacks = {}
	},
	
	
	 Bleed = {
			data = {
		name = "Bleed",
		category = DOT,
		exclusive = false,
		stackable = true,
		stackOnSelf = true, 
		maxStacks = 10,
		duration = 0, 
		tickRate = 0.5, 
		damage = 1,
		cooldown = 1,
		
		flags = {canCancel}
	
	
		},
		
		callbacks = {
			
			onStart = function(self)
				self._tickTimer = 0
			end,

			onStep = function(self, dt)
				self._tickTimer += dt
				if self._tickTimer >= (self.skillData.data.tickRate or 0) then
					self._tickTimer = 0
					
					local damage = self.skillData.data.damage * self.counter
					self.Entity.TakeDamage(damage, self) -- Status se envia como parametro
				end
			end,

		}
	},

	
	--Exemplo de buff que ignora efeitos especificos
	StatusShield = {
    data = {
		exclusive = true,
        name = "StatusShield",
        category = Buff, 
        ShieldsFrom = {DOT}
   		 },
    callbacks = {}

	},


		
	--==[ DEBUFFS ]==--
}

--Prepara as tags usando as tags base estabelicidas caso não tenham sido declaradas
function StateTable:GetTags(stateName)
	local state = self.States[stateName]
	if not state or not state.tags then 
		return tagsBase 
	end

	return setmetatable(state.tags, { 
		__index = tagsBase
	})
end


--Verifica se o estado existe na tabela
function StateTable:IsState(meta)
	if not meta or not meta.name then return false end


	if self.States[meta.name] then return true end


	for _, group in pairs(self.PlayerStates) do
		if type(group) == "table" then
			for name, state in pairs(group) do
				if state.data and state.data.name == meta.name then
					return true
				end
			end
		end
	end

	if meta.category == PlayerState then
		return true
	end

	return false
end

return StateTable