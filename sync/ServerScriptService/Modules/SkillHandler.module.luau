local SkillHandler = {}
local Server = game:GetService("ServerScriptService")
local Storage = game:GetService("ServerStorage")

local SkillRunner = require(Server.Modules.SkillRunner)
local DataManager = require(Server.EntityData.DataManager)
local SkillFactory = require(Server.Modules.SkillFactory)
local StateTable = require(Storage.Modules.Combat.StateTable)

function SkillHandler.HandleMovementInput(ID, dir)

	local entityCore = DataManager.Get(ID) 	--Salva o EntityCore do player que chamou a função
	local dirNormal = (dir and dir.Magnitude > 0) and dir.Unit or Vector3.zero --normaliza direção

	if dirNormal.Magnitude > 0 then
		entityCore.SetDirection(dirNormal) --se tiver uma nova direção, então dê update, caso contrário mantenha a antiga
		return true
	end
	return false
end

function SkillHandler.HandleSkillInput(ID,skillIndex)

	local entityCore = DataManager.Get(ID) 	--Salva o EntityCore da entidade que chamou a função

	local skillScript = entityCore.GetSkillScript(skillIndex) --Pega o script da skill
	if not skillScript then  warn("Skill não encontrada") 
	return false end


	local skill = SkillFactory.GetSkill(skillScript) -- Injeta o fallback da skill pra evitar erros de pointer nil caso a função não esteja declarada, além de preparar maxInstances padrão (1)



	local skillName = entityCore.GetSkillName(skillIndex) -- Pega o nome da skill pra checagem de multiplos requests

	local activeRunners = entityCore.GetActiveSkills(skillName) --Busca instâncias ativas da skill na entidade

	local max = skill.data.maxInstances--Guarda a quantidade máximas de instâncias permitida daquela skill

	local maxCooldown 

	if not entityCore.HasCooldown(skillName) then --Se não estiver em cooldown, então roda

		if not entityCore.CanContinue() then --Testa se a skill poderia cancelar a anterior (caso tenha uma ativa e o player tenha um estado)
			warn("Skill não pode rodar")
			return false
		end


		if not skill.data.ChainHistory then
	    	data = {
        	rootOrigin = entityCore,
        	rootSkill = skillName,
        	history = {skillName},
        	depth = 1,
			chainStart = tick()
			}
			ChainHistory = StateTable.BuildHistory(data)
		end
		maxCooldown = entityCore.GetCooldown(skillName) --Pega o cooldown restante da skill
		
		--Se já tiver uma instância ativa dessa skill
		if #activeRunners > 0 then

			--Se o número de instâncias for maior do que o máximo
			if #activeRunners >= max then 

				--Se o máximo for 1 (padrão de skill de recast apenas, sem spawns)
				if max == 1 then

					--Pego o primeiro runner da lista
					local runner = activeRunners[1]

						local canRecast = entityCore:TrySelfCancel() --tenta cancelar a skill atual
						if not canRecast then return false end
						runner:Recast() --Roda o recast
						entityCore.SetCooldown(skillName)
						return true,skillName end

				return false
			end
		end
			
		local cancel = entityCore.TrySelfCancel()
		
		if not cancel then --Cancela a skill anterior se ela for responsável por um state Self
			return false end -- Se obtiver retorno false (estado encontrado mas não é Self), sai do código
		

	entityCore.SetCooldown(skillName)
	
	
	
	local runner = SkillRunner.new(
		skill,
		entityCore,
		skillName,
		StateTable.Enum.Types.Skill,
		ChainHistory) --lança skill(após checagem de cooldown,validação pelo EntityData e preparação de fallback pelo SkillFactory)
	runner:start()
	end
	return true,skillName,maxCooldown
end

return SkillHandler