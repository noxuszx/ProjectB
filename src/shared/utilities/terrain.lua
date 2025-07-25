--[[
	terrain.lua
	Centralized terrain height calculation utilities
	Provides consistent terrain height calculations across all systems
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChunkConfig = require(ReplicatedStorage.Shared.config.ChunkConfig)
local NoiseGenerator = require(ReplicatedStorage.Shared.utilities.NoiseGenerator)

local terrain = {}

--[[
	Get terrain height at a specific world position
	
	@param x - World X coordinate
	@param z - World Z coordinate
	@return number - The terrain height at the given position
	
	This function handles the spawn area logic:
	- Flat area around spawn (within SPAWN_FLAT_RADIUS)
	- Transition zone (between SPAWN_FLAT_RADIUS and SPAWN_FLAT_RADIUS + SPAWN_TRANSITION_WIDTH)
	- Normal noise-based terrain (beyond transition zone)
]]--
function terrain.getTerrainHeight(x, z)
	local distanceFromSpawn = math.sqrt(x^2 + z^2)
	
	if distanceFromSpawn <= ChunkConfig.SPAWN_FLAT_RADIUS then
		-- Flat spawn area
		return ChunkConfig.SPAWN_HEIGHT
	elseif distanceFromSpawn <= (ChunkConfig.SPAWN_FLAT_RADIUS + ChunkConfig.SPAWN_TRANSITION_WIDTH) then
		-- Transition zone - interpolate between flat and noise-based height
		local transitionFactor = (distanceFromSpawn - ChunkConfig.SPAWN_FLAT_RADIUS) / ChunkConfig.SPAWN_TRANSITION_WIDTH
		return (1 - transitionFactor) * ChunkConfig.SPAWN_HEIGHT + transitionFactor * NoiseGenerator.getTerrainHeight(x, z, ChunkConfig)
	else
		-- Normal noise-based terrain
		return NoiseGenerator.getTerrainHeight(x, z, ChunkConfig)
	end
end

return terrain
