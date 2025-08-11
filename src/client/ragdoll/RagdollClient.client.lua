local camera = workspace.CurrentCamera
local plr = game.Players.LocalPlayer

-- Current character refs (kept up to date across respawns)
local char: Model? = nil
local head: Part? = nil
local hum: Humanoid? = nil

local function bindCharacter(c: Model)
    char = c
    head = c:WaitForChild("Head")
    hum = c:WaitForChild("Humanoid")
end

if plr.Character then
    bindCharacter(plr.Character)
end
plr.CharacterAdded:Connect(bindCharacter)

local noCamShake = true -- R6 specifik!!
local antiMove = false -- enable this if ragdoll is weird

-- put me in StarterPlayer.StarterCharacterScripts

local remote = game.ReplicatedStorage.Remotes.Ragdoll

local function focus(arg)
	if arg == "Focus" then
        if noCamShake and head and hum and hum.RootPart then
            camera.CameraSubject = head
            hum.RootPart.CanCollide = false
        end
	elseif arg == "Unfocus" then
        if noCamShake and hum and hum.RootPart then
            camera.CameraSubject = hum
            hum.RootPart.CanCollide = true
        end 
	end
end
local function noMove(arg)
	if arg == "Stop" then
        if antiMove and hum then
            hum.WalkSpeed = 0
            hum.PlatformStand = true
        end
	elseif arg == "Aan" then
        if antiMove and hum then
            hum.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed
            hum.JumpHeight = game.StarterPlayer.CharacterJumpHeight
            hum.JumpPower = game.StarterPlayer.CharacterJumpPower
            hum.PlatformStand = false
        end
	end
end

remote.OnClientEvent:Connect(function(arg, sec)
    -- Refresh references on each event in case of recent respawn
    if (not hum) or (hum and hum.Parent == nil) then
        if plr.Character then
            bindCharacter(plr.Character)
        end
    end

    if not hum then return end

    local ok, err = pcall(function()
        if arg == "Make" then
            hum:ChangeState(Enum.HumanoidStateType.Physics) -- in ragdoll
            focus("Focus")
            noMove("Stop")
        elseif arg == "Destroy" then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp) -- out of ragdoll
            focus("Unfocus")
            noMove("Aan")
        elseif arg == nil and sec == "manualM" then
            hum:ChangeState(Enum.HumanoidStateType.Physics)
            focus("Focus")
            noMove("Stop")
        elseif arg == nil and sec == "manualD" then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            focus("Unfocus")
            noMove("Aan")
        end
    end)
    if not ok then
        warn("[RagdollClient] Error handling ragdoll event:", err)
    end
end)

if script.Parent == game.Workspace then
	error("Dude wont run dumbass, and this print neither XD")
end