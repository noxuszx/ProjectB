-- src/shared/config/ArenaConfig.lua
-- Central configuration for the Pyramid Arena finale

local ArenaConfig = {}

-- Feature flag
ArenaConfig.Enabled = true

-- Duration and phase timings (in seconds)
ArenaConfig.DurationSeconds = 120
ArenaConfig.PhaseTimes = {
	Reinforcement = 60, -- when 60 seconds remain
	Elites = 30,        -- when 30 seconds remain
}

-- Delay between individual spawns (seconds) per phase
ArenaConfig.SpawnStaggerSeconds = {
	Phase1 = 0.20,  -- 200ms between each spawned enemy
	Phase2 = 0.25,
	Phase3 = 0.30,
}

-- Enemy aggro overrides for arena-only spawns
ArenaConfig.Aggro = {
	DetectionRange = 150, -- Large detection range for instant engagement
	ChaseRange = 200, -- Extended chase range to prevent losing targets
	AttackRange = 5, -- Melee attack range
}

-- Wave composition with arena-specific creatures
ArenaConfig.Waves = {
	Phase1 = {
		-- Initial wave: balanced count for performance
		WideSpawner1 = { {Type = "EgyptianSkeleton", Count = 5} },
		WideSpawner2 = { {Type = "EgyptianSkeleton", Count = 5} },
	},
	Phase2 = {
		-- Reinforcement wave: stronger skeletons (total: 10 creatures)
		WideSpawner1 = { {Type = "EgyptianSkeleton2", Count = 5} },
		WideSpawner2 = { {Type = "EgyptianSkeleton2", Count = 5} },
	},
	Phase3 = {
		-- Elite wave: scorpions spread across arena (total: 5 creatures)
		ScorpionSpawner1 = { {Type = "Scorpion", Count = 1} },
		ScorpionSpawner2 = { {Type = "Scorpion", Count = 1} },
		ScorpionSpawner3 = { {Type = "Scorpion", Count = 1} },
		ScorpionSpawner4 = { {Type = "Scorpion", Count = 1} },
		ScorpionSpawner5 = { {Type = "Scorpion", Count = 1} },
	},
}

-- Arena AI configuration
ArenaConfig.AI = {
	MaxCreaturesPerPlayer = 5, -- Prevent overwhelming single players
	TargetRedistributionInterval = 2.0, -- Seconds between redistributing targets
	PathfindingUpdateRate = 0.5, -- How often to update pathfinding
	EnableSmartTargeting = true, -- Distribute enemies across players
}

-- Workspace instance paths (can be overridden if you restructure)
ArenaConfig.Paths = {
	SpawnFolder = nil,
	TeleportMarkersFolder = nil,
	TreasureDoor = nil,
}

-- Teleport fallback positions used when TeleportMarkersFolder isn't present
ArenaConfig.TeleportPositions = {
	Vector3.new(-5, 40, 135),
	Vector3.new(5, 40, 135),
	Vector3.new(0, 40, 140),
	Vector3.new(-3, 40, 130),
	Vector3.new(3, 40, 130),
}

-- Remote names under ReplicatedStorage.Remotes.Arena
ArenaConfig.Remotes = {
	Folder = "Arena",
	StartTimer = "StartTimer",
	Pause = "Pause",
	Resume = "Resume",
	Sync = "Sync",
	Victory = "Victory",
	PostGameChoice = "PostGameChoice",
}

-- UI strings
ArenaConfig.UI = {
	VictoryMessage = "VICTORY! You survived the Pharaoh's Curse!",
	ChoiceContinue = "Continue",
	ChoiceLobby = "Back to Lobby",
}

return ArenaConfig

