-- src/shared/config/ai/NightHuntConfig.lua
-- Configuration for the Night Hunt system
-- Night-only Mummy spawns that pursue players during NIGHT periods

local NightHuntConfig = {
	
	-- Core spawn timing
	IntervalSeconds = 8,				-- Time between spawn attempts per player
	Radius = 100,						-- Distance from player to spawn mummies (studs)
	
	-- Population limits
	PerPlayerCap = 5,					-- Maximum concurrent Night Hunt mummies per player
	PerPlayerNightLimit = 5,			-- Maximum total spawns per player per night (lifetime limit)
	-- GlobalCap calculated dynamically: PerPlayerNightLimit × number of players
	
	-- Spawn placement settings
	SpawnHeight = 1,					-- Height above ground to spawn mummies (studs)
	MaxGroundRaycast = 30,				-- Maximum downward raycast distance to find ground (studs)
	MaxPlacementAttempts = 4,			-- Number of attempts to find valid spawn location per tick
	MinPlayerClearance = 10,			-- Minimum distance from player when placing (studs)
	
	-- Night Hunt behavior overrides
	DetectionRangeOverride = 100,		-- Override detection range for immediate aggro from spawn ring
	
	-- Cleanup behavior
	DespawnOnSunrise = "Destroy",		-- "Destroy" or "Pool" - how to handle cleanup at sunrise
	UsePooling = false,					-- Phase 1: false, Phase 2: true when pooling implemented
	
	-- Debug settings
	Debug = {
		LogSpawns = true,				-- Print spawn attempts and results
		LogCleanup = true,				-- Print cleanup operations
		LogPeriodChanges = true,		-- Print day/night period transitions
		ShowSpawnRings = false,			-- Visualize spawn rings around players (development only)
	}
}

return NightHuntConfig