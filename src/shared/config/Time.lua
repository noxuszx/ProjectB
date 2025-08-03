--[[
	TimeConfig.lua
	Configuration for day/night cycle system
]]--

local TimeConfig = {}

TimeConfig.DAY_LENGTH = 480
TimeConfig.START_TIME = 6

TimeConfig.DAWN_START = 5.5
TimeConfig.SUNRISE_START = 6.0
TimeConfig.MORNING_START = 8.0
TimeConfig.NOON_START = 12.0
TimeConfig.AFTERNOON_START = 15.0
TimeConfig.SUNSET_START = 18.0
TimeConfig.DUSK_START = 19.0
TimeConfig.NIGHT_START = 20.0
TimeConfig.MIDNIGHT_START = 24.0

TimeConfig.LIGHTING_PRESETS = {
	
	NIGHT = {
		ClockTime = 3,
		Ambient = Color3.fromRGB(15, 25, 45),
		Brightness = 0.5,
		ColorShift_Bottom = Color3.fromRGB(10, 15, 30),
		ColorShift_Top = Color3.fromRGB(25, 35, 60),
		OutdoorAmbient = Color3.fromRGB(20, 30, 50),
		description = "Cool desert night with moon"
	},
	
	DAWN = {
		ClockTime = 5.5,
		Ambient = Color3.fromRGB(40, 35, 60),
		Brightness = 1.0,
		ColorShift_Bottom = Color3.fromRGB(80, 60, 40),
		ColorShift_Top = Color3.fromRGB(120, 80, 60),
		OutdoorAmbient = Color3.fromRGB(60, 50, 80),
		description = "Pre-dawn purple sky"
	},
	
	SUNRISE = {
		ClockTime = 6.5,
		Ambient = Color3.fromRGB(80, 60, 40),
		Brightness = 1.5,
		ColorShift_Bottom = Color3.fromRGB(255, 180, 100),
		ColorShift_Top = Color3.fromRGB(255, 150, 80),
		OutdoorAmbient = Color3.fromRGB(180, 120, 80),
		description = "Golden sunrise"
	},
	
	MORNING = {
		ClockTime = 10,
		Ambient = Color3.fromRGB(120, 120, 100),
		Brightness = 2.0,
		ColorShift_Bottom = Color3.fromRGB(255, 240, 200),
		ColorShift_Top = Color3.fromRGB(180, 200, 255),
		OutdoorAmbient = Color3.fromRGB(200, 180, 140),
		description = "Bright morning light"
	},
	
	NOON = {
		ClockTime = 12,
		Ambient = Color3.fromRGB(150, 150, 130),
		Brightness = 3.0,
		ColorShift_Bottom = Color3.fromRGB(255, 255, 220),
		ColorShift_Top = Color3.fromRGB(200, 220, 255),
		OutdoorAmbient = Color3.fromRGB(220, 200, 160),
		description = "Harsh midday sun"
	},
	
	AFTERNOON = {
		ClockTime = 15,
		Ambient = Color3.fromRGB(140, 130, 110),
		Brightness = 2.5,
		ColorShift_Bottom = Color3.fromRGB(255, 240, 180),
		ColorShift_Top = Color3.fromRGB(180, 200, 255),
		OutdoorAmbient = Color3.fromRGB(200, 170, 130),
		description = "Warm afternoon"
	},
	
	SUNSET = {
		ClockTime = 18.5,
		Ambient = Color3.fromRGB(100, 70, 50),
		Brightness = 1.8,
		ColorShift_Bottom = Color3.fromRGB(255, 120, 60),
		ColorShift_Top = Color3.fromRGB(255, 180, 100),
		OutdoorAmbient = Color3.fromRGB(180, 100, 60),
		description = "Orange sunset"
	},
	
	DUSK = {
		ClockTime = 19.5,
		Ambient = Color3.fromRGB(60, 50, 70),
		Brightness = 1.2,
		ColorShift_Bottom = Color3.fromRGB(120, 80, 100),
		ColorShift_Top = Color3.fromRGB(80, 60, 120),
		OutdoorAmbient = Color3.fromRGB(100, 70, 90),
		description = "Purple dusk"
	}
}

TimeConfig.UPDATE_INTERVAL = 2
TimeConfig.TRANSITION_DURATION = 1.5

TimeConfig.ENABLE_TIME_EVENTS = true

return TimeConfig
