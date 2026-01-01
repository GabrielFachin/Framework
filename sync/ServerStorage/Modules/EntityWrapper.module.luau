-- ============================= SCRIPT USADO PRA ABSTRAÇÃO ENTRE CUSTOM MODELS E HUMANOIDS =====================================


local EntityWrapper = {}

-- ========== INTERFACES (Contratos) ========== --

--[[
    ICharacter - Interface de dados de char
]]
local ICharacter = {}

function ICharacter:GetRoot() 	  end
function ICharacter:SetRoot() 	  end
function ICharacter:SetHumanoid() end
function ICharacter:GetHumanoid() end

--[[
IMovement - Interface de dados de movimentação
]]

local IMovement = {}

function IMovement:GetSpeed()	 end
function IMovement:SetSpeed() 	 end
function IMovement:SetJumpForce()end
function IMovement:GetJumpForce()end


--====================CHARACTER==========================--


--====HUMANOIDS=======--
local HumanoidCharacter = {}
HumanoidCharacter.__index = HumanoidCharacter

function HumanoidCharacter.new(humanoid,root)
	local self = setmetatable({}, HumanoidCharacter)

	self._humanoid = humanoid
	self._root = root


	return self
end


function HumanoidCharacter:GetRoot()
	return self._root
end

function HumanoidCharacter:SetRoot(root)
	self._root = root
end

function HumanoidCharacter:SetHumanoid(humanoid)
	self._humanoid = humanoid
end

function HumanoidCharacter:GetHumanoid()
	return self._humanoid
end




--========NPCS========--
local NPChar = {}
NPChar.__index = NPChar

function NPChar.new(root)
	local self = setmetatable({}, NPChar)

	self._root = root

	return self
end

function NPChar:GetRoot()
	return self._root
end

function NPChar:SetRoot(root)
	self._root = root
end

function NPChar:SetHumanoid()
	--Função vazia apenas pra manter a padronização dos contatos, warn de boas práticas acompanha.
	warn("[EntityWrapper]Tentativa de settar Humanoid em entidade sem humanoid")
end

function NPChar:GetHumanoid()
	warn("[EntityWrapper]Tentativa de acessar Humanoid em entidade sem humanoid")
	return nil
end



--====================MOVIMENTAÇÃO=======================--

local HumanoidMovement = {}
HumanoidMovement.__index = HumanoidMovement

function HumanoidMovement.new(characterWrapper, speed, jump)
	local self = setmetatable({}, HumanoidMovement)

	self._character = characterWrapper

	self._speed = speed

	self._jump = jump

	local humanoid = self._character:GetHumanoid()
		if humanoid then 
			humanoid.WalkSpeed = self._speed
			humanoid.JumpPower = self._jump
		end

	return self
end


function HumanoidMovement:GetSpeed()
	return self._speed
end

function HumanoidMovement:SetSpeed(speed)
	self._speed = speed


	local humanoid = self._character:GetHumanoid()
		if humanoid then 
			humanoid.WalkSpeed = speed
		end
end

function HumanoidMovement:GetJumpForce()
	return self._jump
end

function HumanoidMovement:SetJumpForce(jumpForce)
	self._jump = jumpForce

	local humanoid = self._character:GetHumanoid()
		if humanoid then 
			humanoid.JumpPower = jumpForce
		end
end

local NPCMovement = {}
NPCMovement.__index = NPCMovement

function NPCMovement.new(characterWrapper, speed, jump)
	local self = setmetatable({}, NPCMovement)

	self._character = characterWrapper

	self._speed = speed

	self._jump = jump

	return self
end

function NPCMovement:GetSpeed()
	return self._speed
end

function NPCMovement:SetSpeed(speed)
	self._speed = speed

	local root = self._character:GetRoot()
		if root and root:FindFirstChild("speed") then
			root.speed.Value = speed
		else
			warn("[EntityWrapper Movement] Speed não encontrado em root ou root inexistente")
		end
end


function NPCMovement:GetJumpForce()
	return self._jump
end

function NPCMovement:SetJumpForce(jumpForce)
	self._jump = jumpForce

		local root = self._character:GetRoot()
		if root and root:FindFirstChild("jumpForce") then
			root.jumpForce.Value = jumpForce
		else
			warn("[EntityWrapper Movement] jumpForce não encontrado em root ou root inexistente")
		end			
end

-- ========== FACTORY ========== --


--[[
CreateCharacter, Função de criação de um novo wrapper de referências a partes essenciais da entidade
@params tabela de dados {humanoid,root} TABLE
@return tabela de funções.
]]
EntityWrapper.CreateCharacter = function(params)
	if params.humanoid then
		warn("WRAPPER DE CHARACTER HUMANOIDE INSTANCIADO")
		return HumanoidCharacter.new(params.humanoid,params.root)
	else
		-- NPC sem Humanoid
		warn("WRAPPER DE CHARACTER NPC INSTANCIADO")
		return NPChar.new(params.root)
	end
end




--[[
CreateMovement, Função de criação de um novo wrapper de movimentação
@params tabela de dados {humanoid, baseSpeed : Number, baseJump : number} TABLE
@return tabela de funções.
]]
EntityWrapper.CreateMovement = function(params)
	if params.characterWrapper:GetHumanoid() then 
		warn("WRAPPER DE MOVIMENTAÇÃO HUMANOIDE INSTANCIADO")
		return HumanoidMovement.new(params.characterWrapper,params.baseSpeed,params.baseJump)

	else
		warn("WRAPPER DE MOVIMENTAÇÃO NPC INSTANCIADO")
		return NPCMovement.new(params.characterWrapper,params.baseSpeed,params.baseJump)
	end
end

-- ========== EXPORTS ========== --
EntityWrapper.ICharacter = ICharacter
EntityWrapper.IMovement = IMovement

return EntityWrapper