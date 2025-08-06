--[[
	FrameBudgetConfig.lua
	Central configuration for frame-budgeted world bootstrap
	Defines per-frame processing limits for smooth initialization
]]--

local FrameBudgetConfig = {}

-- Default batch sizes for different systems
FrameBudgetConfig.DEFAULT_BATCH_SIZES = {
	-- Village spawning - structures per frame
	VILLAGES = 2,
	
	-- Model spawning - objects per frame by category (consolidated from ModelSpawnerConfig)
	VEGETATION = 10,
	ROCKS = 5,
	STRUCTURES = 1,
	
	-- Spawner placement - chunks per frame
	SPAWNER_CHUNKS = 10,
	
	-- Creature spawning - creatures per frame
	CREATURES = 3,
	
	-- Chunk processing - chunks per frame for model spawner
	CHUNK_PROCESSING = 5,
	
	-- General fallback
	DEFAULT = 5
}

-- Mobile device multipliers (applied to reduce batch sizes on low-end devices)
FrameBudgetConfig.MOBILE_MULTIPLIERS = {
	VILLAGES = 0.5,      -- 1 structure per frame on mobile
	VEGETATION = 0.5,    -- 5 vegetation per frame on mobile
	ROCKS = 0.6,         -- 3 rocks per frame on mobile
	STRUCTURES = 1.0,    -- Keep 1 structure per frame (already minimal)
	SPAWNER_CHUNKS = 0.5, -- 5 chunks per frame on mobile
	CREATURES = 0.7,     -- 2 creatures per frame on mobile
	CHUNK_PROCESSING = 0.6, -- 3 chunks per frame on mobile for model spawning
	DEFAULT = 0.6
}

-- Performance monitoring settings
FrameBudgetConfig.MONITORING = {
	ENABLED = false,  -- Set to true for development/debugging
	LOG_INTERVAL = 5, -- Seconds between performance logs
	TARGET_FPS = 55,  -- Target server FPS
	WARNING_FPS = 45  -- Log warnings below this FPS
}

-- Get appropriate batch size for current device
function FrameBudgetConfig.getBatchSize(category)
	local UserInputService = game:GetService("UserInputService")
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	
	local baseSize = FrameBudgetConfig.DEFAULT_BATCH_SIZES[category] or FrameBudgetConfig.DEFAULT_BATCH_SIZES.DEFAULT
	
	if isMobile then
		local multiplier = FrameBudgetConfig.MOBILE_MULTIPLIERS[category] or FrameBudgetConfig.MOBILE_MULTIPLIERS.DEFAULT
		return math.max(1, math.floor(baseSize * multiplier))
	else
		return baseSize
	end
end

-- Get batch sizes for model spawning categories
function FrameBudgetConfig.getModelBatchSizes()
	return {
		Vegetation = FrameBudgetConfig.getBatchSize("VEGETATION"),
		Rocks = FrameBudgetConfig.getBatchSize("ROCKS"),
		Structures = FrameBudgetConfig.getBatchSize("STRUCTURES")
	}
end

return FrameBudgetConfig