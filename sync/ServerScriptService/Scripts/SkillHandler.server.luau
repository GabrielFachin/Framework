local Handler = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")


local SkillRunner = require(Server.Modules.SkillRunner)
local DataManager = require(Server.EntityData.DataManager)
local SkillFactory = require(Server.Modules.SkillFactory)


local RemoteEventSkill = ReplicatedStorage.RemoteEvents.RequestSkill
local RemoteEventDir = ReplicatedStorage.RemoteEvents.RequestDir
local RemoteEventSkillFired = ReplicatedStorage.RemoteEvents.SkillFired

RemoteEventDir.OnServerEvent:Connect(function(player,dir)
	local ID = player.Character:GetAttribute("EntityID")


	local entityCore = DataManager.Get(ID) 	--Salva o EntityCore do player que chamou a função
	local dirNormal = (dir and dir.Magnitude > 0) and dir.Unit or Vector3.zero --Aqui sim nós tratamos contra manipulação de dados, falando que queremos apenas o valor normalizado do vetor recebido, caso seja nil, então não atualize


	if dirNormal.Magnitude > 0 then
		entityCore.SetDirection(dirNormal) --se tiver uma nova direção, então dê update, caso contrário mantenha a antiga
	end

end)

RemoteEventSkill.OnServerEvent:Connect(function(player, skillIndex)
	local ID = player.Character:GetAttribute("EntityID")

	local entityCore = DataManager.Get(ID) 	--Salva o EntityCore do player que chamou a função

	--Futuramente precisamos fazer um debounce aqui, checando o delay entre o ultimo envio do cliente e o atual, evitando spam e cheats (ambos pro input de movimento e skills)

	local skillScript = entityCore:GetSkillScript(skillIndex) --Pega o script da skill
	if not skillScript then  warn("Skill não encontrada") 
	return false end


	local skill = SkillFactory.GetSkill(skillScript) -- Injeta o fallback da skill pra evitar erros de pointer nil caso a função não esteja declarada, além de preparar maxInstances padrão (1)



	local skillName = entityCore.GetSkillName(skillIndex) -- Pega o nome da skill pra checagem de multiplos requests

	local activeRunners = entityCore.GetActiveSkills --Busca instâncias ativas da skill no ED

	local max = skill.maxInstances--Guarda a quantidade máximas de instâncias permitida daquela skill

	if not entityCore.HasCooldown(skillName) then --Se não estiver em cooldown, então roda

		
		if not entityCore.CanContinue() then --Testa se a skill poderia cancelar a anterior (caso tenha uma ativa e o player tenha um estado)
			warn("Skill não pode rodar")
			return
		end
		
		
		
		--Se já tiver uma instância ativa dessa skill
		if #activeRunners > 0 then

			--Se o número de instâncias for maior do que o máximo
			if #activeRunners >= max then 

				--Se o máximo for 1 (padrão de skill de recast apenas, sem spawns)
				if max == 1 then

					--Pego o primeiro runner da lista
					local runner = activeRunners[1]

					--Pede pro runner se ele encontrou um recast, e então retorna com uma flag
					local handled = runner:Recast(true)
					if handled then --Se um recast for encontrado, então:
						entityCore.CombatData:TrySelfCancel() --tenta cancelar a skill atual
						runner:Recast() --Roda o recast
						return end
				end
				return
			end
		end
			
		local cancel = entityCore.TrySelfCancel()
		
		if not cancel then --Cancela a skill anterior se ela for responsável por um state Self
			return false end -- Se obtiver retorno false (estado encontrado mas não é Self), sai do código
		end
		

		entityCore.SetCooldown(skillName)
		
		

		local maxCooldown = entityCore.getCooldown(skillName) --Pega o cooldown restante da skill
		
		RemoteEventSkillFired:FireClient(player,skillName,maxCooldown)

		local runner = SkillRunner.new(skill,entityCore,skillName,"skill") --lança skill(após checagem de cooldown,validação pelo EntityData e preparação de fallback pelo SkillFactory)
		runner:start()

	end)




return Handler