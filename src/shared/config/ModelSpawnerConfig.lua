--[[
	ModelSpawnerConfig.lua
	Configuration for custom model spawning system
]]--

local ModelSpawnerConfig = {}

ModelSpawnerConfig.MIN_SPAWN_DISTANCE = 30 		-- Minimum distance from spawn to place objects  
ModelSpawnerConfig.MAX_SPAWN_DISTANCE = 1200 		-- Maximum distance from spawn to place objects (covers full world)

-- Spawn protection zone (around 0,0,0)
ModelSpawnerConfig.SPAWN_PROTECTION_RADIUS = 50 	-- No objects within this radius of spawn
ModelSpawnerConfig.SPAWN_PROTECTION_HEIGHT = 100 	-- Height of protection cylinder

ModelSpawnerConfig.VEGETATION_CHANCE = 0.25
ModelSpawnerConfig.ROCK_CHANCE = 0.15
ModelSpawnerConfig.STRUCTURE_CHANCE = 0.01

ModelSpawnerConfig.MIN_VEGETATION_DISTANCE = 8
ModelSpawnerConfig.MIN_ROCK_DISTANCE = 12
ModelSpawnerConfig.MIN_STRUCTURE_DISTANCE = 30

ModelSpawnerConfig.VEGETATION_SCALE_RANGE = {0.8, 1.3}
ModelSpawnerConfig.ROCK_SCALE_RANGE = {0.7, 3.5}
ModelSpawnerConfig.STRUCTURE_SCALE_RANGE = {0.9, 1.1}

ModelSpawnerConfig.RANDOM_ROTATION = true

ModelSpawnerConfig.MODEL_FOLDERS = {
	Vegetation = "Models.Vegetation",
	Rocks = "Models.Rocks",
	Structures = "Models.Structures"
}

-- Weighted random selection for models (higher weight = more likely to spawn)
ModelSpawnerConfig.MODEL_WEIGHTS = {
	Vegetation = {
		-- Example weights - adjust based on your actual model names
		-- ["DeadTree1"] = 10,
		-- ["Cactus1"] = 15,
		-- ["Shrub1"] = 20,
		-- ["Grass1"] = 30,
		-- ["Rock1"] = 5
	},
	Rocks = {
		-- Example weights
		-- ["BigRock"] = 5,
		-- ["SmallRock"] = 15,
		-- ["Boulder"] = 3
	},
	Structures = {
		-- Example weights  
		-- ["Ruins1"] = 8,
		-- ["Obelisk"] = 2,
		-- ["Pillar"] = 12
	}
}

ModelSpawnerConfig.MAX_OBJECTS_PER_CHUNK = {
	Vegetation = 20,
	Rocks = 10,
	Structures = 2
}

-- Debug settings
ModelSpawnerConfig.DEBUG = false -- Set to true for detailed collision and spawning logs

-- NOTE: Frame budgeting moved to FrameBudgetConfig.lua for centralized configuration

return ModelSpawnerConfig
