local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Inputs = require(ReplicatedStorage.Config.InputConfig)
local MoveDirHandler = require(ReplicatedStorage.Modules.MoveInputHandler)
local Utils = require(ReplicatedStorage.Utils)

local ActionMap = Inputs.InputMap
local InputToSkill = Inputs.InputToSkill

local RemoteEventSkill = ReplicatedStorage.RemoteEvents.RequestSkill
local RemoteEventDir = ReplicatedStorage.RemoteEvents.RequestDir

--Prepara os dados de envio do vetor, enviando em pequenos intervalos pra evitar queda de perfomance do usuário
local lastSentDir = Vector3.zero
local sendCooldown = 0.05
local SinceLastSend = 0

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	--Roda pelo actionMap, pegando a chave e o valor
	for inputSlot, boundInput in pairs(ActionMap) do
		local isMatch = input.KeyCode == boundInput or input.UserInputType == boundInput --Confere se o input do usuário tem um equivalente no ActionMap
		if isMatch then
			local skillIndex = InputToSkill[inputSlot] --Então o index da Skill é equivalente ao index do ActionMap
			if skillIndex then
				RemoteEventSkill:FireServer(skillIndex) --Joga o index da skill pro servidor
			end
		end
	end
end)


--Envia os dados de movimento relativos a camera
RunService.Heartbeat:Connect(function(dt)
	SinceLastSend += dt
	local moveVector = MoveDirHandler.GetCurrentDirection()
	local camera = workspace.CurrentCamera
	local vectorRelative = Utils.GetCameraRelativeDirection(moveVector, camera.CFrame)
	if (vectorRelative - lastSentDir).Magnitude > 0.01 and SinceLastSend >= sendCooldown then
		RemoteEventDir:FireServer(vectorRelative)
		lastSentDir = vectorRelative
		SinceLastSend = 0
	end
end)


