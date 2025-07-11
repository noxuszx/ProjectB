--[[
	LightingManager.lua
	Handles lighting transitions based on time of day
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local TimeConfig = require(ReplicatedStorage.Shared.config.TimeConfig)
local DayNightCycle = require(script.Parent.DayNightCycle)

local TweenService = game:GetService("TweenService")

local LightingManager = {}
local currentTween = nil -- Current tween for smooth transitions

-- Apply lighting preset instantly
local function applyLightingPreset(preset)
	-- Note: ClockTime is handled continuously by DayNightCycle
	Lighting.Ambient = preset.Ambient
	Lighting.Brightness = preset.Brightness
	Lighting.ColorShift_Bottom = preset.ColorShift_Bottom
	Lighting.ColorShift_Top = preset.ColorShift_Top
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
end

-- Tween lighting settings for smooth transition
local function tweenLighting(preset)
	if currentTween then
		currentTween:Cancel() -- Cancel existing tween
	end
	
	-- Note: ClockTime is handled continuously by DayNightCycle
	-- Only tween the color properties smoothly
	local tweenInfo = TweenInfo.new(TimeConfig.TRANSITION_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
	
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

-- Update lighting on time period change
local function onTimePeriodChange(eventType, data)
	if eventType ~= "periodChange" then return end
	
	local newPreset = DayNightCycle.getCurrentLightingPreset()
	print("Switching to lighting preset:", data.newPeriod, "Description:", newPreset.description)
	tweenLighting(newPreset)
end

-- Initialize lighting manager
function LightingManager.init()
	print("Initializing lighting manager...")
	
	local initialPreset = DayNightCycle.getCurrentLightingPreset()
	applyLightingPreset(initialPreset)
	
	DayNightCycle.registerTimeCallback(onTimePeriodChange)
	
	print("Lighting manager ready. Initial preset:", DayNightCycle.getCurrentPeriod())
end

return LightingManager
