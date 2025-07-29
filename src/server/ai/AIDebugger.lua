-- src/server/ai/AIDebugger.lua
-- Debug and monitoring functions for the AI system
-- Pure functions for analyzing AI performance and state

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIConfig = require(ReplicatedStorage.Shared.config.ai.ai)
local LODPolicy = require(script.Parent.LODPolicy)

local AIDebugger = {}

-- Get comprehensive debug information about the AI system
-- @param activeCreatures table - Array of active creature objects
-- @param cachedPlayerPositions table - Array of cached player positions
-- @param totalCreatures number - Total creature count
-- @param isInitialized boolean - Whether system is initialized
-- @param updateBudget number - Current update budget in seconds
-- @param lodUpdateIndex number - Current LOD batch index
-- @param lodBatchSize number - LOD batch size
-- @return table - Complete debug information
function AIDebugger.getDebugInfo(activeCreatures, cachedPlayerPositions, totalCreatures, isInitialized, updateBudget, lodUpdateIndex, lodBatchSize)
	-- Calculate LOD distribution
	local lodBreakdown = {Close = 0, Medium = 0, Far = 0, Culled = 0}
	for _, creature in pairs(activeCreatures) do
		if creature.isActive then
			lodBreakdown[creature.lodLevel] = (lodBreakdown[creature.lodLevel] or 0) + 1
		end
	end
	
	-- Get creature type breakdown
	local creatureTypeBreakdown = AIDebugger.getCreatureTypeBreakdown(activeCreatures)
	
	return {
		totalCreatures = totalCreatures,
		isInitialized = isInitialized,
		updateBudget = updateBudget,
		activeCreatureTypes = creatureTypeBreakdown,
		lodDistribution = lodBreakdown,
		lodUpdateIndex = lodUpdateIndex,
		lodBatchSize = lodBatchSize,
		cachedPlayerCount = #cachedPlayerPositions,
		
		-- Performance metrics
		performanceMetrics = AIDebugger.getPerformanceMetrics(activeCreatures),
		
		-- LOD statistics using current cached positions
		lodStats = LODPolicy.calculateLODStats(activeCreatures, cachedPlayerPositions)
	}
end

-- Get breakdown of creatures by type
-- @param activeCreatures table - Array of active creature objects
-- @return table - Count of each creature type
function AIDebugger.getCreatureTypeBreakdown(activeCreatures)
	local breakdown = {}
	
	for _, creature in pairs(activeCreatures) do
		if creature.isActive then
			local creatureType = creature.creatureType
			breakdown[creatureType] = (breakdown[creatureType] or 0) + 1
		end
	end
	
	return breakdown
end

-- Calculate performance metrics for the AI system
-- @param activeCreatures table - Array of active creature objects
-- @return table - Performance analysis
function AIDebugger.getPerformanceMetrics(activeCreatures)
	local metrics = {
		totalActive = 0,
		totalInactive = 0,
		averageUpdateRate = 0,
		lodDistribution = {Close = 0, Medium = 0, Far = 0, Culled = 0}
	}
	
	local totalUpdateRate = 0
	local activeCount = 0
	
	for _, creature in pairs(activeCreatures) do
		if creature.isActive and creature.model.Parent then
			metrics.totalActive = metrics.totalActive + 1
			activeCount = activeCount + 1
			
			-- Add to LOD distribution
			local lodLevel = creature.lodLevel or "Unknown"
			metrics.lodDistribution[lodLevel] = (metrics.lodDistribution[lodLevel] or 0) + 1
			
			-- Calculate average update rate
			totalUpdateRate = totalUpdateRate + (creature.lodUpdateRate or 0)
		else
			metrics.totalInactive = metrics.totalInactive + 1
		end
	end
	
	-- Calculate average update rate
	if activeCount > 0 then
		metrics.averageUpdateRate = totalUpdateRate / activeCount
	end
	
	return metrics
end

-- Log performance warning if budget is exceeded
-- @param elapsedTime number - Time spent in update cycle
-- @param updateBudget number - Maximum allowed time
-- @param phase string - Which phase exceeded budget
-- @param updatedCreatures number - How many creatures were updated
-- @param totalCreatures number - Total creatures in system
function AIDebugger.logPerformanceWarning(elapsedTime, updateBudget, phase, updatedCreatures, totalCreatures)
	if not AIConfig.Debug.LogPerformanceStats then
		return
	end
	
	local budgetMs = math.floor(updateBudget * 1000)
	local elapsedMs = math.floor(elapsedTime * 1000)
	local budgetPercent = math.floor((elapsedTime / updateBudget) * 100)
	
	warn(string.format(
		"[AIDebugger] Budget exceeded in %s: %dms/%dms (%d%%) - Updated %d/%d creatures",
		phase, elapsedMs, budgetMs, budgetPercent, updatedCreatures or 0, totalCreatures
	))
