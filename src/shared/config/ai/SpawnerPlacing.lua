-- src/shared/config/SpawnerPlacementConfig.lua
-- Configuration file for the Procedural Spawner Placement System
-- This file defines all tunable parameters for intelligent spawner placement

local SpawnerPlacementConfig = {

	Settings = {
		SpawnerChunkChance = 0.6,
		MaxPlacementAttempts = 10,
		SpawnerHeight = 2,
		DebugMode = false,

		UseNoiseBasedSpawning = true, -- false for random
	},

	TerrainValidation = {
		ClearanceRadius = 10,
		RaycastDistance = 50,
	},

	NoiseSettings = {

		Temperature = {
			Seed = 1234,
			Scale = 0.05,
			Octaves = 3,
		},
		
		Humidity = {
			Seed = 5678,
			Scale = 0.08,
			Octaves = 4,
		},
		
		Hostility = {
			Seed = 9012,
			Scale = 0.1,
			Octaves = 2,
		},
	},

	BiomeThresholds = {

		HighTemperature = 0.6,
		LowTemperature = 0.3,
		HighHumidity = 0.6,
		LowHumidity = 0.3,
		HighHostility = 0.7,
		
		ModerateTemperature = 0.5,
		ModerateHumidity = 0.4,
	},

	SpawnAreaRules = {
		
		{
			condition = function(temp, humid, hostile)
				return hostile > 0.75 -- Higher threshold for better Safe/Dangerous balance
			end,
			spawnType = "Dangerous",
			description = "Dangerous desert areas - hostile creatures dominate"
		},
		{
			condition = function(temp, humid, hostile)
				return true
			end,
			spawnType = "Safe",
			description = "Safe desert areas - mostly passive creatures"
		},
	},

	RandomSpawning = {
		SpawnTypeProbabilities = {
			Safe = 0.7,
			Dangerous = 0.3,
		},

		RandomSeed = 12345,
	},

	Performance = {
		BatchSize = 10,
		ProcessingDelay = 0.01,
		MaxSpawnersPerChunk = 1,
		EnableSpatialCaching = true,
		
		-- NEW: Frame budgeting - chunks to process per frame
		PerFrame = 10,
	},

	Debug = {
		ShowSpawnerParts = true,
		ShowBiomeLabels = false,
		LogPlacementDetails = false,
		CreateBiomeMap = false,
		
		AreaColors = {
			Safe = Color3.new(0, 0.8, 0),
			Dangerous = Color3.new(0.8, 0, 0),
		},
	},

	AvoidanceRules = {
		VillageDistance = 10,
		PlayerSpawnDistance = 5,
	},
}

return SpawnerPlacementConfig
