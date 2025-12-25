local Character = {}
Character.__index = Character

function Character.new(entity)
	local self = setmetatable({}, Character)
	
	self.Entity = entity
	self.Character = nil
	self.Root = nil
	self.Humanoid = nil
	self._direction = Vector3.zero
	self.ChosenChar = "Schema"
	self.mode = "Base"
	self.charFolder = nil
	self._modeFolder = nil
	self.SkillsData = nil
	
	return self
end

-- Inicializa pastas de personagem
function Character:initializeFolders()
	local Storage = game:GetService("ServerStorage")
	local charFolder = Storage.Modules.CharData:FindFirstChild(self.ChosenChar)

	if charFolder then
		local modeFolder = charFolder:FindFirstChild(self.mode)
		self._modeFolder = modeFolder
		self.charFolder = charFolder

		if modeFolder then
			local skillsFolder = modeFolder:FindFirstChild("Skills")

			if skillsFolder then
				local skillsModule = skillsFolder:FindFirstChild("Skills")

				if skillsModule then
					local success, skillsData = pcall(require, skillsModule)

					if success then
						self.SkillsData = skillsData
					else
						warn("Erro ao carregar módulo de skills")
					end
				end
			end
		end
	end
end

-- Pega as stats do personagem
function Character:getCharStats()
	if not self.charFolder or not self.mode then
		warn("charFolder ou mode não definidos")
		return nil
	end
	
	local CharDataFolder = self.charFolder:FindFirstChild(self.mode)
	if not CharDataFolder then
		warn("mode folder não encontrado:", self.mode)
		return nil
	end
	
	local CharData = require(CharDataFolder.Data.Base)
	return CharData
end

-- Setta as inmodeações do Character da entidade
function Character:setPlayer(character)
	self.Character = character
	self.Root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart or character:FindFirstChildWhichIsA("BasePart")
	self.Humanoid = character:FindFirstChildWhichIsA("Humanoid")
end

-- Setta a direção da entidade
function Character:setDirection(dir)
	self._direction = dir
end

-- Retorna a direção da entidade
function Character:getDirection()
	return self._direction or Vector3.zero
end

return Character
