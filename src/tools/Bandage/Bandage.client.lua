-- Bandage.client.lua
-- Drives a prebuilt UI progress bar while using the Bandage tool.
-- Assumes you created in StarterGui:
--   ScreenGui "BandageProgressGui" (Enabled=false)
--     Frame "ProgressFrame"
--       Frame "ProgressBar" (Size starts at UDim2.new(0,0,1,0))

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Tool = script.Parent
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get references to your prebuilt UI
local progressGui = playerGui:WaitForChild("BandageProgressGui", 5)
local progressFrame = progressGui and progressGui:WaitForChild("ProgressFrame", 5)
local progressBar = progressFrame and progressFrame:WaitForChild("ProgressBar", 5)

local currentTween
local USE_TIME = Tool:GetAttribute("UseTime") or 1.0

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

local function showProgress()
	if not (progressGui and progressFrame and progressBar) then
		return
	end
	-- Only show if player can actually heal
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health >= hum.MaxHealth or hum.Health <= 0 then
		return
	end

	progressGui.Enabled = true
	resetBar()
	if USE_TIME and USE_TIME > 0 then
		currentTween = TweenService:Create(
			progressBar,
			TweenInfo.new(USE_TIME, Enum.EasingStyle.Linear),
			{ Size = UDim2.new(1, 0, 1, 0) }
		)
		currentTween.Completed:Connect(function(state)
			hideProgress()
		end)
		currentTween:Play()
		-- Failsafe hide after duration
		task.delay(USE_TIME + 0.2, function()
			hideProgress()
		end)
	else
		-- Instant use: briefly flash then hide
		hideProgress()
	end
end



-- Keep client UseTime synced with Tool attribute
Tool.Equipped:Connect(function()
	local t = Tool:GetAttribute("UseTime")
	if typeof(t) == "number" then
		USE_TIME = t
	end
end)

Tool.Activated:Connect(function()
	-- Re-read UseTime each activation in case attribute changed
	local t = Tool:GetAttribute("UseTime")
	if typeof(t) == "number" then
		USE_TIME = t
	end
	showProgress()
end)
Tool.Deactivated:Connect(function()
	hideProgress()
end)
Tool.Unequipped:Connect(function()
	hideProgress()
end)

-- Also hide when server marks use as complete or tool is being destroyed
Tool:GetAttributeChangedSignal("UseComplete"):Connect(function()
	hideProgress()
end)

if Tool.Destroying then
	Tool.Destroying:Connect(function()
		hideProgress()
	end)
end

