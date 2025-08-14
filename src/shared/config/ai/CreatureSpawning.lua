-- src/shared/config/CreatureSpawnConfig.lua
-- Configuration for creature spawn points and spawn types

local CreatureSpawnConfig = {
	Settings = {
		SpawnTag = "CreatureSpawner",
		SpawnTypeAttribute = "CreatureType",
		DebugMode = false,
		ScatterRadius = 8,
		MaxScatterAttempts = 15,
		SpawnHeight = 2,
	},

	SpawnTypes = {
		Safe = {
			MaxSpawns = 3,
			MinSpawns = 1,
			SpawnChance = 1,
			PossibleCreatures = {
				Rabbit = 0.7,
				Camel = 0.2
			}
		},

		Dangerous = {
			MaxSpawns = 2,
			MinSpawns = 1,
			SpawnChance = 1,
			-- Weights (relative). Higher value = more likely per roll.
			PossibleCreatures = {
				Coyote = 4,
				Scorpion = 5,
				SkeletonArcher = 4,
			}
		},

		Village = {
			MaxSpawns = 2,
			MinSpawns = 1,
			SpawnChance = 0.8,
			PossibleCreatures = {
				Villager1 = 0.5,
				Villager2 = 0.5,
				Villager3 = 0.5,
				Villager4 = 0.5,
			}
		},
	},

	Validation = {
		-- Ground detection
		RequireGroundContact  = true,	-- Creatures must spawn on solid ground
		GroundRaycastDistance = 20, 	-- How far to raycast down for ground
		
		-- Obstacle avoidance
		ObstacleCheckRadius = 3, 		-- Radius to check for obstacles around spawn point
		MinClearanceHeight  = 6, 		-- Minimum clear height above spawn point
		
		-- Player proximity
		MinPlayerDistance 	= 25, 		-- Don't spawn too close to players
		MaxPlayerDistance 	= 200, 		-- Don't spawn too far from players
		
		-- Existing creature checks
		MinCreatureDistance = 10, 		-- Minimum distance between spawned creatures
		MaxCreaturesInArea 	= 8, 		-- Maximum creatures in 50 stud radius
	},

	Respawn = {
		EnableRespawning = true,
		RespawnDelay = {180, 300},
		RespawnChance = 0.6,
		MaxRespawnsPerSpawner = 5,
		
		RequirePlayerNearby = true,
		PlayerProximityRange = 100,
	},
}

return CreatureSpawnConfig



