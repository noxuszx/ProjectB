-- src/shared/config/AIConfig.lua
-- Configuration file for the AI System
-- This file defines creature types, behaviors, performance settings, and spawn parameters


local AIConfig = {
	-- Global AI system settings
	Settings = {
		MaxCreatures = 200, 		-- Total maximum creatures in the world (hard limit)
		MaxProceduralCreatures = 130, -- Limit for natural world spawners (reserves 70 slots for events)
		UpdateBudgetMs = 5, 		-- Maximum milliseconds per frame for AI updates
		DebugMode = false, 			-- Enable debug prints and visualizations
		SpatialGridSize = 50, 		-- Size of spatial grid cells for optimization (studs)
		CreaturesFolder = "NPCs", 	-- Folder name in ReplicatedStorage where creature models are stored
	},

	-- Performance optimization settings
	Performance = {
		
		-- Distance-based Level of Detail (LOD) system
		-- Optimized rates after performance improvements (July 2025)
		LOD = {
			Close = {
				Distance = 50,
				UpdateRate = 30,
			},
			Medium = {
				Distance = 100,
				UpdateRate = 15,
			},
			Far = {
				Distance = 250,
				UpdateRate = 2,
			},
		},
		
		-- Parallel processing settings
		Parallel = {
			EnableParallelLOD = true,
			LODBatchSize = 25,
			MinCreaturesForParallel = 10,
		
		MaxCreaturesPerFrame = 25, 			-- Maximum creatures to update per frame (increased from 10)
		CreaturePoolSize = 50,		 		-- Number of creature instances to keep in memory pool
		
		EnableSpatialPartitioning = true,
		SpatialUpdateFrequency = 5,
		}
	},

	-- Creature type definitions
	CreatureTypes = {
		
		Camel = {
			Type = "Passive",
			Health = 100,
			MoveSpeed = 12,
			DetectionRange = 20,
			FleeSpeed = 13,
			FleeDuration = 10,
			RoamRadius = 15,
			IdleTime = {5, 15},
			ModelFolder = "PassiveCreatures",
		},

		Rabbit = {
			Type = "Passive",
			Health = 40,
			MoveSpeed = 12,
			DetectionRange = 20,
			FleeSpeed = 13,
			FleeDuration = 10,
			RoamRadius = 15,
			IdleTime = {5, 15},
			ModelFolder = "PassiveCreatures",
		},

		Villager1 = {
			Type = "Passive",
			Health = 100,
			MoveSpeed = 12,
			DetectionRange = 15,
			FleeSpeed = 18,
			FleeDuration = 8,
			RoamRadius = 30,
			IdleTime = {2, 3},
			ModelFolder = "PassiveCreatures",
			FleeOnProximity = false,
		},

		Villager2 = {
			Type = "Passive",
			Health = 100,
			MoveSpeed = 12,
			DetectionRange = 15,
			FleeSpeed = 16,
			FleeDuration = 5,
			RoamRadius = 30,
			IdleTime = {2, 3},
			ModelFolder = "PassiveCreatures",
			FleeOnProximity = false,
		},

		Villager3 = {
			Type = "Passive",
			Health = 100,
			MoveSpeed = 12,
			DetectionRange = 15,
			FleeSpeed = 18,
			FleeDuration = 8,
			RoamRadius = 30,
			IdleTime = {2, 3},
			ModelFolder = "PassiveCreatures",
			FleeOnProximity = false,
		},

		Villager4 = {
			Type = "Passive",
			Health = 100,
			MoveSpeed = 12,
			DetectionRange = 15,
			FleeSpeed = 16,
			FleeDuration = 5,
			RoamRadius = 30,
			IdleTime = {2, 3},
			ModelFolder = "PassiveCreatures",
			FleeOnProximity = false,
		},

		-- Hostile Creatures
		Coyote = {
			Type = "Hostile",
			Health = 100,
			MoveSpeed = 16,
			DetectionRange = 40,
			TouchDamage = 0,
			ChaseSpeed = 16,
			RoamRadius = 25,
			IdleTime = {5, 12},
			ModelFolder = "HostileCreatures",
			
			DamageCooldown = 1.5, 
		},

		Scorpion = {
			Type = "Hostile",
			Health = 200,
			MoveSpeed = 16,
			DetectionRange = 40,
			TouchDamage = 10,
			ChaseSpeed = 16,
			RoamRadius = 25,
			IdleTime = {5, 12},
			ModelFolder = "HostileCreatures",
			
			DamageCooldown = 1.5, 
		},
		
		
		Skeleton = {
			Type = "Hostile",
			Health = 120,
			MoveSpeed = 20,
			DetectionRange = 45,
			TouchDamage = 12,
			ChaseSpeed = 26,
			RoamRadius = 20,
			IdleTime = {3, 8},
			ModelFolder = "HostileCreatures",
			DamageCooldown = 1.0,
		},
		
		Mummy = {
			Type = "Hostile",
			Health = 150,
			MoveSpeed = 15,
			DetectionRange = 30,
			TouchDamage = 5,
			ChaseSpeed = 18,
			RoamRadius = 18,
			IdleTime = {6, 15},
			ModelFolder = "HostileCreatures",
			DamageCooldown = 1.8,
		},
		
		SkeletonArcher = {
			Type = "RangedHostile",
			Health = 100,
			MoveSpeed = 14,
			DetectionRange = 70,
			TouchDamage = 0,
			ChaseSpeed = 14,
			RoamRadius = 20,
			IdleTime = {4, 10},
			ModelFolder = "HostileCreatures",
			
			-- Ranged config
			ProjectileSpeed = 50,
			OptimalRange = 30,
			MaxRange = 120,
			WeaponName = "SkeletonArrow",
			AnimationId = "rbxassetid://123898471268427",
			
			-- Burst shooting config
			ShotsPerBurst = 3,			-- Number of shots in each burst
			ShotInterval = 1.0,			-- Time between shots within a burst (seconds)
			BurstCooldown = 3.0,		-- Cooldown after completing a burst (seconds)
			KitingDelay = 3.0,			-- Delay before creature starts kiting when player gets close
		},

		-- Tower-specific creatures (separate models)
		TowerSkeleton = {
			Type = "Hostile",
			Health = 100,
			MoveSpeed = 22,
			DetectionRange = 45,
			TouchDamage = 10,
			ChaseSpeed = 28,
			RoamRadius = 20,
			IdleTime = {3, 8},
			ModelFolder = "HostileCreatures",
			DamageCooldown = 1.0,
		},

		TowerMummy = {
			Type = "Hostile",
			Health = 200,
			MoveSpeed = 18,
			DetectionRange = 30,
			TouchDamage = 25,
			ChaseSpeed = 22,
			RoamRadius = 18,
			IdleTime = {6, 15},
			ModelFolder = "HostileCreatures",
			DamageCooldown = 1.5,
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
		
		SpawnHeight = 1,
		MaxSpawnAttempts = 10,
		
		CreatureWeights = {

			-- Passive creatures (more common)
			Rabbit = 2,
			Villager1 = 3,
			Villager2 = 3,

			-- Hostile creatures (less common)
			Wolf = 8,
			Skeleton = 6,
			Mummy = 5,
			SkeletonArcher = 6,
		},
	},

	-- Behavior system settings (simplified)
	BehaviorSettings = {

		-- Most complex settings removed for simplicity and performance
		-- Humanoid:MoveTo handles pathfinding, obstacle avoidance, and stuck detection


		ReturnToSpawnThreshold = 50,
		ReturnSpeed = 1.2,
	},

	TowerSpawning = {
		Settings = {
			DeactivationDelay = 30, 		-- Seconds before deactivating empty floors
			MaxTowerCreatures = 50, 		-- Per-tower creature limit
			ForceDeactivationTime = 120, 	-- Force deactivation if zone empty this long (safety)
			IndoorLODBias = 1.5,    		-- Multiplier for indoor LOD rates (less aggressive throttling)
			ZoneDebounceTime = 0.2, 		-- Debounce zone callbacks to avoid rapid re-entries
		},
		
		Towers = {
			Tower_A = {
				MaxCreatures = 25,
				CreatureTypes = {"TowerSkeleton", "TowerMummy", "Scorpion"}
			},
			Tower_B = {
				MaxCreatures = 30,
				CreatureTypes = {"TowerMummy", "TowerSkeleton", "Scorpion"}
			}
		}
	},

	-- Debugging and visualization settings
	Debug = {
		ShowDetectionRanges = false, 		-- Visualize detection ranges
		ShowWaypoints = false, 		 		-- Show creature waypoints
		ShowStateLabels = false, 	 		-- Show current behavior state above creatures
		ShowPerformanceStats = false,		-- Display performance statistics
		LogBehaviorChanges = false,	 		-- Print behavior state changes (DISABLED to reduce spam)
		LogSpawning = false, 		 		-- Print creature spawning events
		LogStuckDetection = false,   		-- Print stuck detection events (separate from behavior changes)
	},
}

return AIConfig
