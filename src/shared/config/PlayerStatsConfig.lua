-- src/shared/config/PlayerStatsConfig.lua
-- Configuration for the Player Stats System (Health, Hunger, Thirst)
-- Centralized settings for stat decay rates, max values, and damage amounts

local PlayerStatsConfig = {
	-- Maximum stat values (starting values for new players)
	MAX_HEALTH = 100,
	MAX_HUNGER = 100,
	MAX_THIRST = 100,
	
	-- Stat decay system settings
	TICK_INTERVAL = 5, -- Seconds between each decay tick
	
	-- Decay rates per tick (how much stats decrease each interval)
	HUNGER_DECAY_PER_TICK = 0.5, -- Hunger decreases by 0.5 every 5 seconds
	THIRST_DECAY_PER_TICK = 1.0, -- Thirst decreases by 1.0 every 5 seconds (faster than hunger)
	
	-- Damage dealt when stats reach 0
	STARVATION_DAMAGE_PER_TICK = 2, -- Health damage when Hunger = 0
	DEHYDRATION_DAMAGE_PER_TICK = 3, -- Health damage when Thirst = 0 (more dangerous)
	
	-- Respawn system
	RESPAWN_COST_ROBUX = 39, -- Cost to respawn (developer product)
	RESPAWN_RESTORE_ALL_STATS = true, -- Whether respawn restores all stats to max
	
	-- UI Settings (for client reference)
	UI = {
		-- Bar colors
		HUNGER_COLOR = Color3.fromRGB(255, 255, 0), -- Yellow
		THIRST_COLOR = Color3.fromRGB(0, 162, 255), -- Blue
		
		-- Bar dimensions
		BAR_WIDTH = 200,
		BAR_HEIGHT = 20,
		BAR_POSITION_LEFT_OFFSET = 20, -- Pixels from left edge of screen
		BAR_SPACING = 10, -- Vertical spacing between bars
		
		-- Update frequency
		UI_UPDATE_SMOOTHNESS = 0.2, -- TweenInfo duration for smooth bar changes
	},
	
	-- Debug settings
	DEBUG_MODE = false, -- Enable console logging for stat changes
	SHOW_EXACT_VALUES = false, -- Show precise decimal values in debug (vs rounded)
}

return PlayerStatsConfig