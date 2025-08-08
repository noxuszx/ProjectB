-- src/client/StatsDisplay.client.lua
-- Client-side UI display for player stats (Hunger and Thirst bars)
-- References manually created UI elements (no Instance.new() for performance)

local Players 			= game:GetService("Players")
local TweenService 		= game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStatsConfig = require(ReplicatedStorage.Shared.config.PlayerStatsConfig)

local player 	= Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StatsDisplay = {}

-- UI elements (references to manually created elements)
local playerStatsGui   = nil
local statsFrame 	   = nil
local hungerBar 	   = nil
local thirstBar 	   = nil
local hungerBackground = nil
local thirstBackground = nil

local currentStats = {
	Hunger = PlayerStatsConfig.MAX_HUNGER,
	Thirst = PlayerStatsConfig.MAX_THIRST,
}

function StatsDisplay.init()
	print("[StatsDisplay] Initializing client-side stats display...")

	local updatePlayerStatsRemote = ReplicatedStorage.Remotes:WaitForChild("UpdatePlayerStats", 10)
	if not updatePlayerStatsRemote then
		warn("[StatsDisplay] UpdatePlayerStats RemoteEvent not found!")
		return false
	end

	if not StatsDisplay.getUIReferences() then
		warn("[StatsDisplay] Failed to get UI references!")
		return false
	end

	updatePlayerStatsRemote.OnClientEvent:Connect(StatsDisplay.onStatsUpdate)

	print("[StatsDisplay] Stats display initialized!")
	return true
end

-- Get references to manually created UI elements
function StatsDisplay.getUIReferences()

	playerStatsGui = playerGui:WaitForChild("PlayerStatsGui", 10)
	if not playerStatsGui then
		warn("[StatsDisplay] PlayerStatsGui not found! Create it manually in StarterGui.")
		return false
	end

	statsFrame = playerStatsGui:WaitForChild("StatsFrame", 5)
	if not statsFrame then
		warn("[StatsDisplay] StatsFrame not found in PlayerStatsGui!")
		return false
	end

	hungerBackground = statsFrame:WaitForChild("HungerBackground", 5)
	if hungerBackground then
		hungerBar = hungerBackground:WaitForChild("HungerBar", 5)
	end

	thirstBackground = statsFrame:WaitForChild("ThirstBackground", 5)
	if thirstBackground then
		thirstBar = thirstBackground:WaitForChild("ThirstBar", 5)
	end

	if not hungerBar or not thirstBar then
		warn("[StatsDisplay] Missing hunger or thirst bar elements!")
		return false
	end

	print("[StatsDisplay] Successfully referenced manual UI elements")
	return true
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
	local tweenInfo =
		TweenInfo.new(PlayerStatsConfig.UI.UI_UPDATE_SMOOTHNESS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(barElement, tweenInfo, {
		Size = UDim2.new(percentage, 0, 1, 0),
	})

	tween:Play()

	-- Change color when stat is critically low (< 25%)
	if percentage < 0.25 then
		-- Flash red when critically low
		local colorTween = TweenService:Create(barElement, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(255, 100, 100),
		})
		colorTween:Play()

		-- Return to normal color after flash
		colorTween.Completed:Connect(function()
			task.wait(0.5)
			local returnTween = TweenService:Create(barElement, tweenInfo, {
				BackgroundColor3 = barElement.Name:find("Hunger") and PlayerStatsConfig.UI.HUNGER_COLOR
					or PlayerStatsConfig.UI.THIRST_COLOR,
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
	-- Clear references to manually created UI elements
	playerStatsGui = nil
	statsFrame = nil
	hungerBar = nil
	thirstBar = nil
	hungerBackground = nil
	thirstBackground = nil

	currentStats = {
		Hunger = PlayerStatsConfig.MAX_HUNGER,
		Thirst = PlayerStatsConfig.MAX_THIRST,
	}

	print("[StatsDisplay] UI references cleared")
end

StatsDisplay.init()
return StatsDisplay
