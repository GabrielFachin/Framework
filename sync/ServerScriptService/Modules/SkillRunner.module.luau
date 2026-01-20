--=================Esse módulo controla o ciclo de vida das skills, TODAS as skills e modificadores são gerados com um SR base=================

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Storage = game:GetService("ServerStorage")
local StateTable = require(ServerStorage.Modules.Combat.StateTable)
local Utils = require(ReplicatedStorage.Utils)

local SkillRunner = {}
SkillRunner.__index = SkillRunner


local STATES = {  				--Breakpoints do ciclo de vida da skill
	Idle = "Idle",
	Casting = "Casting",
	Running = "Running",
	Ended = "Ended",
}


function SkillRunner.new(skillData,Entity,name,SRtype) --Instancia o SkillRunner como um objeto responsável de criar a habilidade junto do EntityData para as skills utilizarem

	--================VÁRIAVEIS(FACILITAÇÃO DE ACESSO)===================--

	local self = setmetatable({}, SkillRunner)


	--======REQUIRES======--
	self.lib = require(Storage.Modules.Animation.AnimationLib) 					--Prepara a lib de animações
	self.connection = require(Storage.Modules.SkillScheduler) 					--Heartbeat global
	self.statusTable = require(Storage.Modules.Combat.StateTable) 				--Facilita acesso a aplicação de estados pelas skills
	self.weaponHitboxModule = require(Storage.Modules.Combat.ShapecastHitbox)   --Prepara o modulo do shapecast para facil acesso e criação de hitboxes




	--=====DADOS VITAIS=====--

	self.skillData = Utils.deepCopy(skillData)   --Informações extras da skill que vai rodar
	self.Entity = Entity		 				 --Tabela de dados do player que usou a habilidade



	--=====INICIALIZAÇÃO SR=====--
	local runnerType = self.skillData.data.type or SRtype

	self.state = STATES.Idle 	 		--Estado do lifetime skill
	self.elapsedTime = 0    	 		--Tempo de vida atual da skill
	self.counter = 1      		 		--Pode ser utilizado por skills e/ou status pra manter controle de dados de runtime internos, como número de balas, stage, ou stacks aplicados
	self.type = runnerType		 		--Tipo de SR, Skill, Status
	self.skillName = name  		 		--Guarda o nome da skill pra controle de runners ativos



	--=====FACILITADORES DE ACESSO=====--

	if self.Entity then
		
		if Entity:HasComponent(Entity.ComponentKey.Animation) then
			self.charLib = self.lib.character[self.Entity.GetChosenChar()] 	--Biblioteca de animações do char escolhido
		end

		if self.Entity:HasComponent(self.Entity.ComponentKey.Weapon) then

		self.hitPoint = self.Entity.GetHitOrigin() 							--Origem de hitboxes criadas em runtime pela arma
		self.weapon = self.Entity.GetWeapon()						   	    --Arma sendo utilizada pelo player

		end
	end


	self.data      = skillData.data
	self.callbacks = skillData.callbacks
	self.utils     = skillData.utils or {}
	
	

	--=====HISTÓRICO DE INTERAÇÕES SEQUENCIAIS=====--
    if skillData.ChainHistory then
        self.ChainHistory = skillData.ChainHistory
    else
        -- Fallback para casos onde o runner é criado sem input direto
        self.ChainHistory = {
            rootOrigin = Entity and Entity or "Unknown",
            rootSkill = name,
            history = {name},
            depth = 1,
            uniqueChainID = "SYSTEM_" .. tostring(tick())
        }
    end
	
	return self
end




--================================================
--				 LIFECYCLE
--================================================


function SkillRunner:start()
	
	--Conecta com o heartbeat global para rodar o onStep
	self.connection.Register(self,self.type)
	
	self.state = STATES.Casting --Estado de inicialização da skill


	if self.Entity then
		if self.Entity:HasComponent(self.Entity.ComponentKey.Combat) then
			self.Entity.AddActiveSkill(self.skillName,self)	
		end
		
		 if self.Entity:HasComponent(self.Entity.ComponentKey.Weapon) then
			self.Entity.AddHitboxOwner(self) --Informa que o dono da skill é esse skillRunner, permitindo que o wrapper chame o onHit direto por aqui
		end
	end

	
	--Confere se existe onStart na skill, se sim, roda
	if self.skillData.callbacks.onStart then
		self.skillData.callbacks.onStart(self) --Executa onStart tendo acesso aos dados do SkillRuner, útil pra alterações e intarções durante Runtime
	end
	
