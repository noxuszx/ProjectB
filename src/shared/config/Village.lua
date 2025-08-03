--[[
	Village.lua
	Configuration for Village spawning system
	REFACTORED: Simplified from 15 parameters to 6 essential ones
]]--

local Village = {}

-- Essential Village spawning parameters
Village.VILLAGES_TO_SPAWN = {1, 3}			-- Min and max villages to spawn
Village.STRUCTURES_PER_VILLAGE = {3, 8}		-- Min and max structures per Village (reduced from {3,6})
Village.VILLAGE_RADIUS = 100					-- Maximum spread of structures in a Village (increased from 50)
Village.STRUCTURE_SPACING = 50				-- Minimum distance between structures in Village

-- NEW: Toggle-based rotation system
Village.ROTATION_MODE = "CARDINAL"			-- "RANDOM", "CARDINAL", "CENTER_FACING", "CARDINAL_VARIED"
Village.ROTATION_SETTINGS = {
	CARDINAL = { 
		angles = {0, 90, 180, 270} 
	},
	CENTER_FACING = { 
		face_inward = true, 
		angle_offset = 0 
	},
	CARDINAL_VARIED = { 
		base_angles = {0, 90, 180, 270}, 
		variance = 30 
	},
	RANDOM = {}
}

-- NEW: Edge spawning prevention
Village.EDGE_BUFFER = 1						-- Keep 1 chunk from world edge
Village.CENTER_BIAS = 0.3					-- Optional: 30% chance near spawn

-- Static configuration (unchanged)
Village.VILLAGE_MODEL_FOLDER = "Models.Village"
Village.AVAILABLE_STRUCTURES = {
	"House1",
	"House2",
	"Shop",
	"Well"
}
Village.SPAWN_DELAY = 0.1					-- Delay between structure spawns (seconds)

return Village
