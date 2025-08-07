--[[
	CoreStructureConfig.lua
	Configuration for massive landmark structures (Pyramid, Towers)
	These spawn before all other systems to ensure proper avoidance
]]--

local CoreStructureConfig = {}

CoreStructureConfig.STRUCTURES = {
	Pyramid = { radius = 175, embedPercentage = 0.009 },
	Tower_A  = { radius = 30, embedPercentage = 0.02 },
	Tower_B  = { radius = 30, embedPercentage = 0.02 },
	Tower_C  = { radius = 30, embedPercentage = 0.02 },
}

-- Placement rules
CoreStructureConfig.MIN_DISTANCE_BETWEEN = 350
CoreStructureConfig.PLAYER_SPAWN_PROTECT_RADIUS = 50
CoreStructureConfig.MAX_PLACEMENT_ATTEMPTS = 40

CoreStructureConfig.BATCH_SIZE = 1
CoreStructureConfig.CHUNK_MARGIN_FACTOR = 0.1
CoreStructureConfig.MODEL_FOLDER = "Models.Core"

return CoreStructureConfig