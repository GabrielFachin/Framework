local RunService = game:GetService("RunService")
local Script = game:GetService("ServerScriptService")
local DataManager = Script.EntityData.DataManager

local MovementController = {}
MovementController.__index = MovementController

-- Lista de todos os EDs ativos 
local tracked = {}
-- Cache para BodyVelocity/BodyPosition objects
local bodyObjects = {}

function MovementController.Track(ED)
	if not tracked[ED] then
		tracked[ED] = true
	end
end

function MovementController.Untrack(ED)
	tracked[ED] = nil
	-- Limpa body objects quando para de trackear
	if bodyObjects[ED] then
		for _, obj in pairs(bodyObjects[ED]) do
			if obj and obj.Parent then
				obj:Destroy()
			end
		end
		bodyObjects[ED] = nil
	end
end

-- Função para criar BodyVelocity para congelar movimento
local function createFreezeObjects(root)
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	bodyVelocity.Parent = root

	local bodyAngular = Instance.new("BodyAngularVelocity")
	bodyAngular.MaxTorque = Vector3.new(4000, 4000, 4000)
	bodyAngular.AngularVelocity = Vector3.new(0, 0, 0)
	bodyAngular.Parent = root

	return {bodyVelocity, bodyAngular}
end

-- Função para remover objetos de congelamento
local function removeFreezeObjects(ED)
	if bodyObjects[ED] then
		for _, obj in pairs(bodyObjects[ED]) do
			if obj and obj.Parent then
				obj:Destroy()
			end
		end
		bodyObjects[ED] = nil
	end
end

-- Heartbeat loop para aplicar restrições
RunService.Heartbeat:Connect(function()
	for ED in pairs(tracked) do
		local status = ED.CombatData and ED.CombatData.Status
		if not status then continue end

		local tags = status:GetActiveTags()
		local canMove = tags.canMove ~= false
		local canControl = tags.canControl ~= false

		local root = ED.Root
		if not root then continue end

		local humanoid = ED.Humanoid
		if humanoid then
			humanoid.AutoRotate = canControl

			if canMove then
				-- Remove restrições de movimento
				removeFreezeObjects(ED)

				-- Restaura velocidades normais
				humanoid.WalkSpeed = ED.BaseWalkSpeed
				humanoid.JumpPower = ED.BaseJumpPower
				humanoid.PlatformStand = false

			else
				-- Cria BodyVelocity se não existir
				if not bodyObjects[ED] then
					bodyObjects[ED] = createFreezeObjects(root)
				end

				-- Zera velocidades do Humanoid
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
				humanoid.PlatformStand = true
			end
		else
			-- NPC customizado (não-humanoide)
			if root:IsA("BasePart") then
				if canMove then
					removeFreezeObjects(ED)
				else
					if not bodyObjects[ED] then
						bodyObjects[ED] = createFreezeObjects(root)
					end
				end
			end
		end
	end
end)

-- Limpeza quando o player sai
game.Players.PlayerRemoving:Connect(function(player)
	for ED in pairs(tracked) do
		if ED.Entity == player then
			MovementController.Untrack(ED)
		end
	end
end)

return MovementController