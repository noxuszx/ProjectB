--[[
	LightingManager.lua
	Handles Lighting transitions based on time of day
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightingService = game:GetService("Lighting")

local TimeConfig = require(ReplicatedStorage.Shared.config.Time)
local DayNightCycle = require(script.Parent.DayNightCycle)

local TweenService = game:GetService("TweenService")

local Lighting = {}
local currentTween = nil
local lastPeriod = nil

local function applyLightingPreset(preset)
	LightingService.Ambient = preset.Ambient
	LightingService.Brightness = preset.Brightness
	LightingService.ColorShift_Bottom = preset.ColorShift_Bottom
	LightingService.ColorShift_Top = preset.ColorShift_Top
	LightingService.OutdoorAmbient = preset.OutdoorAmbient
end

local function tweenLighting(preset)
	if currentTween then
		currentTween:Cancel()
	end
	
	local tweenInfo = TweenInfo.new(TimeConfig.TRANSITION_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
	
	local tween = TweenService:Create(LightingService, tweenInfo, {
		Ambient = preset.Ambient,
		Brightness = preset.Brightness,
		ColorShift_Bottom = preset.ColorShift_Bottom,
		ColorShift_Top = preset.ColorShift_Top,
		OutdoorAmbient = preset.OutdoorAmbient
	})
	
	tween:Play()
	currentTween = tween
end

local function updateLighting()
	local currentPeriod = DayNightCycle.getCurrentPeriod()
	if currentPeriod ~= lastPeriod then
		lastPeriod = currentPeriod
		local newPreset = DayNightCycle.getCurrentLightingPreset()
		tweenLighting(newPreset)
	end
end

function Lighting.init()
	print("Initializing Lighting manager...")
	
	local initialPreset = DayNightCycle.getCurrentLightingPreset()
	applyLightingPreset(initialPreset)
	
	game:GetService("RunService").Heartbeat:Connect(function()
		updateLighting()
	end)
end

return Lighting
