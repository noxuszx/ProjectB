--[[
	CoreStructureConfig.lua
	Configuration for massive landmark structures (Pyramid, Towers)
	These spawn before all other systems to ensure proper avoidance
]]--

local CoreStructureConfig = {}

-- Structure definitions with collision radii and individual embed percentages
CoreStructureConfig.STRUCTURES = {
	Pyramid = { radius = 175, embedPercentage = 0.009 },  -- Largest structure, placed first
	Tower1  = { radius = 30, embedPercentage = 0.02 },
	Tower2  = { radius = 30, embedPercentage = 0.02 },
	Tower3  = { radius = 30, embedPercentage = 0.02 },
}

-- Placement rules
CoreStructureConfig.MIN_DISTANCE_BETWEEN = 350        -- Minimum distance between any two core structures
CoreStructureConfig.PLAYER_SPAWN_PROTECT_RADIUS = 50  -- Keep clear around world origin
CoreStructureConfig.MAX_PLACEMENT_ATTEMPTS = 40       -- Maximum attempts per structure

-- Performance settings
CoreStructureConfig.BATCH_SIZE = 1                     -- One massive structure per frame

CoreStructureConfig.CHUNK_MARGIN_FACTOR = 0.1

-- Model location
CoreStructureConfig.MODEL_FOLDER = "Models.Core"

return CoreStructureConfig