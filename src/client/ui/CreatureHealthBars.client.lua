-- src/client/ui/CreatureHealthBars.client.lua
-- Client-side health bar display for creatures
-- Creates green health bars above creatures when they're hurt

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CreatureHealthBars = {}

-- Debug configuration
local DEBUG_ENABLED = false

-- UI elements
local healthBarsGui = nil
local activeHealthBars = {}

-- Configuration
local HEALTH_BAR_CONFIG = {
	BAR_WIDTH = 100,
	BAR_HEIGHT = 12,
	BAR_COLOR = Color3.fromRGB(50, 205, 50),
	BACKGROUND_COLOR = Color3.fromRGB(50, 50, 50),
	BORDER_COLOR = Color3.fromRGB(200, 200, 200),

	DISPLAY_DISTANCE = 50,
	HIDE_WHEN_FULL_HEALTH = true,
	FADE_OUT_TIME = 3,
	UPDATE_RATE = 0.1,

	UPDATE_SMOOTHNESS = 0.2,
	FADE_DURATION = 0.5,
}

function CreatureHealthBars.init()
	if DEBUG_ENABLED then
		print("[CreatureHealthBars] Initializing creature health bars...")
	end

	local updateCreatureHealthRemote = ReplicatedStorage.Remotes:WaitForChild("UpdateCreatureHealth", 10)
	if not updateCreatureHealthRemote then
		warn("[CreatureHealthBars] UpdateCreatureHealth RemoteEvent not found!")
		return false
	end

	CreatureHealthBars.createUI()
	updateCreatureHealthRemote.OnClientEvent:Connect(CreatureHealthBars.onCreatureHealthUpdate)
	RunService.Heartbeat:Connect(CreatureHealthBars.updateHealthBarPositions)

	if DEBUG_ENABLED then
		print("[CreatureHealthBars] Creature health bars initialized!")
	end
	return true
end

function CreatureHealthBars.createUI()
	healthBarsGui = Instance.new("ScreenGui")
	healthBarsGui.Name = "CreatureHealthBarsGui"
	healthBarsGui.ResetOnSpawn = false
	healthBarsGui.Parent = playerGui

	if DEBUG_ENABLED then
		print("[CreatureHealthBars] UI container created")
	end
end

function CreatureHealthBars.createHealthBar(creatureModel, health, maxHealth)
	if activeHealthBars[creatureModel] then
		CreatureHealthBars.updateHealthBar(creatureModel, health, maxHealth)
		return
	end

	local frame = Instance.new("Frame")
	frame.Name = "CreatureHealthBar_" .. creatureModel.Name
	frame.Size = UDim2.new(0, HEALTH_BAR_CONFIG.BAR_WIDTH + 4, 0, HEALTH_BAR_CONFIG.BAR_HEIGHT + 4)
	frame.BackgroundTransparency = 1
	frame.Parent = healthBarsGui

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(0, HEALTH_BAR_CONFIG.BAR_WIDTH, 0, HEALTH_BAR_CONFIG.BAR_HEIGHT)
	background.Position = UDim2.new(0, 2, 0, 2)
	background.BackgroundColor3 = HEALTH_BAR_CONFIG.BACKGROUND_COLOR
	background.BorderSizePixel = 1
	background.BorderColor3 = HEALTH_BAR_CONFIG.BORDER_COLOR
	background.Parent = frame

	local bar = Instance.new("Frame")
	bar.Name = "HealthBar"
	bar.BackgroundColor3 = HEALTH_BAR_CONFIG.BAR_COLOR
	bar.BorderSizePixel = 0
	bar.Parent = background

	activeHealthBars[creatureModel] = {
		frame = frame,
		bar = bar,
		background = background,
		lastUpdate = os.clock(),
		lastFullHealthTime = nil,
	}

	CreatureHealthBars.updateHealthBar(creatureModel, health, maxHealth)
end

