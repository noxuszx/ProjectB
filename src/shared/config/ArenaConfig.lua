-- src/shared/config/ArenaConfig.lua
-- Central configuration for the Pyramid Arena finale

local ArenaConfig = {}

-- Feature flag
ArenaConfig.Enabled = true

-- Duration and phase timings (in seconds)
ArenaConfig.DurationSeconds = 120
ArenaConfig.PhaseTimes = {
	Reinforcement = 60,
	Elites = 30,
}

-- Delay between individual spawns (seconds) per phase
ArenaConfig.SpawnStaggerSeconds = {
	Phase1 = 0.20,
	Phase2 = 0.25,
	Phase3 = 0.30,
}

-- Enemy aggro overrides for arena-only spawns
ArenaConfig.Aggro = {
	DetectionRange = 150,
	ChaseRange = 200,
	AttackRange = 3,
}

-- Wave composition with arena-specific creatures
ArenaConfig.Waves = {
	Phase1 = {
		WideSpawner1 = { {Type = "EgyptianSkeleton", Count = 5} },
		WideSpawner2 = { {Type = "EgyptianSkeleton", Count = 5} },
	},
	Phase2 = {
		WideSpawner1 = { {Type = "EgyptianSkeleton2", Count = 5} },
		WideSpawner2 = { {Type = "EgyptianSkeleton2", Count = 5} },
	},
	Phase3 = {
		ScorpionSpawner1 = { {Type = "Scorpion", Count = 1} },
		ScorpionSpawner2 = { {Type = "Scorpion", Count = 1} },
		ScorpionSpawner3 = { {Type = "Scorpion", Count = 1} },
		ScorpionSpawner4 = { {Type = "Scorpion", Count = 1} },
		ScorpionSpawner5 = { {Type = "Scorpion", Count = 1} },
	},
}

-- Arena AI configuration
ArenaConfig.AI = {
	MaxCreaturesPerPlayer = 5, 			-- Prevent overwhelming single players
	TargetRedistributionInterval = 2.0, -- Seconds between redistributing targets
	PathfindingUpdateRate = 0.5, 		-- How often to update pathfinding
	EnableSmartTargeting = true, 		-- Distribute enemies across players
}

ArenaConfig.Paths = {
	SpawnFolder = nil,
	TeleportMarkersFolder = nil,
	TreasureDoor = nil,
}

ArenaConfig.TeleportPositions = {
	Vector3.new(-5, 40, 135),
	Vector3.new(5, 40, 135),
	Vector3.new(0, 40, 140),
	Vector3.new(-3, 40, 130),
	Vector3.new(3, 40, 130),
}

ArenaConfig.Remotes = {
	Folder 	   = "Arena",
	StartTimer = "StartTimer",
	Pause 	   = "Pause",
	Resume 	   = "Resume",
	Sync 	   = "Sync",
	Victory    = "Victory",
	PostGameChoice = "PostGameChoice",
}

-- UI strings
ArenaConfig.UI     = {
	VictoryMessage = "VICTORY! You survived the Pharaoh's Curse!",
	ChoiceContinue = "Continue",
	ChoiceLobby    = "Back to Lobby",
}

return ArenaConfig

