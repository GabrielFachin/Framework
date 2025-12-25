-- ============================= SCRIPT USADO PRA ABSTRAÇÃO ENTRE CUSTOM MODELS E HUMANOIDS =====================================


local EntityWrapper = {}

-- ========== INTERFACES (Contratos) ========== --

--[[
    IMovement - Interface para movimento
]]
local IMovement = {}

function IMovement:SetSpeed(speed) end
function IMovement:GetSpeed() end
function IMovement:SetJumpPower(power) end
function IMovement:CanMove() end
function IMovement:Freeze() end
function IMovement:Unfreeze() end

--[[
    IHealth - Interface para vida
]]
local IHealth = {}

function IHealth:GetHP() end
function IHealth:GetMaxHP() end
function IHealth:SetHP(value) end
function IHealth:ApplyDamage(amount) end
function IHealth:Heal(amount) end
function IHealth:IsDead() end
function IHealth:Kill() end

--[[
    IAnimation - Interface para animações
]]
local IAnimation = {}

function IAnimation:Play(animId, key, fade, weight) end
function IAnimation:Stop(key, fade) end
function IAnimation:GetMarkerSignal(key, marker) end
function IAnimation:StopAll(fade) end

--[[
    IPhysics - Interface para física
]]
local IPhysics = {}

function IPhysics:GetRoot() end
function IPhysics:GetPosition() end
function IPhysics:SetPosition(pos) end
function IPhysics:GetVelocity() end
function IPhysics:SetVelocity(vel) end
function IPhysics:ApplyForce(force) end

-- ========== IMPLEMENTAÇÕES ========== --

--[[
    HumanoidMovement - Implementação para Humanoids
]]
local HumanoidMovement = {}
HumanoidMovement.__index = HumanoidMovement

function HumanoidMovement.new(humanoid, baseSpeed, baseJumpPower)
	local self = setmetatable({}, HumanoidMovement)

	self._humanoid = humanoid
	self._baseSpeed = baseSpeed or 16
	self._baseJumpPower = baseJumpPower or 50
	self._frozen = false

	return self
end

function HumanoidMovement:SetSpeed(speed)
	if not self._frozen then
		self._humanoid.WalkSpeed = speed
	end
end

function HumanoidMovement:GetSpeed()
	return self._humanoid.WalkSpeed
end

function HumanoidMovement:SetJumpPower(power)
	if not self._frozen then
		self._humanoid.JumpPower = power
	end
end

function HumanoidMovement:CanMove()
	return not self._frozen and self._humanoid.WalkSpeed > 0
end

function HumanoidMovement:Freeze()
	self._frozen = true
	self._humanoid.WalkSpeed = 0
	self._humanoid.JumpPower = 0
	self._humanoid.PlatformStand = true
end

function HumanoidMovement:Unfreeze()
	self._frozen = false
	self._humanoid.WalkSpeed = self._baseSpeed
	self._humanoid.JumpPower = self._baseJumpPower
	self._humanoid.PlatformStand = false
end

--[[
    CustomNPCMovement - Implementação para NPCs sem Humanoid
    Usa BodyVelocity/AlignPosition para movimento
]]
local CustomNPCMovement = {}
CustomNPCMovement.__index = CustomNPCMovement

function CustomNPCMovement.new(root, baseSpeed)
	local self = setmetatable({}, CustomNPCMovement)

	self._root = root
	self._baseSpeed = baseSpeed or 16
	self._currentSpeed = baseSpeed
	self._frozen = false

	-- ✅ Cria componentes de movimento uma vez
	self._attachment = Instance.new("Attachment")
	self._attachment.Name = "_NPCMovementAnchor"
	self._attachment.Parent = root

	self._alignPos = Instance.new("AlignPosition")
	self._alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
	self._alignPos.Attachment0 = self._attachment
	self._alignPos.MaxForce = 10000
	self._alignPos.MaxVelocity = math.huge
	self._alignPos.Responsiveness = 200
	self._alignPos.Enabled = false  -- Só ativa quando congelado
	self._alignPos.Parent = root

	return self
end

