local Handler = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Storage = game:GetService("ServerStorage")
local Server = game:GetService("ServerScriptService")


local SkillRunner = require(Server.Modules.SkillRunner)
local DataManager = require(Server.PlayerData.DataManager)
local SkillFactory = require(Server.Modules.SkillFactory)


local RemoteEventSkill = ReplicatedStorage.RemoteEvents.RequestSkill
local RemoteEventDir = ReplicatedStorage.RemoteEvents.RequestDir


function Handler:HandleStatus(statusData, targetTPD, duration, sourceSkillRunner,ID)

	if not targetTPD or not targetTPD.CombatData then
		warn("targetTPD inválido:", targetTPD)
		return
	end

	local originTPD = sourceSkillRunner and sourceSkillRunner.tpd --Permite originTPD ser nil
	if not originTPD then
		warn("TPD DE ORIGEM NÃO DEFINIDO! PODE SER IGNORADO CASO PROPOSITAL OU DEBUG")
		warn("Cooldown de status pode não funcionar devido a falta de um source pra aplicar/buscar o cooldown!")
	end

	local status = SkillFactory.GetStatus(statusData)
	if not status or not status.data.name then
		warn("Status inválido")
		return
	end


	-- Aplica cooldown se necessário
	local cd = targetTPD.CombatData
	if status.data.cooldown and status.data.cooldown > 0 and originTPD then
		if originTPD:HasStatusCooldown(status.data.name) then
			return 
		end
		originTPD:SetCooldown(status.data.name, status.data.cooldown)
	end
	
	
	return status --Devolve os dados tratados pra permitir o StatusController a fazer a aplicação e filtros

end

return Handler