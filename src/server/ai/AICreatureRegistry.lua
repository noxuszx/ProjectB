-- src/server/ai/AICreatureRegistry.lua  
-- Pure functions for creature registry management
-- Handles batch operations and cleanup to avoid performance spikes

local AICreatureRegistry = {}

-- Register a creature with LOD initialization
-- @param creature table - The creature object to register
-- @param activeCreatures table - The main creature registry
-- @return boolean - Success status
function AICreatureRegistry.registerCreature(creature, activeCreatures)
	if not creature then
		warn("[AICreatureRegistry] Attempted to register nil creature")
		return false
	end
	
	-- Initialize LOD properties
	creature.lodLevel = "Close"
	creature.lodUpdateRate = 30
	creature.lodLastUpdate = 0
	creature.lodNextUpdate = 0
	
	table.insert(activeCreatures, creature)
	return true
end

-- Remove a single creature from registry
-- @param creature table - The creature to remove
-- @param activeCreatures table - The main creature registry
-- @return boolean - Whether creature was found and removed
function AICreatureRegistry.unregisterCreature(creature, activeCreatures)
	for i = 1, #activeCreatures do
		if activeCreatures[i] == creature then
			table.remove(activeCreatures, i)
			return true
		end
	end
	return false
end

-- Batch remove multiple creatures efficiently  
-- @param activeCreatures table - The main creature registry
-- @param indicesToRemove table - Array of indices to remove (sorted descending)
function AICreatureRegistry.batchRemoveCreatures(activeCreatures, indicesToRemove)
	-- Remove in reverse order to maintain valid indices
	-- indicesToRemove should be sorted in descending order
	for i = 1, #indicesToRemove do
		local index = indicesToRemove[i]
		table.remove(activeCreatures, index)
	end
end

-- Collect indices of inactive/invalid creatures for batch removal
-- @param activeCreatures table - The main creature registry
-- @param toRemoveIndices table - Reusable array to collect indices (will be cleared)
-- @return table - Array of indices to remove (sorted descending)
function AICreatureRegistry.collectInactiveCreatures(activeCreatures, toRemoveIndices)
	-- Clear the reusable array
	table.clear(toRemoveIndices)
	
	-- Collect indices of creatures to remove (iterate forward)
	for i = 1, #activeCreatures do
		local creature = activeCreatures[i]
		
		-- Check if creature should be removed
		if not creature or 
		   not creature.isActive or 
		   not creature.model or 
		   not creature.model.Parent then
			table.insert(toRemoveIndices, i)
		end
	end
	
	-- Sort in descending order for safe removal
	table.sort(toRemoveIndices, function(a, b) return a > b end)
	
	return toRemoveIndices
end

-- Count active creatures by type for debugging
-- @param activeCreatures table - The main creature registry
-- @return table - Breakdown of creature counts by type
function AICreatureRegistry.getCreatureTypeBreakdown(activeCreatures)
	local breakdown = {}
	local totalActive = 0
	
	for i = 1, #activeCreatures do
		local creature = activeCreatures[i]
		if creature.isActive and creature.model.Parent then
			local creatureType = creature.creatureType or "Unknown"
			breakdown[creatureType] = (breakdown[creatureType] or 0) + 1
			totalActive = totalActive + 1
		end
	end
	
	breakdown.TotalActive = totalActive
	breakdown.TotalRegistered = #activeCreatures
	
	return breakdown
end

-- Validate creature registry integrity (for debugging)
-- @param activeCreatures table - The main creature registry
-- @return table - Validation results and issues found
function AICreatureRegistry.validateRegistry(activeCreatures)
	local results = {
		valid = 0,
		invalidCreatures = 0,
		missingModels = 0,
		duplicates = 0,
		issues = {}
	}
	
	local seenCreatures = {}
	
	for i = 1, #activeCreatures do
		local creature = activeCreatures[i]
		
		-- Check for nil creatures
		if not creature then
			results.invalidCreatures = results.invalidCreatures + 1
			table.insert(results.issues, "Nil creature at index " .. i)
			
		-- Check for missing models
		elseif not creature.model or not creature.model.Parent then
			results.missingModels = results.missingModels + 1
			table.insert(results.issues, "Missing model for creature at index " .. i)
			
		-- Check for duplicates
		elseif seenCreatures[creature] then
			results.duplicates = results.duplicates + 1
			table.insert(results.issues, "Duplicate creature at index " .. i)
		else
			results.valid = results.valid + 1
			seenCreatures[creature] = true
		end
	end
	
	return results
end

return AICreatureRegistry