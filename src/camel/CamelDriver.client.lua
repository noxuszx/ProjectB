-- CamelDriver  (LocalScript)

local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player     = game.Players.LocalPlayer

-- wait until we’re actually mounted
repeat task.wait() until player.Character and player.Character.Humanoid.SeatPart
local seat     = player.Character.Humanoid.SeatPart
local camel    = seat.Parent
local humanoid = camel:WaitForChild("Humanoid")

-- Camel movement tuning
local WALK_SPEED_NORMAL  = 16
local WALK_SPEED_SPRINT  = 30
humanoid.WalkSpeed       = WALK_SPEED_NORMAL
humanoid.JumpPower       = 30
humanoid.MaxSlopeAngle   = 50
humanoid.HipHeight       = 4

-- key state table
local keysDown = {
	W = false, A = false, S = false, D = false
}

local function computeMoveVector()
	local x = (keysDown.D and 1  or 0) + (keysDown.A and -1 or 0)
	local z = (keysDown.S and 1  or 0) + (keysDown.W and -1 or 0)
	local v = Vector3.new(x, 0, z)
	return v.Magnitude > 0 and v.Unit or Vector3.zero
end

-- Input callbacks
local inputConnections = {}
inputConnections[1] = UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	local kc = input.KeyCode

	if kc == Enum.KeyCode.W then keysDown.W = true end
	if kc == Enum.KeyCode.A then keysDown.A = true end
	if kc == Enum.KeyCode.S then keysDown.S = true end
	if kc == Enum.KeyCode.D then keysDown.D = true end

	if kc == Enum.KeyCode.Space     then humanoid.Jump = true end
	if kc == Enum.KeyCode.LeftShift then humanoid.WalkSpeed = WALK_SPEED_SPRINT end
end)

inputConnections[2] = UIS.InputEnded:Connect(function(input, gp)
	if gp then return end
	local kc = input.KeyCode

	if kc == Enum.KeyCode.W then keysDown.W = false end
	if kc == Enum.KeyCode.A then keysDown.A = false end
	if kc == Enum.KeyCode.S then keysDown.S = false end
	if kc == Enum.KeyCode.D then keysDown.D = false end

	if kc == Enum.KeyCode.LeftShift then humanoid.WalkSpeed = WALK_SPEED_NORMAL end
end)

-- Main update loop (RenderStepped = lowest input latency for local player)
local connection
connection = RunService.RenderStepped:Connect(function()
	-- still seated?
	if not player.Character or not player.Character:FindFirstChild("Humanoid")
		or not player.Character.Humanoid.SeatPart then
		humanoid:Move(Vector3.zero, true)   -- STOP camel before disconnecting
		connection:Disconnect()
		-- explicitly disconnect input connections for immediate cleanup
		for _, conn in ipairs(inputConnections) do
			if conn.Connected then
				conn:Disconnect()
			end
		end
		script:Destroy()
		return
	end

	-- Apply movement every frame (Vector3.zero clears WalkDirection)
	humanoid:Move(computeMoveVector(), true)
end)