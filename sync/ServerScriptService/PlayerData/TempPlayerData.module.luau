local Storage = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")

local TempPlayerData = {}
TempPlayerData.__index = TempPlayerData
CombatData = require(game.ServerScriptService.PlayerData.CombatData)
MovementController = require(game.ServerStorage.Modules.MovementController)
local HealthModule = require(Storage.Modules.Combat.HealthController)


function TempPlayerData.new(player)
	local self = setmetatable({}, TempPlayerData)

	-- Dados fixos do player
	self.Player = player
	self.ChosenChar = "Schema"
	self.Character = nil
	self.form = "Base"
	self.Cooldowns = {}
	self.StatusCooldowns = {}
	self.ActiveSkills = {}
	self._direction = Vector3.zero
	
	--Controladores	
	self.CombatData = CombatData.new(player,self)


	MovementController.Track(self)
	
	-- Carrega e armazena referência ao módulo de skills para evitar requires repetidos, além inicializar a lista de cooldowns com 0 para cada skill
	local Storage = game:GetService("ServerStorage")

	--Esse código assustador abaixo só busca o caminho até o Skills, parece assustador mas o que importa é só o for no final
	local charFolder = Storage.Modules.CharData:FindFirstChild(self.ChosenChar)

	if charFolder then
		local formFolder = charFolder:FindFirstChild(self.form)
		self._formFolder = formFolder
		self.charFolder = charFolder

		if formFolder then
			local ScriptFolder = formFolder:FindFirstChild("Script")
			local skillsFolder = formFolder:FindFirstChild("Skills")

			if skillsFolder then
				local skillsModule = skillsFolder:FindFirstChild("Skills")

				if skillsModule then
					local success, skillsData = pcall(require, skillsModule)

					if success then
						self.SkillsData = skillsData

						for _, skillName in pairs(skillsData) do --Inicializa o cooldown para cada skill pelo índice
							self.Cooldowns[skillName] = 0
						end
					else
						warn("Erro ao carregar módulo de skills")
					end
				end
			end
		end
	end


		if self.CombatData then
			local stats = self:getCharStats()
			local HealthController = require(game.ServerStorage.Modules.Combat.HealthController)
		self.CombatData:SetHealthController(HealthController.new(stats.MaxHP or 100))
		end

	return self
end

--==============INFORMAÇÕES SKILLS================


--Pega o nome da skill, utilizado para obter os Script de lógica e dados
function TempPlayerData:getSkillName(index)
	if not self.SkillsData then
		warn("SkillsData não carregado")
		return nil
	end

	local skillName = self.SkillsData[index]
	if not skillName then
		warn("Skill não encontrada no índice", index)
		return nil
	end
	return skillName
end

--Pega Skill do Character escolhido pelo player usando o index da skill (o TempData fica armazenado no player, então ele já sabe o personagem, sem necessidade desse parametro)
function TempPlayerData:GetSkill(index)
	if not self.SkillsData then
		warn("SkillsData não carregado")
		return nil
	end

	--Pega o nome da skill pra devolver o script/nome do script
	local skillName = self:getSkillName(index)

	-- Busca o script da skill na pasta Script
	local skillScript = self._formFolder:FindFirstChild("Script") and self._formFolder.Script:FindFirstChild(skillName)

	if not skillScript then
		warn("Script da skill '" .. skillName .. "' não encontrado")
		return nil
	end

	return skillScript
end



--Adiciona a skill atual na lista de skills/runners atviso
function TempPlayerData:addSkill(name, runner)
	if not self.ActiveSkills[name] then
		self.ActiveSkills[name] = {}
	end
	table.insert(self.ActiveSkills[name], runner)
end



--Remove a skill recebi da lista de skills/runners ativos
function TempPlayerData:removeSkill(name, runner)
	local list = self.ActiveSkills[name]
	if not list then return end

	for i = #list, 1, -1 do
		if list[i] == runner then
			table.remove(list)
			break
		end
	end
end


--======================COOLDOWN====================

--Setta o cooldown da skill usando o index, pegando o tick atual e somando com o cooldown da skill (ou seja, o cooldown registrado é o momento futuro em que a skill vai voltar)



