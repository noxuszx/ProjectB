-- src/server/ai/ParallelLODActor.lua
-- Parallel actor for LOD distance calculations using Parallel Luau
-- Processes creature LOD calculations on separate thread for performance

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import AI config for LOD thresholds
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)

local ParallelLODActor = {}

-- LOD calculation function that runs in parallel
-- @param creatureData table - Array of {position: Vector3, id: string}
-- @param playerPositions table - Array of player positions
-- @return table - Array of {id: string, lodLevel: string, updateRate: number}
function ParallelLODActor.calculateLODBatch(creatureData, playerPositions)
	local results = {}
	
	-- Early exit if no players
	if #playerPositions == 0 then
		for i = 1, #creatureData do
			table.insert(results, {
				id = creatureData[i].id,
				lodLevel = "Culled",
				updateRate = 0
			})
		end
		return results
	end
	
	-- Process each creature's LOD
	for i = 1, #creatureData do
		local creature = creatureData[i]
		local nearestPlayerDistance = math.huge
		
		-- Find nearest player distance
		for j = 1, #playerPositions do
			local distance = (creature.position - playerPositions[j]).Magnitude
			nearestPlayerDistance = math.min(nearestPlayerDistance, distance)
		end
		
		-- Determine LOD level based on distance
		local lodLevel, updateRate = ParallelLODActor.getLODFromDistance(nearestPlayerDistance)
		
		table.insert(results, {
			id = creature.id,
			lodLevel = lodLevel,
			updateRate = updateRate
		})
	end
	
	return results
end

-- Helper function to determine LOD level from distance
-- @param distance number - Distance to nearest player
-- @return string, number - LOD level and update rate
function ParallelLODActor.getLODFromDistance(distance)
	if distance == math.huge then
		return "Culled", 0
	end
	
	local lodConfig = AIConfig.Performance.LOD
	if distance <= lodConfig.Close.Distance then
		return "Close", lodConfig.Close.UpdateRate
	elseif distance <= lodConfig.Medium.Distance then
		return "Medium", lodConfig.Medium.UpdateRate
	elseif distance <= lodConfig.Far.Distance then
		return "Far", lodConfig.Far.UpdateRate
	else
		return "Culled", 0
	end
end

return ParallelLODActor