function CustomNPCMovement:SetSpeed(speed)
	self._currentSpeed = speed
end

function CustomNPCMovement:GetSpeed()
	return self._currentSpeed
end

function CustomNPCMovement:SetJumpPower(power)
	-- NPCs customizados não usam jump (podem ter sistema próprio de voo/dash)
end

function CustomNPCMovement:CanMove()
	return not self._frozen
end

function CustomNPCMovement:Freeze()
	self._frozen = true
	self._alignPos.Enabled = true
	self._alignPos.Position = self._root.Position

	-- Zera velocidade
	if self._root.AssemblyLinearVelocity.Magnitude > 0.1 then
		self._root.AssemblyLinearVelocity = Vector3.zero
	end
end

function CustomNPCMovement:Unfreeze()
	self._frozen = false
	self._alignPos.Enabled = false
end

function CustomNPCMovement:Destroy()
	self._attachment:Destroy()
	self._alignPos:Destroy()
end

--[[
    HumanoidHealth - Implementação para Humanoids (LEGACY SUPPORT)
]]
local HumanoidHealth = {}
HumanoidHealth.__index = HumanoidHealth

function HumanoidHealth.new(humanoid, maxHP)
	local self = setmetatable({}, HumanoidHealth)

	self._humanoid = humanoid
	self._maxHP = maxHP or humanoid.MaxHealth
	self._hp = self._maxHP

	return self
end

function HumanoidHealth:GetHP()
	return self._hp
end

function HumanoidHealth:GetMaxHP()
	return self._maxHP
end

function HumanoidHealth:SetHP(value)
	self._hp = math.clamp(value, 0, self._maxHP)

	-- ✅ Sincroniza com Humanoid (para backward compatibility)
	if self._humanoid then
		self._humanoid.Health = self._hp
	end
end

function HumanoidHealth:ApplyDamage(amount)
	self:SetHP(self._hp - amount)
end

function HumanoidHealth:Heal(amount)
	self:SetHP(self._hp + amount)
end

function HumanoidHealth:IsDead()
	return self._hp <= 0
end

function HumanoidHealth:Kill()
	self:SetHP(0)

	if self._humanoid then
		self._humanoid.Health = 0
	end
end

--[[
    CustomNPCHealth - Implementação para NPCs sem Humanoid
]]
local CustomNPCHealth = {}
CustomNPCHealth.__index = CustomNPCHealth

function CustomNPCHealth.new(maxHP)
	local self = setmetatable({}, CustomNPCHealth)

	self._maxHP = maxHP or 100
	self._hp = self._maxHP
	self._isDead = false

	return self
end

function CustomNPCHealth:GetHP()
	return self._hp
end

function CustomNPCHealth:GetMaxHP()
	return self._maxHP
end

function CustomNPCHealth:SetHP(value)
	self._hp = math.clamp(value, 0, self._maxHP)

	if self._hp <= 0 and not self._isDead then
		self._isDead = true
		-- ✅ Dispara evento de morte (via EventBus)
		local EventBus = require(game.ServerStorage.Modules.EventBus)
		EventBus.Global:Fire("EntityDied", {
			Entity = self,
			Timestamp = tick()
		})
	end
end

function CustomNPCHealth:ApplyDamage(amount)
	self:SetHP(self._hp - amount)
end

function CustomNPCHealth:Heal(amount)
	self:SetHP(self._hp + amount)
end

function CustomNPCHealth:IsDead()
	return self._isDead
end

function CustomNPCHealth:Kill()
	self:SetHP(0)
end

--[[
    HumanoidAnimation - Implementação padrão (já existe, apenas wrapper)
]]
local HumanoidAnimation = {}
HumanoidAnimation.__index = HumanoidAnimation

function HumanoidAnimation.new(animator)
	local self = setmetatable({}, HumanoidAnimation)

	local AnimationController = require(game.ServerStorage.Modules.Animation.AnimationController)
	self._controller = AnimationController.new(animator)

	return self
end

function HumanoidAnimation:Play(animId, key, fade, weight)
	return self._controller:Play(animId, key, fade, weight)
end

