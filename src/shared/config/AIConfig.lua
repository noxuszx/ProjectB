-- src/shared/config/AIConfig.lua
-- Configuration file for the AI System
-- This file defines creature types, behaviors, performance settings, and spawn parameters

local AIConfig = {
	-- Global AI system settings
	Settings = {
		MaxCreatures = 300, -- Maximum number of creatures in the world
		UpdateBudgetMs = 5, -- Maximum milliseconds per frame for AI updates
		DebugMode = false, -- Enable debug prints and visualizations
		SpatialGridSize = 50, -- Size of spatial grid cells for optimization (studs)
		CreaturesFolder = "NPCs", -- Folder name in ReplicatedStorage where creature models are stored
	},

	-- Performance optimization settings
	Performance = {
		-- Distance-based Level of Detail (LOD) system
		LOD = {
			Close = {
				Distance = 50, -- 0-50 studs
				UpdateRate = 30, -- Updates per second
			},
			Medium = {
				Distance = 100, -- 50-100 studs  
				UpdateRate = 10, -- Updates per second
			},
			Far = {
				Distance = 200, -- 100-200 studs
				UpdateRate = 2, -- Updates per second
			},
			-- Beyond 200 studs: creatures are paused/culled
		},
		
		-- Batch processing settings
		MaxCreaturesPerFrame = 10, -- Maximum creatures to update per frame
		CreaturePoolSize = 50, -- Number of creature instances to keep in memory pool
		
		-- Spatial optimization
		EnableSpatialPartitioning = true,
		SpatialUpdateFrequency = 5, -- How often to update spatial grid (seconds)
	},

	-- Creature type definitions
	CreatureTypes = {
		-- Passive Creatures
		Rabbit = {
			Type = "Passive",
			Health = 25,
			MoveSpeed = 16, -- Studs per second
			DetectionRange = 20, -- Range to detect players/threats (studs)
			FleeSpeed = 24, -- Speed when fleeing (studs per second)
			FleeDuration = 10, -- How long to flee after taking damage (seconds)
			RoamRadius = 15, -- How far from spawn point to roam (studs)
			IdleTime = {5, 15}, -- Min/max time to stay idle (seconds)
			ModelFolder = "PassiveCreatures", -- Subfolder in Models.Creatures
		},
		
		Deer = {
			Type = "Passive",
			Health = 40,
			MoveSpeed = 18,
			DetectionRange = 25,
			FleeSpeed = 28,
			FleeDuration = 12,
			RoamRadius = 20,
			IdleTime = {8, 20},
			ModelFolder = "PassiveCreatures",
		},
		
		Bird = {
			Type = "Passive",
			Health = 15,
			MoveSpeed = 12,
			DetectionRange = 30, -- Birds are more alert
			FleeSpeed = 20,
			FleeDuration = 8,
			RoamRadius = 25,
			IdleTime = {3, 10},
			ModelFolder = "PassiveCreatures",
		},
		
		Sheep = {
			Type = "Passive",
			Health = 35,
			MoveSpeed = 14,
			DetectionRange = 18,
			FleeSpeed = 22,
			FleeDuration = 15,
			RoamRadius = 12,
			IdleTime = {10, 25}, -- Sheep are lazier
			ModelFolder = "PassiveCreatures",
		},

		-- Hostile Creatures
		Wolf = {
			Type = "Hostile",
			Health = 100,
			MoveSpeed = 18,
			DetectionRange = 40, -- Range to detect players (studs)
			TouchDamage = 15, -- Damage dealt on contact with player
			ChaseSpeed = 22, -- Speed when chasing players
			RoamRadius = 25,
			IdleTime = {5, 12},
			ModelFolder = "HostileCreatures",
			-- Touch damage settings
			DamageCooldown = 1.5, -- Seconds between damage instances to same player
		},
		
		Bear = {
			Type = "Hostile", 
			Health = 200,
			MoveSpeed = 16, -- Slower but tankier
			DetectionRange = 35,
			TouchDamage = 25, -- Higher damage
			ChaseSpeed = 20,
			RoamRadius = 30,
			IdleTime = {8, 18},
			ModelFolder = "HostileCreatures",
			DamageCooldown = 2.0,
		},
		
		Goblin = {
			Type = "Hostile",
			Health = 60,
			MoveSpeed = 20,
			DetectionRange = 45,
			TouchDamage = 12,
			ChaseSpeed = 26,
			RoamRadius = 20,
			IdleTime = {3, 8},
			ModelFolder = "HostileCreatures",
			DamageCooldown = 1.0,
		},
		
		Orc = {
			Type = "Hostile",
			Health = 150,
			MoveSpeed = 15,
			DetectionRange = 30,
			TouchDamage = 20,
			ChaseSpeed = 18,
			RoamRadius = 18,
			IdleTime = {6, 15},
			ModelFolder = "HostileCreatures",
			DamageCooldown = 1.8,
		},
	},

	-- Spawning system settings
	SpawnSettings = {

		-- General spawn parameters
		CreaturesPerChunk = {2, 5}, 	-- Min/max creatures per chunk
		SpawnChance = 0.7, 				-- Chance for a chunk to have creatures
		MinDistanceFromPlayer = 30, 	-- Minimum distance from players when spawning (studs)
		MaxDistanceFromPlayer = 150, 	-- Maximum distance from players when spawning (studs)
		RespawnDelay = 300, 			-- Time before respawning creatures in empty areas (seconds)
		
		SpawnHeight = 3,
		MaxSpawnAttempts = 10,
		
		-- Creature distribution weights (higher = more common)
		CreatureWeights = {
			-- Passive creatures (more common)
			Rabbit = 25,
			Deer = 15,
			Bird = 20,
			Sheep = 18,
			
			-- Hostile creatures (less common)
			Wolf = 8,
			Bear = 3,
			Goblin = 6,
			Orc = 5,
		},
		
		BiomeSpawning = {
			-- Example: Different creatures spawn in different areas
			-- Forest = {"Rabbit", "Deer", "Wolf"},
			-- Plains = {"Sheep", "Rabbit"},
			-- Mountains = {"Bear", "Goblin"}
		},
	},

	-- Behavior system settings
	BehaviorSettings = {

		StateTransitionDelay = 0.5, -- Minimum time between state changes (seconds)
		
		WaypointDistance = 8, -- Distance between waypoints when roaming (studs)
		ObstacleAvoidanceRange = 5, -- Range to detect obstacles (studs)
		StuckThreshold = 2, -- Time before considering creature stuck (seconds)
		
		-- Detection settings
		LineOfSightEnabled = true, -- Whether to use raycast line-of-sight checks
		DetectionUpdateRate = 5, -- How often to check for players (per second)
		
		-- Return behavior settings
		ReturnToSpawnThreshold = 50, -- Distance from spawn before returning (studs)
		ReturnSpeed = 1.2, -- Speed multiplier when returning to spawn
	},

	-- Debugging and visualization settings
	Debug = {
		ShowDetectionRanges = false, -- Visualize detection ranges
		ShowWaypoints = false, -- Show creature waypoints
		ShowStateLabels = false, -- Show current behavior state above creatures
		ShowPerformanceStats = false, -- Display performance statistics
		LogBehaviorChanges = false, -- Print behavior state changes
		LogSpawning = false, -- Print creature spawning events
	},
}

return AIConfig
