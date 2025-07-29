-- src/server/ai/LODPolicy.lua
-- Pure LOD (Level of Detail) calculation functions
-- Optimized with cached player positions to avoid expensive Character.PrimaryPart lookups

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIConfig = require(ReplicatedStorage.Shared.config.ai.ai)

local LODPolicy = {}

-- Calculate LOD level based on creature position and cached player positions
-- @param creaturePosition Vector3 - The creature's current position
-- @param cachedPlayerPositions table - Array of cached player position vectors
-- @return string, number - LOD level name and update rate
function LODPolicy.calculateLODLevel(creaturePosition, cachedPlayerPositions)
	local nearestPlayerDistance = math.huge
	
	-- Find nearest player using cached positions (major performance improvement)
	for i = 1, #cachedPlayerPositions do
		local playerPosition = cachedPlayerPositions[i]
		local distance = (creaturePosition - playerPosition).Magnitude
		nearestPlayerDistance = math.min(nearestPlayerDistance, distance)
	end
	
	-- Handle case where no players are cached
	if nearestPlayerDistance == math.huge then
		return "Culled", 0
	end
	
	-- Determine LOD level based on distance
	local lodConfig = AIConfig.Performance.LOD
	if nearestPlayerDistance <= lodConfig.Close.Distance then
		return "Close", lodConfig.Close.UpdateRate
	elseif nearestPlayerDistance <= lodConfig.Medium.Distance then
		return "Medium", lodConfig.Medium.UpdateRate
	elseif nearestPlayerDistance <= lodConfig.Far.Distance then
		return "Far", lodConfig.Far.UpdateRate
	else
		return "Culled", 0 -- Beyond max distance, don't update
	end
end

-- Get creatures within range of any cached player position
-- @param creatures table - Array of creature objects
-- @param cachedPlayerPositions table - Array of cached player position vectors  
-- @param range number - Maximum distance to include creatures
-- @param scratchArray table - Reusable array to avoid allocations
-- @return table - Array of creatures within range (using scratchArray)
function LODPolicy.getCreaturesInRange(creatures, cachedPlayerPositions, range, scratchArray)
	-- Clear the scratch array for reuse
	table.clear(scratchArray)
	
	-- Early exit if no players
	if #cachedPlayerPositions == 0 then
		return scratchArray
	end
	
	-- Check each creature against all player positions
	for i = 1, #creatures do
		local creature = creatures[i]
		if creature.isActive and creature.model.Parent then
			local creaturePosition = creature.position
			
			-- Check if creature is within range of any player
			local withinRange = false
			for j = 1, #cachedPlayerPositions do
				local playerPosition = cachedPlayerPositions[j]
				local distance = (creaturePosition - playerPosition).Magnitude
				
				if distance <= range then
					withinRange = true
					break -- Found one player in range, no need to check others
				end
			end
			
			if withinRange then
				table.insert(scratchArray, creature)
			end
		end
	end
	
	return scratchArray
end

-- Calculate LOD statistics for debugging
-- @param creatures table - Array of creature objects
-- @param cachedPlayerPositions table - Array of cached player position vectors
-- @return table - Statistics breakdown by LOD level
function LODPolicy.calculateLODStats(creatures, cachedPlayerPositions)
	local stats = {
		Close = 0,
		Medium = 0,
		Far = 0,
		Culled = 0,
		Total = 0
	}
	
	for i = 1, #creatures do
		local creature = creatures[i]
		if creature.isActive and creature.model.Parent then
			local lodLevel = LODPolicy.calculateLODLevel(creature.position, cachedPlayerPositions)
			stats[lodLevel] = (stats[lodLevel] or 0) + 1
			stats.Total = stats.Total + 1
		end
	end
	
	return stats
end

return LODPolicy