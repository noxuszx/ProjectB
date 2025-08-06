-- src/shared/config/SpawnerPlacementConfig.lua
-- Configuration file for the Procedural Spawner Placement System
-- This file defines all tunable parameters for intelligent spawner placement

local SpawnerPlacementConfig = {

	Settings = {
		SpawnerChunkChance = 0.8, -- Increased from 0.6 for more spawners
		MaxPlacementAttempts = 10,
		SpawnerHeight = 2,
		DebugMode = false,

		UseNoiseBasedSpawning = false, -- Simplified random spawning for better gameplay balance
	},

	TerrainValidation = {
		ClearanceRadius = 7, -- Reduced from 10 for denser spawner placement
		RaycastDistance = 50,
	},

	-- Noise-based biome settings removed for simplified random spawning approach

	RandomSpawning = {
		-- Designer-controlled spawn type ratios for balanced gameplay
		SpawnTypeProbabilities = {
			Safe = 0.60,      -- 60% safe areas (passive creatures)
			Dangerous = 0.40, -- 40% dangerous areas (hostile creatures)
		},

		RandomSeed = 12345,
	},

	Performance = {
		BatchSize = 10,
		ProcessingDelay = 0.01,
		MaxSpawnersPerChunk = 5, -- Increased from 3 for denser spawning
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
