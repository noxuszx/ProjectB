--[[
	ChunkConfig.lua
	Configuration for chunk-based terrain generation
]]--

local ChunkConfig = {}

-- Chunk system parameters
ChunkConfig.CHUNK_SIZE = 234 			-- Size of each chunk in studs (32x32)
ChunkConfig.RENDER_DISTANCE = 5		-- How many chunks to render in each direction (3 = 7x7 grid)
ChunkConfig.HEIGHT_RANGE = {
	MIN = 0,
	MAX = 5
}
ChunkConfig.BASE_HEIGHT = 0

-- Terrain generation parameters
ChunkConfig.NOISE_SCALE = 0.03 			-- How "zoomed in" the noise is (smaller = more detailed)
ChunkConfig.NOISE_OCTAVES = 4  			-- Number of noise layers
ChunkConfig.NOISE_PERSISTENCE = 0.5 	-- How much each octave contributes

-- Visual parameters
ChunkConfig.TERRAIN_MATERIAL = Enum.Material.Plastic
ChunkConfig.TERRAIN_COLOR = Color3.fromRGB(235, 225, 169)

-- Performance parameters
ChunkConfig.GENERATION_DELAY = 0

-- Chunk subdivision
ChunkConfig.SUBDIVISIONS = 4 			-- How many parts per chunk axis (4x4 = 16 parts per chunk)

-- Spawn area parameters
ChunkConfig.SPAWN_FLAT_RADIUS = 48 		-- Radius around spawn to keep flat (in studs)
ChunkConfig.SPAWN_HEIGHT = 2 			-- Height of the flat spawn area
ChunkConfig.SPAWN_TRANSITION_WIDTH = 16 -- Width of transition zone from flat to terrain

return ChunkConfig