--Confere o cooldown no módulo da skill (agora localizado em Script/, acessando .data.cooldown)
function TempPlayerData:getSkillCooldown(skillName)

	local skillModuleInstance = self._formFolder:FindFirstChild("Script") and self._formFolder.Script:FindFirstChild(skillName)
	if not skillModuleInstance then
		warn("Módulo da skill '" .. skillName .. "' não encontrado na pasta Script")
		return nil
	end

	local success, skillModule = pcall(require, skillModuleInstance)
	if not success or not skillModule or not skillModule.data then
		warn("Erro ao requerer módulo da skill '" .. skillName .. "' ou .data ausente")
		return nil
	end

	local cd = skillModule.data.cooldown
	if not cd then
		warn("Cooldown não definido no .data da skill '" .. skillName .. "'")
		return nil
	end

	return cd
end


function TempPlayerData:hasCooldown(skillName)
	local currentTime = tick()
	return (self.Cooldowns[skillName] or 0) > currentTime
end

function TempPlayerData:setCooldown(skillName, customCooldown)
	local cd = customCooldown or self:getSkillCooldown(skillName)
	self.Cooldowns[skillName] = tick() + cd
end

--Mostra o cooldown "limpo" da skill, tirando o tick do cálculo e apenas mostrando o tempo restante
function TempPlayerData:getCooldown(skillName)
	return (self.Cooldowns[skillName] or 0) - tick()
end



function TempPlayerData:setStatusCooldown(name, duration)
	self.StatusCooldowns[name] = tick() + duration
end



function TempPlayerData:getStatusCooldown(name)
	local cooldownEnd = self.StatusCooldowns[name] or 0
	return math.max(0, cooldownEnd - tick())
end



function TempPlayerData:hasStatusCooldown(name)
	return self:getStatusCooldown(name) > 0
end


--=========================INFORMAÇÕES PERSONAGEM/PLAYER=====================

function TempPlayerData:getCharStats()
	local CharDataFolder = self.charFolder:FindFirstChild(self.form)
	local CharData = require(CharDataFolder.Data.Base)
	
	return CharData
end

--Setta as informações do Character do player, como root (deve ser atualizado toda vez que o player morrer)
function TempPlayerData:setPlayer(character)
	self.Character = character
	self.Root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart or character:FindFirstChildWhichIsA("BasePart")
	self.Humanoid = character:FindFirstChildWhichIsA("Humanoid")

	local stats = self:getCharStats()
	

	self.BaseWalkSpeed = stats.Speed or 16
	self.BaseJumpPower = stats.JumpPower or 50
	
	self.Weapon = stats.weapon

--Envia a string de nome da arma declarada no modulo 'data.base' (se tiver alguma)
if self.Weapon then
	local HitboxWrapper = require(Storage.Modules.Combat.HitboxWrapper)
	
	self:setWeapon(self.Weapon)
	
	--Cria o wrapper da hitbox da arma
	self.Hitbox = HitboxWrapper.new(self)
end

	if self.Humanoid then
		self.Humanoid.WalkSpeed = self.BaseWalkSpeed
		self.Humanoid.JumpPower = self.BaseJumpPower
		local control = self.CombatData:GetHealthController()
		control:SetHP(stats.MaxHP)
	end
	
	self.CombatData.Character = character
	self.CombatData.Humanoid = self.Humanoid
	self.CombatData.Root = self.Root
	

end



--Dá attach da arma ao player
function TempPlayerData:setWeapon(modelName)
	if self.weapon then return end
	
	local char = self.Character

	local weaponFolder = RS.Assets.Weapons:FindFirstChild(self.ChosenChar)
	local weaponModel = weaponFolder:FindFirstChild(modelName)
	if not weaponModel then return end
	
	local weaponClone = weaponModel:Clone()
	weaponClone.Name = weaponModel.Name
	weaponClone.Parent = char

	local handle = weaponClone:FindFirstChild("Handle")

	--Busca o membro de attach na arma, se não encontrar, procura a váriavel no modulo base do char, por último, caso não encontre, setta como o valor padrão (Right Arm)
	local attach = weaponModel.AttachTo.value or self:getCharStats().attachTo
	if not attach then local attach = "Right Arm" end

	local charAttach = char:FindFirstChild(attach)
	local CFrameValue = weaponClone:FindFirstChild("Value")

	-- Motor 6D
	local motor = Instance.new('Motor6D')
	motor.Part0 = charAttach
	motor.part1 = handle
	motor.C1 = CFrameValue.Value
	motor.Parent = handle
	
	self.hitOrigin = weaponClone:FindFirstChild("hitOrigin")
	self.weapon = weaponClone
	
	return weaponClone
end





--Recebem a ultima direção do player
function TempPlayerData:setDirection(dir)
	self._direction = dir
end

function TempPlayerData:getDirection()
	return self._direction or Vector3.zero
end

return TempPlayerData