 local HitboxWrapper = {}
HitboxWrapper.__index = HitboxWrapper

local ShapecastModule = require(script.Parent.ShapecastHitbox)
local DataManager = require(game.ServerScriptService.PlayerData.DataManager)

-- Pool global
local hitboxPool = {}
local POOL_MAX_SIZE = 50 -- Limite



--TIPAGEM
type HitboxConfig = {
	name: string,
	part: Part,
	flags: {string},
}

type HitResult = {
	target: any,
	hitboxName: string,
	position: Vector3,
	normal: Vector3,
	distance: number,
	instance: Instance,
	segment: any,
	flags: {string},
}

--Inicializa a hitbox, podendo receber um excludeSelf como parâmetro, o padrão é True caso não declarado
function HitboxWrapper.new(tpd,excludeSelf : BoolValue?)
	
	
	--Se não receber nada informando se a hitbox deveria ou não excluir o usuário, então a hitbox vai ignorar o usuário por padrão
	if excludeSelf == nil then
		excludeSelf = true
	end
	
	local self = setmetatable({}, HitboxWrapper)
	self.tpd = tpd
	
	if tpd.weapon then
	self.weapon = tpd.weapon end
	self.activeHitboxes = {}
	self.hitboxConfigs = {}
	self.isActive = false
	self.hitTargets = {}
	
	self.owners = {} --Será setado pelo SkillRunner, informando quem está rodando a skill

	-- RaycastParams, inicia a configuração de exclusão
	self.raycastParams = RaycastParams.new()
	self.raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.raycastParams.FilterDescendantsInstances = {tpd.Character, self.weapon}

	-- Descobre hitboxes
	self:_discoverHitboxes()

	return self
end


--Mostra as hitboxes encontradas na arma, assim como as flags, e as guarda nas configurações da hitbox
function HitboxWrapper:_discoverHitboxes()
	local hitboxFolder = self.weapon:FindFirstChild("Hitbox")
	if not hitboxFolder then
		warn("[HitboxWrapper] Pasta de hitboxes não encontrada para: ", self.weapon.Name)
		return
	end

	--Loopa por todas as hitboxes no modelo (dentro da pasta hitboxes)
	for _, hitboxModel in ipairs(hitboxFolder:GetChildren()) do
		if hitboxModel:IsA("Part")then
			local flags = {}

			
			--Busca por flags (tags) especiais dentro da hitbox
			if hitboxModel:GetAttribute("Flags") then
				flags = string.split(hitboxModel:GetAttribute("Flags"), ",")
			end

			self.hitboxConfigs[hitboxModel.Name] = {
				name = hitboxModel.Name,
				part = hitboxModel,
				flags = flags,
			}
		end
	end
end


--Informa a skill que está rodando pra facilitar aceso a função "onHit" sem código extra na skill
function HitboxWrapper:AddOwner(owner)
	if not self.owners then self.owners = {} end
	if owner == nil then return self end
	self.owners[owner] = owner

	-- cria callback que chama todos os owners (executa todos os onHit pra todos as skills linkadas a hitbox atual)
	self.callback = function(hitResult)
		for _, o in pairs(self.owners) do
			if type(o.onHit) == "function" then
				local ok, err = pcall(function() o:onHit(hitResult) end)
				if not ok then warn("[HitboxWrapper] owner:onHit erro:", err) end
			end
		end
	end

	return self
end


--Remove um dono da hitbox, caso ninguém esteja mais, limpa a callback
function HitboxWrapper:RemoveOwner(owner)
    if not self.owners then return self end
    self.owners[owner] = nil

    -- se ficou vazio, remove callback
    local empty = true
    for _ in pairs(self.owners) do empty = false; break end
    if empty then
        self.callback = nil
    end

    return self
end


--Inicia a hitbox (caso ainda não ativa)
function HitboxWrapper:Start(duration)
	
	if self.isActive then return false end
	if next(self.hitboxConfigs) == nil then
		warn("[HitboxWrapper] Nenhuma hitbox configurada")
		return false
	end

	self.isActive = true
	table.clear(self.hitTargets)

	--Pra cada dado na tabela de configuração das hitboxes (flags, nome e parte)
	for name, config in pairs(self.hitboxConfigs) do
		
		--Cria (ou reutiliza) uma hitbox
		local hitbox = self:_createOrReuseHitbox(config.part)

		--Se encontrar alguma parte já alocada então prepara o onHit da hitbox dela, informando callbacks e afins
		if hitbox then
			hitbox:OnHit(function(result, segment)
				self:_handleHit(result, segment, config, self.callback)
			end)

			hitbox:HitStart(duration)

			hitbox:OnStopped(function(clearCallbacks)
				clearCallbacks()
				self:_returnHitbox(name, hitbox)
			end)

			self.activeHitboxes[name] = hitbox
		end
	end

	return true
