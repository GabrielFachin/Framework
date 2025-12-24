--===================================================================================================================================== --
-- === COMBAT DATA SERVE COMO UMA API DE ACESSO E APLICAÇÃO DE DADOS, CENTRALIZANDO TUDO E REDIRECIONANDO PROS SCRIPTS RESPONSÁVEIS === --
--===================================================================================================================================== --

local Script = game:GetService("ServerScriptService")
local Storage = game:GetService("ServerStorage")

local StateTable = require(Storage.Modules.Combat.StateTable)
local StatusController = require(Storage.Modules.Combat.StatusController)
local HealthModule = require(Storage.Modules.Combat.HealthController)

local AnimationController = require(Storage.Modules.Animation.AnimationController)

local RS = game:GetService("ReplicatedStorage")
local UpdateHPBar = RS.RemoteEvents:WaitForChild("UpdateHealthBar")

local CombatData = {}
CombatData.__index = CombatData

function CombatData.new(player,TPD)
	local self = setmetatable({}, CombatData)

	self.Player = player
	self.Character = player.Character or player.CharacterAdded:Wait()
	self.Humanoid = self.Character:WaitForChild("Humanoid")
	self.Root = self.Character:WaitForChild("HumanoidRootPart")
	self.tpd = TPD
	

	self.Status = StatusController.new(self)
	
	local animator = self.Humanoid:FindFirstChildOfClass("Animator")

	self.Anim = AnimationController.new(animator)
	
	return self
end

-- Apenas repassa a aplicação do status para o StatusController (já devolve o ID criado)
function CombatData:ApplyStatus(Data, targetTPD, duration, sourceSkill,ID)
	return self.Status:HandleApplication(Data, targetTPD, duration, sourceSkill, ID) --Envia pro StatusController fazer o direcionamento pro StatusHandler antes de aplicar
end

-- Verifica se o player pode realizar a ação
function CombatData:Test(actionTag)
	local tags = self.Status:GetActiveTags()
	return tags[actionTag]
end

-- Tags ativas combinadas de status e estados
function CombatData:GetCombinedTags()
	return self.Status:GetActiveTags()
end

-- Conta quantas vezes um efeito está ativo
function CombatData:Count(effect)
	local name = effect.data.name
	return self.Status:GetCounter(name)
end

-- Remove manualmente um efeito
function CombatData:Remove(effect)
	local name = effect.data.name
	self.Status:Remove(name)
end


--Gera um novo ID
function CombatData:CreateID(sourceName)
	return self.Status:generateUniqueId(sourceName)
end


--Remove um efeito por ID
function CombatData:RemoveID(ID)
	return self.Status:RemoveById(ID)
end



-- ============================================= --
-- ==    VALIDAÇÃO DE INTERAÇÃO / BYPASS      == --
-- ============================================= --

-- Pega os dados pra iniciar a interação, se encontrar, então comece a interação com testes de tags e estados chamando TryInteract
function CombatData:TryHit(target, skillFlags)
	local targetCD = self:_ResolveCombatData(target) --Busca o CombatData do alvo e começa a rodar os dados internamente pelo alvo
	if not targetCD then return false, warn("CombatData de ",target," não encontrado") end
	return self:TryInteract(targetCD, skillFlags) --Se conseguir, começa a interação
end


--Começa os testes e validações entre origem e alvo
function CombatData:TryInteract(targetCombatData, effectFlags)
	local targetTags = targetCombatData:GetCombinedTags()					--Pega as tags do alvo
	local immunityRules = self._immunityRules or self:_InitImmunityRules()	--Inicializa as regras de imunidade

	for immunityName, rule in pairs(immunityRules) do						--Pra cada tag na presente, roda obtendo o nome da tabela e o valor
		if targetTags[immunityName] then									--Se encontrar uma tag no alvo que bate com as regras ja estabelecidas
			local allowed = false											--Não entrega permissão ainda
			for _, flag in ipairs(effectFlags or {}) do						--Pega as strings dentro das tags
				if table.find(rule.bypassableBy, flag) then					--Se encontrar uma tag que bata com a regra, entrega permissão
					allowed = true
					break
				end
			end
			if not allowed then												--Se a permissão não for garantida então retorne e fale o motivo
				return false, immunityName
			end
		end
	end

	return true
end


--Inicializa as regras de imunidade
function CombatData:_InitImmunityRules()								--Prepara as regras de imunidade buscando por tags que tenham bypassBy
	local rules = {}


	for name, def in pairs(StateTable.Status) do						--Pega os status e suas tags
		local data = def.data or def
		local tags = data.tags or {}

		for tagName, isTrue in pairs(tags) do							--Loopa cada item da tabela, retornando o nome e o valor da tag (true ou false)
			if isTrue and data.bypassBy then							--Se a tag for true e tiver bypassBy
				rules[tagName] = {										--Adiciona esses dados na tabela temporária de regras do alvo
					name = name,
					bypassableBy = data.bypassBy,						--Se o valor tiver uma forma de bypass é considerado defensivo e vem pra lista!
				}
			end
		end
	end

	self._immunityRules = rules
	return rules													  --Devolve essa tabela
end


-- ============================================= --
-- ==           APLICAÇÃO DE DANO             == --
-- ============================================= --



-- Aplica dano ao alvo, caso seja uma skill não tem necessidade de passar sourceData

