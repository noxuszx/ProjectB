--[[
	village.lua
	Configuration for village spawning system
	REFACTORED: Simplified from 15 parameters to 6 essential ones
]]--

local village = {}

-- Essential village spawning parameters
village.VILLAGES_TO_SPAWN = {1, 3}			-- Min and max villages to spawn
village.STRUCTURES_PER_VILLAGE = {3, 8}		-- Min and max structures per village (reduced from {3,6})
village.VILLAGE_RADIUS = 100					-- Maximum spread of structures in a village (increased from 50)
village.STRUCTURE_SPACING = 50				-- Minimum distance between structures in village

-- NEW: Toggle-based rotation system
village.ROTATION_MODE = "CARDINAL"			-- "RANDOM", "CARDINAL", "CENTER_FACING", "CARDINAL_VARIED"
village.ROTATION_SETTINGS = {
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
village.EDGE_BUFFER = 1						-- Keep 1 chunk from world edge
village.CENTER_BIAS = 0.3					-- Optional: 30% chance near spawn

-- Static configuration (unchanged)
village.VILLAGE_MODEL_FOLDER = "Models.Village"
village.AVAILABLE_STRUCTURES = {
	"House1",
	"House2", 
	"Shop"
}
village.SPAWN_DELAY = 0.1					-- Delay between structure spawns (seconds)

return village