end


--[[
Controla o tempo de execução do SkillRunner (atualizado pelo Heartbeat global)
]]
function SkillRunner:_internalUpdate(dt)
	
	--Controle do timer da skill
	 self.elapsedTime += dt


	--Se estiver castando algo, confere se já terminou a duração do cast, se sim, mude o estado para "rodando"
	if self.state == STATES.Casting then
		if self.skillData.data.castTime and self.elapsedTime >= self.skillData.data.castTime then
			self.state  = STATES.Running 
			self.elapsedTime = 0
		end

	--Se estiver running:
	elseif self.state == STATES.Running then
		if self.skillData.callbacks.onStep then  --confere  se o skillData tem onStep para rodar scripts em frames/tempos especificos, se tiver, rode o onStep do frame atual
			self.skillData.callbacks.onStep(self,dt)
		end
	
	end

	local duration = self.skillData.runtimeDuration or self.skillData.data.duration

	--Se a skill tiver zerado sua duração, então: 
	if duration and self.elapsedTime >= duration then
		self:endSkill(false)
	end
	
end

--[[Callback ao atingir algo]]
function SkillRunner:onHit(data)
	if self.skillData.callbacks.onHit then
		self.skillData.callbacks.onHit(self,data)
	end
	
end


--[[Recast de runner]]
function SkillRunner:Recast(checkOnly : boolean?)
	
	--Procura se tem onRecast, se tiver, roda e fala que encontrou
	if self.skillData.callbacks.onRecast ~= nil then
		
		--Se for um pedido de teste, retorna antes de rodar o recast
		if checkOnly then return true end
		
		--roda o onRecast com contexto pra permitir informar o motivo/origem do recast
		self.skillData.callbacks.onRecast(self)
		return true
	end

end


--[[
Trigger externo, usado especialmente mas não exclusivamente por blocks e shields de efeitos
@param data - dados de quem deu trigger
]]
function SkillRunner:TriggerAction(context : {}?)
    local skillSettings = self.skillData.data
    local hasFilterConfig = skillSettings.ShieldsFrom or skillSettings.ShieldsFromType

    if hasFilterConfig then
        if not self.statusTable.CheckBlockFilter(self, context) then
            return nil 
        end
    end


    	if self.skillData.callbacks.onTriggerAction then
    	    return self.skillData.callbacks.onTriggerAction(self, context)
    	end
    
    return nil
end


--[[Cancela a skill
@param cancel - boolean, se a skill foi cancelada forçadamente de forma externa
]]
function SkillRunner:Stop(cancel : boolean?)
	self:endSkill(cancel)
end


--Finaliza a skill
function SkillRunner:endSkill(cancel)

	--Se foi cancelada externamente
	if cancel then
		if self.skillData.callbacks.onCancel then
			local stop = self.skillData.callbacks.onCancel(self)   --Roda a ação da skill ao ser cancelada
			warn("[SkillRunner] Skill cancelada:", self.skillName) 
			if not stop then self.state = STATES.Running end	   --Permita que somente a ação ocorra sem parar a skill.
		end
	end	
	
	if self.state == STATES.Ended then return end
	self.state = STATES.Ended


	--Sequência de finalização padrão
	if self.skillData.callbacks.onEnd then
		self.skillData.callbacks.onEnd(self)
	end
	
	if self.Entity then
		self.Entity.RemoveActiveSkill(self.skillName, self)
		if self.Entity:HasComponent(self.Entity.ComponentKey.Weapon) then
			self.Entity.RemoveHitboxOwner(self) --Limpa a hitbox
	end
end


	if self.connection then
		self.connection:Unregister(self,self.type) --Sai do heartbeat global
		self.connection = nil
	end

	-- Sempre limpar o runner e notificar
	if self.onFinish then self.onFinish() end
	
end

return SkillRunner