end

--Criação e/ou reutilização de novas hitboxes já preparadas na pool
function HitboxWrapper:_createOrReuseHitbox(part: Part)
	
	--Chave de acesso da pool (dict)
	local poolKey = part:GetFullName()

	--Se a pool já tiver uma hitbox para aquela parte, então a reutiliza
	if hitboxPool[poolKey] and #hitboxPool[poolKey] > 0 then
		local hitbox = table.remove(hitboxPool[poolKey])
		hitbox.Instance = part
		hitbox.RaycastParams = self.raycastParams
		hitbox:Reconcile() --E atualiza a posição da mesma
		return hitbox
	end

	--Se não existente, cria uma nova hitbox
	local success, hitbox = pcall(function()
		return ShapecastModule.new(part, self.raycastParams)
	end)

	return success and hitbox or nil
end

--Insere a hitbox na pool global
function HitboxWrapper:_returnHitbox(name: string, hitbox)
	if not hitbox then return end

	local poolKey = hitbox.Instance:GetFullName()

	if not hitboxPool[poolKey] then
		hitboxPool[poolKey] = {}
	end

	-- Limite de pool
	if #hitboxPool[poolKey] < POOL_MAX_SIZE then
		hitbox:HitStop()
		table.insert(hitboxPool[poolKey], hitbox)
	else
		hitbox:Destroy()
	end

	self.activeHitboxes[name] = nil
end


--Callback do onHit
function HitboxWrapper:_handleHit(result: RaycastResult, segment, config: HitboxConfig, callback)
	if not result then return end


	--Busca o TPD do alvo atingido
	local targetTPD = self:_getTargetTPD(result.Instance)
	if not targetTPD then return end

	-- Anti multi-hit
	--Vale notar que, caso a skill seja feita pra ter multi hit é necessário desligar a hitbox a cada hit e reativar depois do cooldown/ticks entre hits!
	local targetId = targetTPD.Player.UserId
	if self.hitTargets[targetId] then return end
	self.hitTargets[targetId] = true

	local hitResult: HitResult = {
		target = targetTPD,
		hitboxName = config.name,
		position = result.Position,
		normal = result.Normal,
		distance = result.Distance,
		instance = result.Instance,
		segment = segment,
		flags = config.flags,
	}

	--Se tiver um callback, executa (provavelmente onHit da skill)
	if self.callback then
		local success, err = pcall(self.callback, hitResult)
		if not success then
			warn("[HitboxWrapper] Erro no callback:", err)
		end
	end
end

--Busca o TPD do alvo atingido
function HitboxWrapper:_getTargetTPD(hitInstance: Instance)
	local current = hitInstance

	--Se atingir uma parte, busca o humanoid e o player (precisa ser alterado futuramente pra suportar NPCs)
	while current and current ~= workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local player = game.Players:GetPlayerFromCharacter(current)
				if player then
					return DataManager.Get(player)
				end
				return nil
			end
		end
		current = current.Parent
	end

	return nil
end

--Desativa a hitbox
function HitboxWrapper:Stop()
	if not self.isActive then return end

	for name, hitbox in pairs(self.activeHitboxes) do
		hitbox:HitStop()
		self:_returnHitbox(name, hitbox)
	end

	table.clear(self.activeHitboxes)
	table.clear(self.hitTargets)
	self.isActive = false
end


--Destrói a hitbox
function HitboxWrapper:Destroy()
	self:Stop()
	self.tpd = nil
	self.weapon = nil
	self.raycastParams = nil
	table.clear(self.hitboxConfigs)
end
-- Limpa pool global
function HitboxWrapper.ClearPool()
	local totalDestroyed = 0
	for poolKey, pool in pairs(hitboxPool) do
		for _, hitbox in ipairs(pool) do
			hitbox:Destroy()
			totalDestroyed += 1
		end
	end

	table.clear(hitboxPool)
	print("[HitboxWrapper] Pool limpo. Destruídas:", totalDestroyed)
end
-- Debug
function HitboxWrapper.GetPoolStats()
	local stats = {
		totalPools = 0,
		totalHitboxes = 0,
		byType = {}
	}
	for poolKey, pool in pairs(hitboxPool) do
		stats.totalPools += 1
		stats.totalHitboxes += #pool
		stats.byType[poolKey] = #pool
	end

	return stats
end
return HitboxWrapper