function CombatData:ApplyDamage(amount, sourceData)		--Essa função roda INTERNAMENTE em quem vai receber o dano e só deve ser chamada por quem está recebendo o dano
														--A mesma ainda passa por validações de tag, permitindo status a conectar diretamente no pedido de dano (já que já estão localmente no alvo)
	local sourceCombatData = nil						
	local effectFlags = {}

	-- extrai flags e CombatData de origem
	if type(sourceData) == "table" and sourceData.skillData then
		local skillData = sourceData.skillData								--Pega os dados da habilidade/status que chamou a intenção
		sourceCombatData = sourceData.tpd and sourceData.tpd.CombatData		--Pega o tpd e o cd da origem do pedido
								
		if skillData.data and skillData.data.flags then						--Se tiver flags então guarde elas
			effectFlags = skillData.data.flags
		end
	end


	-- Validação de imunidade / interações
	if sourceCombatData then
		local success, reason = sourceCombatData:TryInteract(self, effectFlags) --Testa se o alvo pode receber o dano
		if not success then														
			warn("Dano bloqueado por:", reason)									--Devolve o motivo do dano ter sido ignorado
			return false, reason
		end
	end

	-- Aplica modificadores de dano
	amount = self:ModifyDamage(amount, sourceCombatData, effectFlags)

	self:TryCancel(effectFlags)

	-- Busca o sistema de vida utilizado atualmente (própio ou do roblox? pra suporte de transição ao novo sistema de hp em breve)
	local healthObj = self:GetHealthController()
	if not healthObj then
		warn("CombatData sem referência de vida")
		return false
	end

	
	local hp = self:GetHealthController()
	if not hp or typeof(hp.ApplyDamage) ~= "function" then
		warn("CombatData sem sistema de vida válido")
		return false
	end

	hp:ApplyDamage(amount)
	--Atualiza a barra de vida!
	
	local currentHP = hp:GetHP()
	local maxHP = hp:GetMaxHP()
	UpdateHPBar:FireClient(self.Player,currentHP,maxHP)
	
	print(currentHP)
	if currentHP <= 0 then
		print(self.Humanoid.Health)
		self.Humanoid.Health = 0
	end
end


	function CombatData:SetHealthController(controller)
		self.HealthController = controller
	end


	function CombatData:GetHealthController()
		return self.HealthController
	end
	
	
	
function CombatData:ModifyDamage(amount, sourceCombatData, flags)
	
	-- Função já chamada por outras partes no código, basta adicionar os testes pra redução ou aumento de dano aqui
	
	return amount
end


-- Devolve o combatData do alvo com validação de existencia
function CombatData:GetTarget(target)
	local targetCD = self:_ResolveCombatData(target)
	if not targetCD then
		warn("CombatData do alvo não encontrado:", target)
		return nil
	end
	return targetCD
end


-- Devolve o CD do alvo
function CombatData:_ResolveCombatData(target)
	if target and target.CombatData then
		return target.CombatData
	end
	return nil
end

function CombatData:TryCancel(effectFlags)
	
	if not table.find(effectFlags, "Cancel") then return end

	for stateName, _ in pairs(self.Status.statuses.state) do
		print(stateName)
		local state = self.Status:GetPlayerState(stateName)
		if state and state.data.data.category == "PlayerState" then
			for k,v in pairs(StateTable.PlayerStates.Out) do
				if v.data.name == stateName then

			local runner = state.sourceSkill or state.sourceRunner or state.runner
			if runner and typeof(runner) == "table" and runner.Stop then
				runner:Stop(true)
				warn("Cancelamento aplicado, estado:", stateName)
				end
				end
			end
		end
	end
end




--Função de tentativa de cancelamento, mas chamada pra testes internos do dono do pedido
function CombatData:TrySelfCancel()


	for stateName, _ in pairs(self.Status.statuses.state) do

		local state = self.Status:GetPlayerState(stateName)
		if state and state.data.data.category == "PlayerState" then

			for k,v in pairs(StateTable.PlayerStates.Self) do

				if v.data.name == stateName then

					local runner = state.sourceSkill or state.sourceRunner or state.runner
					if runner and typeof(runner) == "table" and runner.Stop then

						runner:Stop(true)
						warn("Cancelamento aplicado, estado:", stateName)
						return true
					end
				end
			end
			return false --Se encontrar um PlayerState, então retorne false
		end
	end
		return true --Se não encontrar nada, retorne true e siga o caminho pra instanciação
end


--Checa se poderia se auto cancelar caso necessário, se o estado do player tá ok pra continuar o casting e se não existe nenhuma tag que impeça o cast
function CombatData:CanContinue()
	
	--Testa por silence
	local tags = self:GetCombinedTags()
	if tags["canCast"] == false  then
		warn("Player não pode castar!")
		return false
	end
	
	local rawState = self.Status:GetActivePlayerState()
	if not rawState then return true end

	local activeState = rawState.data
	-- Testa se o estado atual está na tabela Self
	for _, stateDef in pairs(StateTable.PlayerStates.Self) do
		if activeState.data.name == stateDef.data.name then
			return true -- Pode continuar e cancelar a própria

		end
	end

	-- Estado ativo não está em Self  não pode continuar
	return false
end






--=====================================================---
--==                   ANIMAÇÕES                     ==---
--=====================================================---




function CombatData:PlayAnim(animId, key, fade, weight)
	if self.Anim then
		return self.Anim:Play(animId, key, fade, weight)
	end
end

function CombatData:StopAnim(key, fade)
	if self.Anim then
		self.Anim:Stop(key, fade)
	end
end

function CombatData:GetAnimMarker(key, marker)
	if self.Anim then
		return self.Anim:GetMarkerReachedSignal(key, marker)
	end
end

function CombatData:StopAllAnim(fade)
	if self.Anim then
		self.Anim:StopAll(fade)
	end
end

function CombatData:PlayAnimSequence(seq, loop)
	if self.Anim then
		self.Anim:PlaySequence(seq, nil, loop)
	end
end


return CombatData
