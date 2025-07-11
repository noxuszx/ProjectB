--[[
	ModelSpawnerConfig.lua
	Configuration for custom model spawning system
]]--

local ModelSpawnerConfig = {}

-- General spawning parameters
ModelSpawnerConfig.MIN_SPAWN_DISTANCE = 100 -- Minimum distance from spawn to place objects
ModelSpawnerConfig.MAX_SPAWN_DISTANCE = 500 -- Maximum distance from spawn to place objects

-- Spawn chances per chunk subdivision (0-1)
ModelSpawnerConfig.VEGETATION_CHANCE = 0.25 -- 25% chance per subdivision
ModelSpawnerConfig.ROCK_CHANCE = 0.15 -- 15% chance per subdivision
ModelSpawnerConfig.STRUCTURE_CHANCE = 0.01 -- 5% chance per subdivision

-- Minimum distances between objects (to prevent overcrowding)
ModelSpawnerConfig.MIN_VEGETATION_DISTANCE = 8 -- studs
ModelSpawnerConfig.MIN_ROCK_DISTANCE = 12 -- studs
ModelSpawnerConfig.MIN_STRUCTURE_DISTANCE = 30 -- studs

-- Size scaling for models (random variation)
ModelSpawnerConfig.VEGETATION_SCALE_RANGE = {0.8, 1.3} -- 80% to 130% of original size
ModelSpawnerConfig.ROCK_SCALE_RANGE = {0.7, 1.5} -- 70% to 150% of original size
ModelSpawnerConfig.STRUCTURE_SCALE_RANGE = {0.9, 1.1} -- 90% to 110% of original size

-- Rotation randomization
ModelSpawnerConfig.RANDOM_ROTATION = true -- Randomly rotate Y-axis

-- Model folder paths in ReplicatedStorage
ModelSpawnerConfig.MODEL_FOLDERS = {
	Vegetation = "Models.Vegetation",
	Rocks = "Models.Rocks",
	Structures = "Models.Structures"
}

-- Weight system for model selection (if you want some models to spawn more often)
-- This will be automatically populated by scanning the folders
ModelSpawnerConfig.MODEL_WEIGHTS = {
	-- Example:
	-- Vegetation = {
	--     ["DeadTree1"] = 10,
	--     ["Cactus1"] = 15,
	--     ["Shrub1"] = 20
	-- }
}

-- Performance settings
ModelSpawnerConfig.GENERATION_DELAY = 0.02 -- Delay between model spawns (seconds)
ModelSpawnerConfig.MAX_OBJECTS_PER_CHUNK = {
	Vegetation = 20,
	Rocks = 10,
	Structures = 2
}

return ModelSpawnerConfig
