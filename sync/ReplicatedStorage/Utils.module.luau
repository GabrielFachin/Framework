local Utils = {}

function Utils.getRoot(character)
	return character:FindFirstChild("HumanoidRootPart")
end

function Utils.GetCameraRelativeDirection(moveVector, cameraCFrame)
	local camLook = cameraCFrame.LookVector
	camLook = Vector3.new(camLook.X, 0, camLook.Z).Unit

	local camRight = cameraCFrame.RightVector
	camRight = Vector3.new(camRight.X, 0, camRight.Z).Unit

	local direction = (camLook * moveVector.Z) + (camRight * moveVector.X)

	if direction.Magnitude > 0 then
		return direction.Unit
	else
		return Vector3.zero
	end
end

return Utils