end

-- Log frame performance summary
-- @param totalFrameTime number - Total time spent in frame
-- @param updateBudget number - Budget limit
-- @param updatedCreatures number - Creatures updated this frame
-- @param totalCreatures number - Total creatures in system
function AIDebugger.logFramePerformance(totalFrameTime, updateBudget, updatedCreatures, totalCreatures)
	if not AIConfig.Debug.LogPerformanceStats then
		return
	end
	
	-- Only log if we used 80% or more of our budget
	if totalFrameTime <= updateBudget * 0.8 then
		return
	end
	
	print(string.format(
		"[AIDebugger] Frame time: %dms Budget: %dms Updated: %d creatures",
		math.floor(totalFrameTime * 1000),
		math.floor(updateBudget * 1000),
		updatedCreatures
	))
end

-- Generate a detailed system report for debugging
-- @param activeCreatures table - Array of active creature objects
-- @param cachedPlayerPositions table - Array of cached player positions
-- @param additionalData table - Additional system data
-- @return string - Formatted debug report
function AIDebugger.generateSystemReport(activeCreatures, cachedPlayerPositions, additionalData)
	local debugInfo = AIDebugger.getDebugInfo(
		activeCreatures, 
		cachedPlayerPositions,
		additionalData.totalCreatures,
		additionalData.isInitialized,
		additionalData.updateBudget,
		additionalData.lodUpdateIndex,
		additionalData.lodBatchSize
	)
	
	local report = {}
	table.insert(report, "=== AI System Debug Report ===")
	table.insert(report, "Status: " .. (debugInfo.isInitialized and "Initialized" or "Not Initialized"))
	table.insert(report, "Total Creatures: " .. debugInfo.totalCreatures)
	table.insert(report, "Cached Players: " .. debugInfo.cachedPlayerCount)
	table.insert(report, "Update Budget: " .. math.floor(debugInfo.updateBudget * 1000) .. "ms")
	
	table.insert(report, "\n--- LOD Distribution ---")
	for lodLevel, count in pairs(debugInfo.lodDistribution) do
		table.insert(report, lodLevel .. ": " .. count)
	end
	
	table.insert(report, "\n--- Creature Types ---")
	for creatureType, count in pairs(debugInfo.activeCreatureTypes) do
		table.insert(report, creatureType .. ": " .. count)
	end
	
	table.insert(report, "\n--- Performance Metrics ---")
	local metrics = debugInfo.performanceMetrics
	table.insert(report, "Active: " .. metrics.totalActive)
	table.insert(report, "Inactive: " .. metrics.totalInactive)
	table.insert(report, "Avg Update Rate: " .. string.format("%.1f", metrics.averageUpdateRate) .. "Hz")
	
	return table.concat(report, "\n")
end

-- Validate that player position caching is working correctly
-- @param cachedPlayerPositions table - Array of cached player positions
-- @return table - Validation results
function AIDebugger.validatePlayerCache(cachedPlayerPositions)
	local validation = {
		isValid = true,
		issues = {},
		playerCount = #cachedPlayerPositions,
		duplicates = 0
	}
	
	-- Check for duplicate positions (potential caching bug)
	local positionStrings = {}
	for i, position in ipairs(cachedPlayerPositions) do
		local posStr = tostring(position.X) .. "," .. tostring(position.Y) .. "," .. tostring(position.Z)
		
		if positionStrings[posStr] then
			validation.duplicates = validation.duplicates + 1
			validation.isValid = false
			table.insert(validation.issues, "Duplicate position found: " .. posStr)
		else
			positionStrings[posStr] = true
		end
	end
	
	-- Check if positions look reasonable (not NaN, not extremely large)
	for i, position in ipairs(cachedPlayerPositions) do
		if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then
			validation.isValid = false
			table.insert(validation.issues, "NaN position detected at index " .. i)
		end
		
		if math.abs(position.X) > 10000 or math.abs(position.Y) > 10000 or math.abs(position.Z) > 10000 then
			validation.isValid = false
			table.insert(validation.issues, "Extreme position detected at index " .. i .. ": " .. tostring(position))
		end
	end
	
	return validation
end

return AIDebugger