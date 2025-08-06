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
			MaxSpawns = 3,		-- Reduced from 4
			MinSpawns = 1, 		-- Reduced from 2
			SpawnChance = 1, 	-- Reduced from 0.9
			PossibleCreatures = {
				Rabbit = 0.7,
				Camel = 0.2
			}
		},

		Dangerous = {
			MaxSpawns = 2, 		-- Reduced from 5
			MinSpawns = 1, 		-- Reduced from 3
			SpawnChance = 0.9, 	-- Reduced from 0.95
			PossibleCreatures = {
				Coyote = 0.8,
				Mummy = 0.5,
				Scorpion = 0.8,
				SkeletonArcher = 0.3, -- Lower chance for ranged enemies
			}
		},

		Village = {
			MaxSpawns = 2,		-- 1-3 villagers per spawner
			MinSpawns = 1,
			SpawnChance = 0.8,	-- High chance for consistent village population
			PossibleCreatures = {
				Villager1 = 0.5,	-- 50% chance for first villager type
				Villager2 = 0.5,
				Villager3 = 0.5,
				Villager4 = 0.5,	-- 50% chance for second villager type
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



