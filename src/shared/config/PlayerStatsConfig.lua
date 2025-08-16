-- src/shared/config/PlayerStatsConfig.lua
-- Configuration for the Player Stats System (Health, Hunger, Thirst)
-- Centralized settings for stat decay rates, max values, and damage amounts

local PlayerStatsConfig = {

	MAX_HEALTH = 100,
	MAX_HUNGER = 100,
	MAX_THIRST = 100,
	STARTING_MONEY = 9999,

	TICK_INTERVAL = 1,

	-- Hunger lasts 6 minutes (360 seconds): 100 / 360 = ~0.278 per second
	HUNGER_DECAY_PER_TICK = 0.278,
	-- Thirst lasts 5 minutes (300 seconds): 100 / 300 = ~0.333 per second  
	THIRST_DECAY_PER_TICK = 0.333,

	STARVATION_DAMAGE_PER_TICK = 2,
	DEHYDRATION_DAMAGE_PER_TICK = 3,

	RESPAWN_COST_ROBUX = 39,
	RESPAWN_RESTORE_ALL_STATS = true,

	UI = {
		HUNGER_COLOR = Color3.fromRGB(255, 255, 0),
		THIRST_COLOR = Color3.fromRGB(0, 162, 255),

		BAR_WIDTH = 200,
		BAR_HEIGHT = 20,
		BAR_POSITION_LEFT_OFFSET = 20,
		BAR_SPACING = 10,

		UI_UPDATE_SMOOTHNESS = 0.2,
	},

	-- Debug settings
	DEBUG_MODE = true,
	SHOW_EXACT_VALUES = false,
}

return PlayerStatsConfig
