--[[
	LightingManager.lua
	Handles lighting transitions based on time of day
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local TimeConfig = require(ReplicatedStorage.Shared.config.time)
local DayNightCycle = require(script.Parent.dayNightCycle)

local TweenService = game:GetService("TweenService")

local lighting = {}
local currentTween = nil
local lastPeriod = nil

local function applyLightingPreset(preset)
	Lighting.Ambient = preset.Ambient
	Lighting.Brightness = preset.Brightness
	Lighting.ColorShift_Bottom = preset.ColorShift_Bottom
	Lighting.ColorShift_Top = preset.ColorShift_Top
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
end

local function tweenLighting(preset)
	if currentTween then
		currentTween:Cancel()
	end
	
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

local function updateLighting()
	local currentPeriod = DayNightCycle.getCurrentPeriod()
	if currentPeriod ~= lastPeriod then
		lastPeriod = currentPeriod
		local newPreset = DayNightCycle.getCurrentLightingPreset()
		tweenLighting(newPreset)
	end
end

function lighting.init()
	print("Initializing lighting manager...")
	
	local initialPreset = DayNightCycle.getCurrentLightingPreset()
	applyLightingPreset(initialPreset)
	
	game:GetService("RunService").Heartbeat:Connect(function()
		updateLighting()
	end)
end

return lighting
