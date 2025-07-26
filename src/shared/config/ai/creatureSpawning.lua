-- src/shared/config/CreatureSpawnConfig.lua
-- Configuration for creature spawn points and spawn types
-- This file defines spawn point types and their creature tables, similar to ItemConfig spawn types

local CreatureSpawnConfig = {
	-- Global spawn point settings
	Settings = {
		SpawnTag = "CreatureSpawner",
		SpawnTypeAttribute = "CreatureType",
		DebugMode = false,
		ScatterRadius = 8,
		MaxScatterAttempts = 15,
		SpawnHeight = 2,

		-- Time-based spawning settings
		NightOnlyCreatures = {"Mummy", "Skeleton"},
	},

	SpawnTypes = {
		
		Safe = {
			MaxSpawns = 4, -- Maximum creatures per spawner
			MinSpawns = 2, -- Minimum creatures per spawner
			SpawnChance = 0.9, -- Chance this spawner will spawn creatures
			PossibleCreatures = {
				Lizard = 0.9, -- Desert lizards
				Rabbit = 0.8, -- Desert rabbits
			}
		},

		Dangerous = {
			MaxSpawns = 5,
			MinSpawns = 3,
			SpawnChance = 0.95,
			PossibleCreatures = {
				-- Only hostile desert creatures in dangerous areas
				Wolf = 0.7, -- Desert wolves/jackals (increased since no passive creatures)
				Mummy = 0.5, -- Desert mummies (night only)
				Skeleton = 0.6, -- Desert skeletons (night only)

			}
		},
	},

	-- Spawn validation settings
	Validation = {
		-- Ground detection
		RequireGroundContact = true, -- Creatures must spawn on solid ground
		GroundRaycastDistance = 20, -- How far to raycast down for ground
		
		-- Obstacle avoidance
		ObstacleCheckRadius = 3, -- Radius to check for obstacles around spawn point
		MinClearanceHeight = 6, -- Minimum clear height above spawn point
		
		-- Player proximity
		MinPlayerDistance = 25, -- Don't spawn too close to players
		MaxPlayerDistance = 200, -- Don't spawn too far from players
		
		-- Existing creature checks
		MinCreatureDistance = 10, -- Minimum distance between spawned creatures
		MaxCreaturesInArea = 8, -- Maximum creatures in 50 stud radius
	},

	-- Respawn settings
	Respawn = {
		EnableRespawning = true, -- Whether to respawn creatures after they die
		RespawnDelay = {180, 300}, -- Min/max respawn delay in seconds
		RespawnChance = 0.6, -- Chance to respawn after delay
		MaxRespawnsPerSpawner = 5, -- Maximum times a spawner can respawn creatures
		
		RequirePlayerNearby = true, -- Only respawn if players are in area
		PlayerProximityRange = 100, -- Range to check for players for respawning
	},

	Events = {
		-- Example: Night spawns more hostile creatures
		-- NightSpawnMultiplier = 1.5,
		-- DaySpawnMultiplier = 0.8,
		
		-- Seasonal spawning
		-- SeasonalSpawning = false,
		
		-- Player activity based spawning
		-- ActivityBasedSpawning = false,
	},
}

return CreatureSpawnConfig
