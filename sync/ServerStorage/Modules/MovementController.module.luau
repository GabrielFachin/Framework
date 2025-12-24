local RunService = game:GetService("RunService")
local Script = game:GetService("ServerScriptService")
local DataManager = Script.PlayerData.DataManager

local MovementController = {}
MovementController.__index = MovementController

-- Lista de todos os TPDs ativos 
local tracked = {}
-- Cache para BodyVelocity/BodyPosition objects
local bodyObjects = {}

function MovementController.Track(tpd)
	if not tracked[tpd] then
		tracked[tpd] = true
	end
end

function MovementController.Untrack(tpd)
	tracked[tpd] = nil
	-- Limpa body objects quando para de trackear
	if bodyObjects[tpd] then
		for _, obj in pairs(bodyObjects[tpd]) do
			if obj and obj.Parent then
				obj:Destroy()
			end
		end
		bodyObjects[tpd] = nil
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
local function removeFreezeObjects(tpd)
	if bodyObjects[tpd] then
		for _, obj in pairs(bodyObjects[tpd]) do
			if obj and obj.Parent then
				obj:Destroy()
			end
		end
		bodyObjects[tpd] = nil
	end
end

-- Heartbeat loop para aplicar restrições
RunService.Heartbeat:Connect(function()
	for tpd in pairs(tracked) do
		local status = tpd.CombatData and tpd.CombatData.Status
		if not status then continue end

		local tags = status:GetActiveTags()
		local canMove = tags.canMove ~= false
		local canControl = tags.canControl ~= false

		local root = tpd.Root
		if not root then continue end

		local humanoid = tpd.Humanoid
		if humanoid then
			humanoid.AutoRotate = canControl

			if canMove then
				-- Remove restrições de movimento
				removeFreezeObjects(tpd)

				-- Restaura velocidades normais
				humanoid.WalkSpeed = tpd.BaseWalkSpeed
				humanoid.JumpPower = tpd.BaseJumpPower
				humanoid.PlatformStand = false

			else
				-- Cria BodyVelocity se não existir
				if not bodyObjects[tpd] then
					bodyObjects[tpd] = createFreezeObjects(root)
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
					removeFreezeObjects(tpd)
				else
					if not bodyObjects[tpd] then
						bodyObjects[tpd] = createFreezeObjects(root)
					end
				end
			end
		end
	end
end)

-- Limpeza quando o player sai
game.Players.PlayerRemoving:Connect(function(player)
	for tpd in pairs(tracked) do
		if tpd.Player == player then
			MovementController.Untrack(tpd)
		end
	end
end)

return MovementController