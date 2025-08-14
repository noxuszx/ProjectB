-- src/shared/config/SpawnerPlacementConfig.lua
-- Configuration file for the Procedural Spawner Placement System

local SpawnerPlacementConfig = {

	Settings = {
		SpawnerChunkChance = 0.8,
		MaxPlacementAttempts = 10,
		SpawnerHeight = 2,
		DebugMode = false,

		UseNoiseBasedSpawning = false,
	},

	TerrainValidation = {
		ClearanceRadius = 7,
		RaycastDistance = 50,
	},

	RandomSpawning = {
		SpawnTypeProbabilities = {
			Safe = 0.60,      -- 60% safe areas (passive creatures)
			Dangerous = 0.40, -- 40% dangerous areas (hostile creatures)
		},

		RandomSeed = 12345,
	},

	Performance = {
		BatchSize = 10,
		ProcessingDelay = 0.01,
		MaxSpawnersPerChunk = 5,
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
