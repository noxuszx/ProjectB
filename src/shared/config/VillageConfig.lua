--[[
	VillageConfig.lua
	Configuration for village spawning system
]]--

local VillageConfig = {}

-- Village spawning parameters
VillageConfig.MIN_VILLAGES = 1			-- Minimum number of villages to spawn
VillageConfig.MAX_VILLAGES = 3			-- Maximum number of villages to spawn

-- Distance constraints
VillageConfig.MIN_VILLAGE_DISTANCE = 80	-- Minimum distance between villages (studs)
VillageConfig.MIN_SPAWN_DISTANCE = 100	-- Minimum distance from spawn point
VillageConfig.MAX_SPAWN_DISTANCE = 400	-- Maximum distance from spawn point

-- Village structure parameters
VillageConfig.VILLAGE_RADIUS = 50		-- Maximum spread of structures in a village
VillageConfig.MIN_STRUCTURE_DISTANCE = 30	-- Minimum distance between structures in village
VillageConfig.MAX_STRUCTURE_DISTANCE = 50	-- Maximum distance between structures in village

-- Model folder path
VillageConfig.VILLAGE_MODEL_FOLDER = "Models.Village"

-- Available structure types for villages
VillageConfig.AVAILABLE_STRUCTURES = {
	"House1",
	"House2", 
	"Shop"
}

-- Village composition settings
VillageConfig.STRUCTURES_PER_VILLAGE = {3, 6} -- Min and max structures per village
VillageConfig.RANDOM_ROTATION = true -- Enable random Y-axis rotation

-- Obstacle detection
VillageConfig.OBSTACLE_CHECK_RADIUS = 15	-- Radius to check for large obstacles
VillageConfig.MAX_PLACEMENT_ATTEMPTS = 10	-- Max attempts to find valid village location

-- Performance settings
VillageConfig.SPAWN_DELAY = 0.1			-- Delay between structure spawns (seconds)

return VillageConfig
