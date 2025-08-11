--[[
	LightingManager.lua
	Server-side lighting initialization only - client handles visual updates
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightingService = game:GetService("Lighting")

local TimeConfig = require(ReplicatedStorage.Shared.config.Time)
local DayNightCycle = require(script.Parent.DayNightCycle)

local Lighting = {}

local function applyLightingPreset(preset)
	LightingService.Ambient = preset.Ambient
	LightingService.Brightness = preset.Brightness
	LightingService.ColorShift_Bottom = preset.ColorShift_Bottom
	LightingService.ColorShift_Top = preset.ColorShift_Top
	LightingService.OutdoorAmbient = preset.OutdoorAmbient
end

function Lighting.init()
	print("Initializing server-side lighting...")
	
	-- Set initial lighting preset only - client handles updates
	local initialPreset = DayNightCycle.getCurrentLightingPreset()
	applyLightingPreset(initialPreset)
	
	-- No per-frame updates needed - clients handle visual transitions
	print("Server lighting initialization complete - clients handle visual updates")
end

return Lighting
