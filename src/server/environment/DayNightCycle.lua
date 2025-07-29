--[[
	dayNightCycle.lua
	Core day/night cycle system managing game time and events
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TimeConfig = require(ReplicatedStorage.Shared.config.time)

local dayNightCycle = {}
local currentTime = TimeConfig.START_TIME
local cycleStartTime = os.clock()
local timeCallbacks = {}

local currentPeriod = nil
local lastPeriod = nil

local function formatTime(gameHours)
	local hour = math.floor(gameHours) % 24
	return string.format("%.1f", gameHours)
end

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

local function updateTime()
	local currentTick = os.clock()
	local elapsedTime = currentTick - cycleStartTime
	local gameTimeProgress = (elapsedTime / TimeConfig.DAY_LENGTH) * 24

	currentTime = (TimeConfig.START_TIME + gameTimeProgress) % 24
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = currentTime
	local newPeriod = getTimePeriod(currentTime)

	if newPeriod ~= currentPeriod then
		lastPeriod = currentPeriod
		currentPeriod = newPeriod
	end
end

function dayNightCycle.getCurrentTime()
	return currentTime
end

function dayNightCycle.getCurrentPeriod()
	return currentPeriod or getTimePeriod(currentTime)
end

function dayNightCycle.getFormattedTime()
	return formatTime(currentTime)
end

function dayNightCycle.getTimeProgress()
	local elapsedTime = os.clock() - cycleStartTime
	return (elapsedTime / TimeConfig.DAY_LENGTH) % 1
end

function dayNightCycle.getCurrentLightingPreset()
	local period = dayNightCycle.getCurrentPeriod()
	return TimeConfig.LIGHTING_PRESETS[period]
end

function dayNightCycle.setTime(gameHours)
	currentTime = gameHours % 24
	cycleStartTime = os.clock() - ((currentTime - TimeConfig.START_TIME) / 24) * TimeConfig.DAY_LENGTH
	updateTime()
end

function dayNightCycle.skipToNextPeriod()
	local period = dayNightCycle.getCurrentPeriod()
	local targetTime
	
	if period == "NIGHT" then
		targetTime = TimeConfig.DAWN_START
	elseif period == "DAWN" then
		targetTime = TimeConfig.SUNRISE_START
	elseif period == "SUNRISE" then
		targetTime = TimeConfig.MORNING_START
	elseif period == "MORNING" then
		targetTime = TimeConfig.NOON_START
	elseif period == "NOON" then
		targetTime = TimeConfig.AFTERNOON_START
	elseif period == "AFTERNOON" then
		targetTime = TimeConfig.SUNSET_START
	elseif period == "SUNSET" then
		targetTime = TimeConfig.DUSK_START
	elseif period == "DUSK" then
		targetTime = TimeConfig.NIGHT_START
	else
		targetTime = TimeConfig.DAWN_START
	end
	
	dayNightCycle.setTime(targetTime)
end

function dayNightCycle.init()
	
	currentTime = TimeConfig.START_TIME
	cycleStartTime = os.clock()
	currentPeriod = getTimePeriod(currentTime)
	
	RunService.Heartbeat:Connect(function()
		updateTime()
	end)
	
	print("Day/Night cycle initialized...")
end

function dayNightCycle.getDebugInfo()
	return {
		currentPeriod = currentPeriod,
		gameTime = currentTime
	}
end

return dayNightCycle