function CreatureHealthBars.updateHealthBar(creatureModel, health, maxHealth)
	local healthBarData = activeHealthBars[creatureModel]
	if not healthBarData then
		return
	end

	local percentage = math.max(0, math.min(1, health / maxHealth))
	healthBarData.lastUpdate = os.clock()

	if percentage >= 1 then
		if not healthBarData.lastFullHealthTime then
			healthBarData.lastFullHealthTime = os.clock()
		end
	else
		healthBarData.lastFullHealthTime = nil
	end

	healthBarData.bar.Size = UDim2.new(percentage, 0, 1, 0)

	local color = HEALTH_BAR_CONFIG.BAR_COLOR
	if percentage < 0.25 then
		color = Color3.fromRGB(244, 67, 54)
	elseif percentage < 0.5 then
		color = Color3.fromRGB(255, 193, 7)
	end

	healthBarData.bar.BackgroundColor3 = color
end

function CreatureHealthBars.updateHealthBarPositions()
	if not player.Character or not player.Character.PrimaryPart then
		return
	end

	local camera = workspace.CurrentCamera
	local playerPosition = player.Character.PrimaryPart.Position

	for creatureModel, healthBarData in pairs(activeHealthBars) do
		if not creatureModel or not creatureModel.Parent or not creatureModel.PrimaryPart then
			-- Creature destroyed, remove health bar
			CreatureHealthBars.removeHealthBar(creatureModel)
			continue
		end

		local creaturePosition = creatureModel.PrimaryPart.Position
		local distance = (creaturePosition - playerPosition).Magnitude

		-- Hide if too far away
		if distance > HEALTH_BAR_CONFIG.DISPLAY_DISTANCE then
			healthBarData.frame.Visible = false
			continue
		end

		if HEALTH_BAR_CONFIG.HIDE_WHEN_FULL_HEALTH and healthBarData.lastFullHealthTime then
			local timeSinceFullHealth = os.clock() - healthBarData.lastFullHealthTime
			if timeSinceFullHealth > HEALTH_BAR_CONFIG.FADE_OUT_TIME then
				CreatureHealthBars.fadeOutHealthBar(creatureModel)
				continue
			end
		end

		local headPosition = creaturePosition + Vector3.new(0, 2, 0) -- Offset above creature
		local screenPosition, onScreen = camera:WorldToScreenPoint(headPosition)

		if onScreen then
			healthBarData.frame.Visible = true
			healthBarData.frame.Position = UDim2.new(
				0,
				screenPosition.X - HEALTH_BAR_CONFIG.BAR_WIDTH / 2,
				0,
				screenPosition.Y - HEALTH_BAR_CONFIG.BAR_HEIGHT - 10
			)
		else
			healthBarData.frame.Visible = false
		end
	end
end

function CreatureHealthBars.fadeOutHealthBar(creatureModel)
	local healthBarData = activeHealthBars[creatureModel]
	if not healthBarData then
		return
	end

	local tweenInfo = TweenInfo.new(HEALTH_BAR_CONFIG.FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local tween = TweenService:Create(healthBarData.frame, tweenInfo, {
		BackgroundTransparency = 1,
	})

	tween:Play()
	tween.Completed:Connect(function()
		CreatureHealthBars.removeHealthBar(creatureModel)
	end)
end

function CreatureHealthBars.removeHealthBar(creatureModel)
	local healthBarData = activeHealthBars[creatureModel]
	if healthBarData then
		if healthBarData.frame then
			healthBarData.frame:Destroy()
		end
		activeHealthBars[creatureModel] = nil
	end
end

function CreatureHealthBars.onCreatureHealthUpdate(creatureModel, health, maxHealth)
	if not creatureModel or not creatureModel.Parent then
		CreatureHealthBars.removeHealthBar(creatureModel)
		return
	end

	-- no-op for hit sounds; handled directly in weapon clients for reliability

	if health <= 0 then
		CreatureHealthBars.removeHealthBar(creatureModel)
		return
	end

	if health < maxHealth then
		CreatureHealthBars.createHealthBar(creatureModel, health, maxHealth)
	else
		local healthBarData = activeHealthBars[creatureModel]
		if healthBarData then
			CreatureHealthBars.updateHealthBar(creatureModel, health, maxHealth)
		end
	end
end

function CreatureHealthBars.cleanup()
	for creatureModel, _ in pairs(activeHealthBars) do
		CreatureHealthBars.removeHealthBar(creatureModel)
	end

	if healthBarsGui then
		healthBarsGui:Destroy()
		healthBarsGui = nil
	end

	if DEBUG_ENABLED then
		print("[CreatureHealthBars] UI cleaned up")
	end
end

CreatureHealthBars.init()

return CreatureHealthBars
