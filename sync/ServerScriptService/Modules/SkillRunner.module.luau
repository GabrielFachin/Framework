--=================Esse módulo controla o ciclo de vida das skills, TODAS as skills e modificadores são gerados com um SR base=================

local RunService = game:GetService("RunService")
local Storage = game:GetService("ServerStorage")

local SkillRunner = {}
SkillRunner.__index = SkillRunner


local STATES = {  				--Breakpoints do ciclo de vida da skill
	Idle = "Idle",
	Casting = "Casting",
	Running = "Running",
	Ended = "Ended",
}


function SkillRunner.new(skillData,ED,name,type) --Instancia o SkillRunner como um objeto responsável de criar a habilidade junto do EntityData para as skills utilizarem
	local self = setmetatable({}, SkillRunner)
	self.lib = require(Storage.Modules.Animation.AnimationLib) --Prepara a lib de animações
	
	self.skillData = skillData -- Informações extras da skill que vai rodar
	self.ED = ED --Tabela de dados do player que usou a habilidade
	self.cd = self.ED.CombatData --Separa o CombatData pra fácil acesso pelas skills
	self.state = STATES.Idle --Estado do lifetime skill
	self.skillName = name   --Guarda o nome da skill pra controle de runners ativos
	self.elapsedTime = 0    --Tempo de vida atual da skill
	self.counter = 1      --Pode ser utilizado por skills e/ou status pra manter controle de dados de runtime internos, como número de balas, stage, ou stacks aplicados
	self.connection = require(Storage.Modules.SkillScheduler) --Heartbeat global
	self.stop = false --cancelada/parar a força?
	self.statusTable = require(Storage.Modules.Combat.StateTable) --Facilita acesso a aplicação de estados pelas skills
	self.anim = self.cd.Anim  --Fácil acesso ao controlador de animações
	self.charLib = self.lib.character[self.ED.ChosenChar]
	self.hitPoint = self.ED.hitPoint --Prepara a origen das hitboxes da arma
	self.weaponHitboxModule = require(Storage.Modules.Combat.ShapecastHitbox) --Prepara o modulo do shapecast para facil acesso e criação de hitboxes
	self.weaponHitboxFolder = Storage.Assets.Hitboxes:FindFirstChild(self.ED.ChosenChar) --Busca a pasta de hitboxes do personagem escolhido
	self.weaponHitbox = self.ED.Hitbox --Facilita acesso ao wrapper da hitbox
	self.weapon = self.ED.weapon --Pega a arma sendo utilizada pelo player
	self.type = type
	
	-- Facilita o acesso aos dados da skill.
	self.data      = skillData.data
	self.callbacks = skillData.callbacks
	self.utils     = skillData.utils or {}
	
	
	assert(ED and ED.addSkill, "SkillRunner recebeu ED inválido")
	
	return self
end





function SkillRunner:start()
	
	
	--Conecta com o heartbeat global para rodar o onStep
	self.connection.Register(self,self.type)
	
	self.state = STATES.Casting --Estado de inicialização da skill

	self.weaponHitbox:AddOwner(self) --Informa que o dono da skill é esse skillRunner, permitindo que o wrapper chame o onHit direto por aqui
	
	--Confere se existe onStart na skill, se sim, roda
	if self.skillData.callbacks.onStart then
		self.skillData.callbacks.onStart(self) --Executa onStart tendo acesso aos dados do SkillRuner, útil pra alterações e intarções durante Runtime
	end
	
	
	self.ED:addSkill(self.skillName,self)
end




--[[
Controla o tempo de execução do SkillRunner (atualizado pelo Heartbeat global)
]]

function SkillRunner:_internalUpdate(dt)
	
	--Controle do timer da skill
	 self.elapsedTime += dt

	--Se estiver castando algo, confere se já terminou a duração do cast, se sim, mude o estado para "rodando"
	if self.state == STATES.Casting  then
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
	
	
	--Se a skill tiver zerado sua duração, então: 
	if self.skillData.data.duration and self.elapsedTime >= self.skillData.data.duration then
		self:endSkill(false)
	end
	
end



function SkillRunner:onHit(data)
	if self.skillData.callbacks.onHit then
		self.skillData.callbacks.onHit(self,data)
	end
	
end



function SkillRunner:Recast(checkOnly)
	
	--Procura se tem onRecast, se tiver, roda e fala que encontrou
	if self.skillData.callbacks.onRecast then
		
		--Se for um pedido de teste, retorna antes de rodar o recast
		if checkOnly then return true end
		
		self.skillData.callbacks.onRecast(self)
		return true
	end

end


--Permite que o objeto fale que a skill foi cancelada de forma externa (chamando essa função)
function SkillRunner:Stop(cancel)
		self.stop = cancel
		self:endSkill(cancel)
end




--Finaliza a skill
function SkillRunner:endSkill(cancel)
	
	if self.state == STATES.Ended then return end
	self.state = STATES.Ended
	self.stop = cancel


	if self.connection then
		self.connection:Unregister(self,self.type) --Sai do heartbeat global
		self.connection = nil
	end
	
	self.weaponHitbox:RemoveOwner(self) --Limpa a hitbox

	self.ED:removeSkill(self.skillName, self)


	if cancel then
		if self.skillData.callbacks.onCancel then
			self.skillData.callbacks.onCancel(self)
			warn("[SkillRunner] Cancelando", self.skillName)
		end
	else
		if self.skillData.callbacks.onEnd then
			self.skillData.callbacks.onEnd(self)
		end
	end

	-- Sempre limpar o runner e notificar
	if self.onFinish then self.onFinish() end
	
end

return SkillRunner
