local animation = script:WaitForChild('EvaIdle')
local humanoid = script.Parent:WaitForChild('Humanoid')
local idle = humanoid:LoadAnimation(animation)
idle:play()
idle.Looped = true