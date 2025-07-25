--[[
	village.lua
	Configuration for village spawning system
]]--

local village = {}

-- Village spawning parameters
village.MIN_VILLAGES = 1			-- Minimum number of villages to spawn
village.MAX_VILLAGES = 3			-- Maximum number of villages to spawn

-- Distance constraints
village.MIN_VILLAGE_DISTANCE = 80	-- Minimum distance between villages (studs)
village.MIN_SPAWN_DISTANCE = 100	-- Minimum distance from spawn point
village.MAX_SPAWN_DISTANCE = 400	-- Maximum distance from spawn point

-- Village structure parameters
village.VILLAGE_RADIUS = 50		-- Maximum spread of structures in a village
village.MIN_STRUCTURE_DISTANCE = 30	-- Minimum distance between structures in village
village.MAX_STRUCTURE_DISTANCE = 50	-- Maximum distance between structures in village

village.VILLAGE_MODEL_FOLDER = "Models.Village"

village.AVAILABLE_STRUCTURES = {
	"House1",
	"House2", 
	"Shop"
}

-- Village composition settings
village.STRUCTURES_PER_VILLAGE = {3, 6} -- Min and max structures per village
village.RANDOM_ROTATION = true -- Enable random Y-axis rotation

-- Obstacle detection
village.OBSTACLE_CHECK_RADIUS = 15	-- Radius to check for large obstacles
village.MAX_PLACEMENT_ATTEMPTS = 10	-- Max attempts to find valid village location

-- Performance settings
village.SPAWN_DELAY = 0.1			-- Delay between structure spawns (seconds)

return village