function HumanoidAnimation:Stop(key, fade)
	self._controller:Stop(key, fade)
end

function HumanoidAnimation:GetMarkerSignal(key, marker)
	return self._controller:GetAnimMark(key, marker)
end

function HumanoidAnimation:StopAll(fade)
	self._controller:StopAll(fade)
end

--[[
    CustomNPCAnimation - Para NPCs sem Animator
    Pode usar Tweens, CFrames, ou sistema customizado
]]
local CustomNPCAnimation = {}
CustomNPCAnimation.__index = CustomNPCAnimation

function CustomNPCAnimation.new(root)
	local self = setmetatable({}, CustomNPCAnimation)

	self._root = root
	self._activeTweens = {}

	return self
end

function CustomNPCAnimation:Play(animId, key, fade, weight)
	-- ✅ NPCs podem usar Tweens ao invés de animações Roblox
	-- Ou simplesmente não fazer nada (NPCs sem animação)
	warn("[CustomNPCAnimation] Play não implementado:", animId, key)
end

function CustomNPCAnimation:Stop(key, fade)
	-- Limpa tweens ativos
	if self._activeTweens[key] then
		self._activeTweens[key]:Cancel()
		self._activeTweens[key] = nil
	end
end

function CustomNPCAnimation:GetMarkerSignal(key, marker)
	-- NPCs customizados não têm markers (retorna dummy signal)
	local signal = Instance.new("BindableEvent")
	return signal.Event
end

function CustomNPCAnimation:StopAll(fade)
	for key, tween in pairs(self._activeTweens) do
		tween:Cancel()
	end
	table.clear(self._activeTweens)
end

--[[
    CustomNPCPhysics - Física para NPCs
]]
local CustomNPCPhysics = {}
CustomNPCPhysics.__index = CustomNPCPhysics

function CustomNPCPhysics.new(root)
	local self = setmetatable({}, CustomNPCPhysics)

	self._root = root

	return self
end

function CustomNPCPhysics:GetRoot()
	return self._root
end

function CustomNPCPhysics:GetPosition()
	return self._root.Position
end

function CustomNPCPhysics:SetPosition(pos)
	self._root.CFrame = CFrame.new(pos)
end

function CustomNPCPhysics:GetVelocity()
	return self._root.AssemblyLinearVelocity
end

function CustomNPCPhysics:SetVelocity(vel)
	self._root.AssemblyLinearVelocity = vel
end

function CustomNPCPhysics:ApplyForce(force)
	self._root:ApplyImpulse(force)
end

-- ========== FACTORY ========== --

EntityWrapper.CreateMovement = function(entity)
	if entity.Humanoid then
		local stats = entity.Character:FindFirstChild("_Stats")
		local baseSpeed = stats and stats:GetAttribute("Speed") or 16
		local baseJump = stats and stats:GetAttribute("JumpPower") or 50

		return HumanoidMovement.new(entity.Humanoid, baseSpeed, baseJump)
	else
		-- NPC customizado
		local baseSpeed = entity.Character:GetAttribute("Speed") or 16
		return CustomNPCMovement.new(entity.Root, baseSpeed)
	end
end

EntityWrapper.CreateHealth = function(entity, maxHP)
	if entity.Humanoid then
		return HumanoidHealth.new(entity.Humanoid, maxHP)
	else
		return CustomNPCHealth.new(maxHP)
	end
end

EntityWrapper.CreateAnimation = function(entity)
	if entity.Humanoid then
		local animator = entity.Humanoid:FindFirstChildOfClass("Animator")
		if animator then
			return HumanoidAnimation.new(animator)
		end
	end

	-- Fallback para NPCs sem animação
	return CustomNPCAnimation.new(entity.Root)
end

EntityWrapper.CreatePhysics = function(entity)
	return CustomNPCPhysics.new(entity.Root)
end

-- Exporta interfaces (para tipagem/documentação)
EntityWrapper.IMovement = IMovement
EntityWrapper.IHealth = IHealth
EntityWrapper.IAnimation = IAnimation
EntityWrapper.IPhysics = IPhysics

return EntityWrapper