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
	DetectionRange = 70,
	ChaseRange = 70,
}

-- Wave composition (keep peak ~35)
ArenaConfig.Waves = {
	Phase1 = {
		WideSpawner1 = { {Type = "EgyptianSkeleton", Count = 3}, {Type = "Mummy", Count = 2} },
		WideSpawner2 = { {Type = "EgyptianSkeleton", Count = 3}, {Type = "Mummy", Count = 2} },
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

