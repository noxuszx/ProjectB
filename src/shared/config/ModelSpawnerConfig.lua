--[[
	ModelSpawnerConfig.lua
	Configuration for custom model spawning system
]]--

local ModelSpawnerConfig = {}

ModelSpawnerConfig.MIN_SPAWN_DISTANCE = 30 		-- Minimum distance from spawn to place objects  
ModelSpawnerConfig.MAX_SPAWN_DISTANCE = 1200 		-- Maximum distance from spawn to place objects (covers full world)

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

ModelSpawnerConfig.MODEL_WEIGHTS = {
	-- Example:
	-- Vegetation = {
	--     ["DeadTree1"] = 10,
	--     ["Cactus1"] = 15,
	--     ["Shrub1"] = 20
	-- }
}

ModelSpawnerConfig.MAX_OBJECTS_PER_CHUNK = {
	Vegetation = 20,
	Rocks = 10,
	Structures = 2
}

-- NEW: Frame budgeting - objects to spawn per frame by category
ModelSpawnerConfig.PER_FRAME = {
	Vegetation = 10,
	Rocks = 5,
	Structures = 1
}

return ModelSpawnerConfig
