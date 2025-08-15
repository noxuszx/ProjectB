-- Medkit.client.lua
-- Optional progress UI for Medkit, similar to Bandage.
-- UI assumed in StarterGui:
--   ScreenGui "MedkitProgressGui" (Enabled=false)
--     Frame "ProgressFrame"
--       Frame "ProgressBar" (Size starts at UDim2.new(0,0,1,0))

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Tool = script.Parent
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local progressGui = playerGui:WaitForChild("MedkitProgressGui", 5)
local progressFrame = progressGui and progressGui:WaitForChild("ProgressFrame", 5)
local progressBar = progressFrame and progressFrame:WaitForChild("ProgressBar", 5)

local currentTween
local USE_TIME = Tool:GetAttribute("UseTime") or 1.0
local holding = false
local heartbeatConn

local function resetBar()
	if progressBar then
		progressBar.Size = UDim2.new(0, 0, 1, 0)
	end
end

local function hideProgress()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	if progressGui then
		progressGui.Enabled = false
	end
	resetBar()
end

local function canShow()
	if not (progressGui and progressFrame and progressBar) then return false end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health >= hum.MaxHealth or hum.Health <= 0 then return false end
	return true
end

local function showProgress()
	if not canShow() then return end
	-- Restart tween cleanly
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	progressGui.Enabled = true
	resetBar()
	if USE_TIME and USE_TIME > 0 then
		currentTween = TweenService:Create(
			progressBar,
			TweenInfo.new(USE_TIME, Enum.EasingStyle.Linear),
			{ Size = UDim2.new(1, 0, 1, 0) }
		)
		currentTween.Completed:Connect(function()
			hideProgress()
		end)
		currentTween:Play()
		-- Failsafe hide after duration
		task.delay(USE_TIME + 0.25, function()
			-- Only hide if we're not currently holding; if we are, Completed already hid
			if not holding then
				hideProgress()
			end
		end)
	else
		hideProgress()
	end
end

-- Keep client UseTime synced with Tool attribute
Tool.Equipped:Connect(function()
	local t = Tool:GetAttribute("UseTime")
	if typeof(t) == "number" then
		USE_TIME = t
	end
	-- Start watchdog once equipped
	if heartbeatConn == nil then
		heartbeatConn = RunService.Heartbeat:Connect(function()
			-- If UI is visible but we are not holding, hide immediately
			if progressGui and progressGui.Enabled and not holding then
				hideProgress()
			end
		end)
	end
end)

Tool.Activated:Connect(function()
	local t = Tool:GetAttribute("UseTime")
	if typeof(t) == "number" then
		USE_TIME = t
	end
	holding = true
	showProgress()
end)

Tool.Deactivated:Connect(function()
	holding = false
	hideProgress()
end)

Tool.Unequipped:Connect(function()
	holding = false
	hideProgress()
	-- Stop watchdog when unequipped
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end)

-- Also hide when server marks use as complete or tool is being destroyed
Tool:GetAttributeChangedSignal("UseComplete"):Connect(function()
	holding = false
	hideProgress()
end)

if Tool.Destroying then
	Tool.Destroying:Connect(function()
		holding = false
		hideProgress()
		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
	end)
end
