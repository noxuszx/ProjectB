-- CamelDriver  (LocalScript)

local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player     = game.Players.LocalPlayer

-- Toggle for verbose client logging
local DEBUG = false

-- Shared utility for consistent mobile buttons
local CAU = require(game.ReplicatedStorage.Shared.modules.ContextActionUtility)

-- Attempt to use the universal PlayerModule controls so mobile/gamepad/keyboard all work
local controls = nil
local function tryAcquireControls()
	local ok, result = pcall(function()
		local ps = player:FindFirstChild("PlayerScripts") or player:WaitForChild("PlayerScripts", 10)
		if not ps then return nil end
		local pm = ps:FindFirstChild("PlayerModule") or ps:WaitForChild("PlayerModule", 10)
		if not pm then return nil end
		local PlayerModule = require(pm)
		return PlayerModule:GetControls()
	end)
	if ok and result then
		controls = result
		if DEBUG then warn("[CamelDriver] Acquired PlayerModule controls") end
		return true
	end
	return false
end

-- Keep retrying to acquire controls for a short window
if not tryAcquireControls() then
	task.spawn(function()
		for i = 1, 60 do -- ~6 seconds total (0.1s step)
			if controls then break end
			if tryAcquireControls() then break end
			task.wait(0.1)
		end
		if not controls and DEBUG then
			warn("[CamelDriver] PlayerModule controls not available; falling back to keyboard-only input")
		end
	end)
end

-- wait until we’re actually mounted
repeat task.wait() until player.Character and player.Character.Humanoid.SeatPart
local seat     = player.Character.Humanoid.SeatPart
local camel    = seat.Parent
local humanoid = camel:WaitForChild("Humanoid")
if DEBUG then warn("[CamelDriver] Mounted camel:", camel:GetFullName()) end

-- Camel movement tuning
local WALK_SPEED_NORMAL  = 16
local WALK_SPEED_SPRINT  = 30
humanoid.WalkSpeed       = WALK_SPEED_NORMAL
humanoid.JumpPower       = 30
humanoid.MaxSlopeAngle   = 50
humanoid.HipHeight       = 4

-- key state table (fallback for desktop if PlayerModule not available)
local keysDown = {
	W = false, A = false, S = false, D = false
}

local function computeMoveVector()
	-- Prefer the move vector from Roblox’s control module (works for touch/joystick)
	if controls then
		local mv = controls:GetMoveVector()
		return mv -- may be zero-length
	end
	-- Fallback to manual WASD keys
	local x = (keysDown.D and 1  or 0) + (keysDown.A and -1 or 0)
	local z = (keysDown.S and 1  or 0) + (keysDown.W and -1 or 0)
	local v = Vector3.new(x, 0, z)
	return v.Magnitude > 0 and v.Unit or Vector3.zero
end

-- Jump binding: works on Space (keyboard), ButtonA (gamepad), and adds a touch button on mobile via ContextActionUtility
local function onCamelJump(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		humanoid.Jump = true
		if DEBUG then warn("[CamelDriver] Jump triggered via", actionName, inputObject and inputObject.KeyCode) end
	end
end
CAU:BindAction("CamelJump", onCamelJump, true, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
CAU:SetTitle("CamelJump", "Camel")
-- Move our button further away from the default jump to avoid overlapping hitboxes
local camelBtn = CAU:GetButton("CamelJump")
if camelBtn then
	camelBtn.Position = UDim2.new(-1.25, 0, -0.25, 0)
end

-- Input callbacks (kept for keyboard movement + sprint on desktop)
local inputConnections = {}
inputConnections[1] = UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	local kc = input.KeyCode

	if kc == Enum.KeyCode.W then keysDown.W = true end
	if kc == Enum.KeyCode.A then keysDown.A = true end
	if kc == Enum.KeyCode.S then keysDown.S = true end
	if kc == Enum.KeyCode.D then keysDown.D = true end

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
connection = RunService.RenderStepped:Connect(function(dt)
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
		CAU:UnbindAction("CamelJump")
		script:Destroy()
		return
	end

	local mv = computeMoveVector()
	if DEBUG and (tick() % 0.5) < dt then -- roughly every 0.5s
		warn(string.format("[CamelDriver] mv=(%.2f, %.2f, %.2f) ws=%d", mv.X, mv.Y, mv.Z, humanoid.WalkSpeed))
	end
	-- Apply movement every frame (Vector3.zero clears WalkDirection)
	humanoid:Move(mv, true)
end)
