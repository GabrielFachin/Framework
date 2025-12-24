local animation = script:WaitForChild('SchemaIdle')
local humanoid = script.Parent:WaitForChild('Humanoid')
local idle = humanoid:LoadAnimation(animation)
idle:play()
idle.Looped = true