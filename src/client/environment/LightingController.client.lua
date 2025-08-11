--[[
	LightingController.client.lua
	Client-side lighting system - handles visual updates locally to reduce server replication
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local TimeConfig = require(ReplicatedStorage.Shared.config.Time)

-- Cache services and RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TimeSystem")
local periodChangedRemote = remotes:WaitForChild("PeriodChanged")
local syncTimeRemote = remotes:WaitForChild("SyncTime")

local LightingController = {}

-- Local state
local currentTime = TimeConfig.START_TIME
local currentPeriod = nil
local cycleStartTime = os.clock()
local currentTween = nil
local lastSyncTime = os.clock()

-- Sync interval (30 seconds to prevent drift)
local SYNC_INTERVAL = 30

local function getTimePeriod(gameHours)
	local hour = gameHours % 24
	
	if hour >= TimeConfig.MIDNIGHT_START or hour < TimeConfig.DAWN_START then
		return "NIGHT"
	elseif hour >= TimeConfig.DAWN_START and hour < TimeConfig.SUNRISE_START then
		return "DAWN"
	elseif hour >= TimeConfig.SUNRISE_START and hour < TimeConfig.MORNING_START then
		return "SUNRISE"
	elseif hour >= TimeConfig.MORNING_START and hour < TimeConfig.NOON_START then
		return "MORNING"
	elseif hour >= TimeConfig.NOON_START and hour < TimeConfig.AFTERNOON_START then
		return "NOON"
	elseif hour >= TimeConfig.AFTERNOON_START and hour < TimeConfig.SUNSET_START then
		return "AFTERNOON"
	elseif hour >= TimeConfig.SUNSET_START and hour < TimeConfig.DUSK_START then
		return "SUNSET"
	elseif hour >= TimeConfig.DUSK_START and hour < TimeConfig.NIGHT_START then
		return "DUSK"
	else
		return "NIGHT"
	end
end

local function applyLightingPreset(preset)
	if currentTween then
		currentTween:Cancel()
	end
	
	local tweenInfo = TweenInfo.new(
		TimeConfig.TRANSITION_DURATION, 
		Enum.EasingStyle.Linear, 
		Enum.EasingDirection.InOut
	)
	
	local tween = TweenService:Create(Lighting, tweenInfo, {
		Ambient = preset.Ambient,
		Brightness = preset.Brightness,
		ColorShift_Bottom = preset.ColorShift_Bottom,
		ColorShift_Top = preset.ColorShift_Top,
		OutdoorAmbient = preset.OutdoorAmbient
	})
	
	tween:Play()
	currentTween = tween
end

local function updateClientTime()
	local currentTick = os.clock()
	local elapsedTime = currentTick - cycleStartTime
	local gameTimeProgress = (elapsedTime / TimeConfig.DAY_LENGTH) * 24
	
	currentTime = (TimeConfig.START_TIME + gameTimeProgress) % 24
	Lighting.ClockTime = currentTime
	
	-- Check for period changes
	local newPeriod = getTimePeriod(currentTime)
	if newPeriod ~= currentPeriod then
		currentPeriod = newPeriod
		local preset = TimeConfig.LIGHTING_PRESETS[newPeriod]
		if preset then
			applyLightingPreset(preset)
		end
	end
	
	-- Request time sync if needed
	if currentTick - lastSyncTime > SYNC_INTERVAL then
		syncTimeRemote:FireServer()
		lastSyncTime = currentTick
	end
end

-- Handle server period changes (fallback/sync)
periodChangedRemote.OnClientEvent:Connect(function(period, serverTime)
	if period ~= currentPeriod then
		currentPeriod = period
		local preset = TimeConfig.LIGHTING_PRESETS[period]
		if preset then
			applyLightingPreset(preset)
		end
	end
	
	-- Sync time if provided
	if serverTime then
		currentTime = serverTime
		cycleStartTime = os.clock() - ((currentTime - TimeConfig.START_TIME) / 24) * TimeConfig.DAY_LENGTH
	end
end)

-- Handle time sync responses
syncTimeRemote.OnClientEvent:Connect(function(serverTime)
	currentTime = serverTime
	cycleStartTime = os.clock() - ((currentTime - TimeConfig.START_TIME) / 24) * TimeConfig.DAY_LENGTH
	lastSyncTime = os.clock()
end)

function LightingController.init()
	-- Initialize with current time period
	currentPeriod = getTimePeriod(currentTime)
	local initialPreset = TimeConfig.LIGHTING_PRESETS[currentPeriod]
	if initialPreset then
		-- Apply immediately without tween for initialization
		Lighting.Ambient = initialPreset.Ambient
		Lighting.Brightness = initialPreset.Brightness
		Lighting.ColorShift_Bottom = initialPreset.ColorShift_Bottom
		Lighting.ColorShift_Top = initialPreset.ColorShift_Top
		Lighting.OutdoorAmbient = initialPreset.OutdoorAmbient
	end
	
	-- Start client-side time updates
	RunService.Heartbeat:Connect(updateClientTime)
	
	print("Client-side lighting controller initialized")
end

-- Auto-initialize when script loads
LightingController.init()

return LightingController