-- src/client/StatsDisplay.client.lua
-- Client-side UI display for player stats (Hunger and Thirst bars)
-- Receives updates from server and displays small horizontal bars on left side

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStatsConfig = require(ReplicatedStorage.Shared.config.PlayerStatsConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StatsDisplay = {}

-- UI elements
local statsFrame = nil
local hungerBar = nil
local thirstBar = nil
local hungerBackground = nil
local thirstBackground = nil

local currentStats = {
	Hunger = PlayerStatsConfig.MAX_HUNGER,
	Thirst = PlayerStatsConfig.MAX_THIRST
}

function StatsDisplay.init()
	print("[StatsDisplay] Initializing client-side stats display...")
	
	local updatePlayerStatsRemote = ReplicatedStorage.Remotes:WaitForChild("UpdatePlayerStats", 10)
	if not updatePlayerStatsRemote then
		warn("[StatsDisplay] UpdatePlayerStats RemoteEvent not found!")
		return false
	end
	
	StatsDisplay.createUI()
	updatePlayerStatsRemote.OnClientEvent:Connect(StatsDisplay.onStatsUpdate)
	
	print("[StatsDisplay] Stats display initialized!")
	return true
end

-- Create the UI elements
function StatsDisplay.createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StatsDisplayGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsDisplay"
	statsFrame.Size = UDim2.new(0, PlayerStatsConfig.UI.BAR_WIDTH + 20, 0, 80)
	statsFrame.Position = UDim2.new(0, PlayerStatsConfig.UI.BAR_POSITION_LEFT_OFFSET, 0, 50)
	statsFrame.BackgroundTransparency = 1
	statsFrame.Parent = screenGui
	
	StatsDisplay.createStatBar("Hunger", PlayerStatsConfig.UI.HUNGER_COLOR, 0)
	StatsDisplay.createStatBar("Thirst", PlayerStatsConfig.UI.THIRST_COLOR, 1)
	
	print("[StatsDisplay] UI elements created")
end

-- Create a stat bar (hunger or thirst)
function StatsDisplay.createStatBar(statName, color, index)
	local yOffset = index * (PlayerStatsConfig.UI.BAR_HEIGHT + PlayerStatsConfig.UI.BAR_SPACING)
	
	-- Background bar (dark)
	local background = Instance.new("Frame")
	background.Name = statName .. "Background"
	background.Size = UDim2.new(0, PlayerStatsConfig.UI.BAR_WIDTH, 0, PlayerStatsConfig.UI.BAR_HEIGHT)
	background.Position = UDim2.new(0, 10, 0, yOffset + 10)
	background.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	background.BorderSizePixel = 1
	background.BorderColor3 = Color3.fromRGB(200, 200, 200)
	background.Parent = statsFrame
	
	local foreground = Instance.new("Frame")
	foreground.Name = statName .. "Bar"
	foreground.Size = UDim2.new(1, 0, 1, 0)
	foreground.Position = UDim2.new(0, 0, 0, 0)
	foreground.BackgroundColor3 = color
	foreground.BorderSizePixel = 0
	foreground.Parent = background
	
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, color)
	}
	gradient.Rotation = 90
	gradient.Parent = foreground
	
	if statName == "Hunger" then
		hungerBackground = background
		hungerBar = foreground
	elseif statName == "Thirst" then
		thirstBackground = background
		thirstBar = foreground
	end
end

function StatsDisplay.onStatsUpdate(newStats)
	if not newStats then
		warn("[StatsDisplay] Received invalid stats data")
		return
	end
	
	if newStats.Hunger ~= nil then
		StatsDisplay.updateBar(hungerBar, newStats.Hunger, PlayerStatsConfig.MAX_HUNGER)
		currentStats.Hunger = newStats.Hunger
	end
	
	if newStats.Thirst ~= nil then
		StatsDisplay.updateBar(thirstBar, newStats.Thirst, PlayerStatsConfig.MAX_THIRST)
		currentStats.Thirst = newStats.Thirst
	end
end

function StatsDisplay.updateBar(barElement, currentValue, maxValue)
	if not barElement then
		return
	end
	
	local percentage = math.max(0, math.min(1, currentValue / maxValue))
	local tweenInfo = TweenInfo.new(
		PlayerStatsConfig.UI.UI_UPDATE_SMOOTHNESS,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local tween = TweenService:Create(barElement, tweenInfo, {
		Size = UDim2.new(percentage, 0, 1, 0)
	})
	
	tween:Play()
	
	-- Change color when stat is critically low (< 25%)
	if percentage < 0.25 then
		-- Flash red when critically low
		local colorTween = TweenService:Create(barElement, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(255, 100, 100)
		})
		colorTween:Play()
		
		-- Return to normal color after flash
		colorTween.Completed:Connect(function()
			wait(0.5)
			local returnTween = TweenService:Create(barElement, tweenInfo, {
				BackgroundColor3 = barElement.Name:find("Hunger") and PlayerStatsConfig.UI.HUNGER_COLOR or PlayerStatsConfig.UI.THIRST_COLOR
			})
			returnTween:Play()
		end)
	end
end

function StatsDisplay.getCurrentStats()
	return currentStats
end

function StatsDisplay.setVisible(visible)
	if statsFrame then
		statsFrame.Visible = visible
	end
end

function StatsDisplay.cleanup()
	if statsFrame then
		statsFrame:Destroy()
		statsFrame = nil
		hungerBar = nil
		thirstBar = nil
		hungerBackground = nil
		thirstBackground = nil
	end
	
	currentStats = {
		Hunger = PlayerStatsConfig.MAX_HUNGER,
		Thirst = PlayerStatsConfig.MAX_THIRST
	}
	
	print("[StatsDisplay] UI cleaned up")
end

StatsDisplay.init()
return StatsDisplay