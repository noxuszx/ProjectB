--[[
	Village.lua
	Configuration for Village spawning system
	REFACTORED: Simplified from 15 parameters to 6 essential ones
]]--

local Village = {}

-- Essential Village spawning parameters
Village.VILLAGES_TO_SPAWN = {3, 4}				-- Min and max villages to spawn (increased)
Village.STRUCTURES_PER_VILLAGE = {8, 14}		-- Min and max structures per Village (more buildings)
Village.VILLAGE_RADIUS = 120					-- Maximum spread of structures in a Village (increased to fit more)
Village.STRUCTURE_SPACING = 5					-- Minimum distance between structures in Village (kept tight for density)

-- NEW: Mandatory structure system
Village.MANDATORY_STRUCTURES = {"Hospital", "Sell", "Campfire", "Well"}	-- Must appear once per village
Village.CAMPFIRE_BUFFER = 10					-- Minimum gap (studs) between campfire and other structures (reduced for density)

-- NEW: Global spacing between villages
Village.MIN_VILLAGE_DISTANCE = 0			-- Minimum center-to-center distance between villages (0 disables spacing)

-- NEW: Frame budgeting
Village.BATCH_SIZE = 1							-- Structures to spawn per frame (will be adjusted per device)

-- NEW: Toggle-based rotation system
Village.ROTATION_MODE = "CARDINAL"				-- "RANDOM", "CARDINAL", "CENTER_FACING", "CARDINAL_VARIED"
Village.ROTATION_SETTINGS = {
	CARDINAL = { 
		angles = {0, 90, 180, 270},
		angle_offset = 180
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

-- NEW: A/B test for western main street layout
Village.LAYOUT_AB_TEST_PROB = 0.8 -- 50% chance to use main street layout per village
Village.MAIN_STREET = {
	HalfWidth = 45,                 -- distance from street centerline to each row center
	FrontageSpacing = {18, 26},     -- spacing between buildings along the row
	JitterAlong = 3,                -- max along-street jitter (+/-)
	JitterSetback = 2,              -- small setback variation (+/-) toward/away from street
	SkipChance = 0.12,              -- chance to skip a frontage slot (empty lot)
	TIntersectionChance = 0.4,      -- chance to add a short perpendicular T near the center
	TCrossLengthRatio = 0.5         -- cross length relative to main street reach
}

-- NEW: Edge spawning prevention
Village.EDGE_BUFFER = 1						-- Keep 1 chunk from world edge
Village.CENTER_BIAS = 0.3					-- Optional: 30% chance near spawn

-- Static configuration (unchanged)
Village.VILLAGE_MODEL_FOLDER = "Models.Village"
Village.AVAILABLE_STRUCTURES = {
	"House1",
	"House2",
	"House3",
	"House4",
	"Campfire",
	"Hospital",
	"Sell",
	"Market",
	"WeaponShop",
	"Well"
}
Village.SPAWN_DELAY = 0.1

return Village
