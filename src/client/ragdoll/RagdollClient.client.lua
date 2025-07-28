local camera = workspace.CurrentCamera
local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local head : Part = char:WaitForChild("Head")
local hum : Humanoid = char:WaitForChild("Humanoid")

local noCamShake = true -- R6 specifik!!
local antiMove = false -- enable this if ragdoll is weird

-- put me in StarterPlayer.StarterCharacterScripts

local remote = game.ReplicatedStorage.Remotes.Ragdoll

local function focus(arg)
	if arg == "Focus" then
		if noCamShake then
			camera.CameraSubject = head
			hum.RootPart.CanCollide = false
		end
	elseif arg == "Unfocus" then
		if noCamShake then
			camera.CameraSubject = hum
			hum.RootPart.CanCollide = true
		end	
	end
end
local function noMove(arg)
	if arg == "Stop" then
		if antiMove then
			hum.WalkSpeed = 0
			hum.PlatformStand = true
		end
	elseif arg == "Aan" then
		if antiMove then
			hum.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed
			hum.JumpHeight = game.StarterPlayer.CharacterJumpHeight
			hum.JumpPower = game.StarterPlayer.CharacterJumpPower
			hum.PlatformStand = false
		end
	end
end

remote.OnClientEvent:Connect(function(arg, sec)
	if hum then
		if arg == "Make" then
			hum:ChangeState(Enum.HumanoidStateType.Physics) -- in ragdoll
			focus("Focus")
			noMove("Stop")
		elseif arg == "Destroy" then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp) -- out of ragdoll
			focus("Unfocus")
			noMove("Aan")
		end
		if arg == nil then
			if sec == "manualM" then
				hum:ChangeState(Enum.HumanoidStateType.Physics)
				focus("Focus")
				noMove("Stop")
			end
		end
		if arg == nil then
			if sec == "manualD" then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				focus("Unfocus")
				noMove("Aan")
			end
		end
	end
end)

if script.Parent == game.Workspace then
	error("Dude wont run dumbass, and this print neither XD")
end