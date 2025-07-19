--[[
	DayNightCycle.lua
	Core day/night cycle system managing game time and events
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TimeConfig = require(ReplicatedStorage.Shared.config.TimeConfig)

local DayNightCycle = {}
local currentTime = TimeConfig.START_TIME
local cycleStartTime = tick()
local timeCallbacks = {}

-- Time period tracking
local currentPeriod = nil
local lastPeriod = nil

local function formatTime(gameHours)
	local hours = math.floor(gameHours) % 24
	local minutes = math.floor((gameHours % 1) * 60)
	local period = hours >= 12 and "PM" or "AM"
	local displayHours = hours == 0 and 12 or (hours > 12 and hours - 12 or hours)
	
	return string.format("%d:%02d %s", displayHours, minutes, period)
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

-- Fire time-based events
local function fireTimeEvents(eventType, data)
	if not TimeConfig.ENABLE_TIME_EVENTS then return end
	
	for _, callback in pairs(timeCallbacks) do
		local success, error = pcall(callback, eventType, data)
		if not success then
			warn("Time event callback error:", error)
		end
	end
end

-- Update the current time
local function updateTime()
	local currentTick = tick()
	local elapsedTime = currentTick - cycleStartTime
	
	local gameTimeProgress = (elapsedTime / TimeConfig.DAY_LENGTH) * 24
	currentTime = (TimeConfig.START_TIME + gameTimeProgress) % 24
	
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = currentTime
	
	local newPeriod = getTimePeriod(currentTime)
	if newPeriod ~= currentPeriod then
		lastPeriod = currentPeriod
		currentPeriod = newPeriod
		
		fireTimeEvents("periodChange", {
			newPeriod = newPeriod,
			oldPeriod = lastPeriod,
			gameTime = currentTime,
			formattedTime = formatTime(currentTime)
		})
		
		print(string.format("Time period changed to %s at %s", newPeriod, formatTime(currentTime)))
	end
end

function DayNightCycle.getCurrentTime()
	return currentTime
end

function DayNightCycle.getCurrentPeriod()
	return currentPeriod or getTimePeriod(currentTime)
end

function DayNightCycle.getFormattedTime()
	return formatTime(currentTime)
end

function DayNightCycle.getTimeProgress()
	local elapsedTime = tick() - cycleStartTime
	return (elapsedTime / TimeConfig.DAY_LENGTH) % 1
end

function DayNightCycle.getCurrentLightingPreset()
	local period = DayNightCycle.getCurrentPeriod()
	return TimeConfig.LIGHTING_PRESETS[period]
end

function DayNightCycle.registerTimeCallback(callback)
	table.insert(timeCallbacks, callback)
end

function DayNightCycle.unregisterTimeCallback(callback)
	for i, cb in ipairs(timeCallbacks) do
		if cb == callback then
			table.remove(timeCallbacks, i)
			break
		end
	end
end

function DayNightCycle.setTime(gameHours)
	currentTime = gameHours % 24
	cycleStartTime = tick() - ((currentTime - TimeConfig.START_TIME) / 24) * TimeConfig.DAY_LENGTH
	updateTime()
end

function DayNightCycle.skipToNextPeriod()
	local period = DayNightCycle.getCurrentPeriod()
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
	
	DayNightCycle.setTime(targetTime)
end

function DayNightCycle.init()
	print("Initializing day/night cycle...")
	print("Day length:", TimeConfig.DAY_LENGTH, "seconds")
	print("Starting time:", formatTime(TimeConfig.START_TIME))
	
	currentTime = TimeConfig.START_TIME
	cycleStartTime = tick()
	currentPeriod = getTimePeriod(currentTime)
	
	RunService.Heartbeat:Connect(function()
		updateTime()
	end)
	
	fireTimeEvents("init", {
		period = currentPeriod,
		gameTime = currentTime,
		formattedTime = formatTime(currentTime)
	})
	
	print("Day/night cycle initialized!")
	print("Current time:", formatTime(currentTime))
	print("Current period:", currentPeriod)
end

function DayNightCycle.getDebugInfo()
	return {
		currentTime = currentTime,
		formattedTime = formatTime(currentTime),
		currentPeriod = currentPeriod,
		timeProgress = DayNightCycle.getTimeProgress(),
		cycleStartTime = cycleStartTime,
		elapsedTime = tick() - cycleStartTime
	}
end

return DayNightCycle
