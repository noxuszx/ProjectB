-- src/server/ai/AIManager.lua
-- Central AI management system - handles creature lifecycle and updates
-- Singleton pattern for global access
-- Optimized with modular architecture and player position caching

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)
local LODPolicy = require(script.Parent.LODPolicy)
local AICreatureRegistry = require(script.Parent.AICreatureRegistry)
local AIDebugger = require(script.Parent.AIDebugger)

local AIManager = {}
AIManager.__index = AIManager
local instance = nil

-- ============================================
-- CORE STATE MANAGEMENT
-- ============================================
local activeCreatures = {}
local lastUpdateTime = 0
local updateConnection = nil

-- ============================================  
-- PLAYER POSITION CACHING SYSTEM
-- ============================================
local cachedPlayerPositions = {}
local lastPlayerCacheUpdate = 0
local playerCacheUpdateInterval = 0.1

-- ============================================
-- LOD (LEVEL OF DETAIL) SYSTEM
-- ============================================
local lodUpdateIndex = 1
local lodUpdateBatchSize = 15
local lodCacheDuration = 0.5

-- ============================================
-- PERFORMANCE OPTIMIZATION
-- ============================================
local scratchArray = {}
local toRemoveIndices = {}

function AIManager.getInstance()
	if not instance then
		instance = AIManager.new()
	end
	return instance
end

function AIManager.new()
	local self = setmetatable({}, AIManager)
	
	self.isInitialized = false
	self.totalCreatures = 0
	self.updateBudget = AIConfig.Settings.UpdateBudgetMs / 1000
	
	return self
end

-- ============================================
-- PLAYER POSITION CACHING FUNCTIONS
-- ============================================

-- Update cached player positions for performance optimization
local function updatePlayerPositionCache()
	local currentTime = os.clock()
	if currentTime - lastPlayerCacheUpdate < playerCacheUpdateInterval then
		return
	end
	table.clear(cachedPlayerPositions)
	
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character.PrimaryPart then
			table.insert(cachedPlayerPositions, player.Character.PrimaryPart.Position)
		end
	end
	
	lastPlayerCacheUpdate = currentTime
end

-- ============================================
-- INITIALIZATION
-- ============================================

-- Initialize the AI system
function AIManager:init()
	if self.isInitialized then
		warn("[AIManager] Already initialized")
		return
	end
	
	self.isInitialized = true
	lastUpdateTime = os.clock()
	LODPolicy.initParallel()
	updatePlayerPositionCache()
	updateConnection = RunService.Heartbeat:Connect(function()
		self:updateAllCreatures()
	end)
	

end


-- Register a creature with the AI system
-- ============================================
-- CREATURE LIFECYCLE MANAGEMENT
-- ============================================

function AIManager:registerCreature(creature)
	local success = AICreatureRegistry.registerCreature(creature, activeCreatures)
	if success then
		self.totalCreatures = #activeCreatures
	end
	return success
end

function AIManager:unregisterCreature(creature)
	local success = AICreatureRegistry.unregisterCreature(creature, activeCreatures)
	if success then
		self.totalCreatures = #activeCreatures
	end
	return success
end

-- Parallel LOD update system - processes all creatures using parallel actors
function AIManager:updateCreatureLOD()
	if #activeCreatures == 0 then return end
	
	local currentTime = os.clock()
	local creaturesToUpdate = {}
	
	-- Collect creatures that need LOD updates
	for _, creature in ipairs(activeCreatures) do
		if creature and creature.isActive then
			-- Only recalculate LOD if cache has expired
			if currentTime - creature.lodLastUpdate >= lodCacheDuration then
				table.insert(creaturesToUpdate, creature)
			end
		end
	end
	
	-- Process LOD updates in parallel batches
	if #creaturesToUpdate > 0 then
		local lodResults = LODPolicy.calculateLODBatch(creaturesToUpdate, cachedPlayerPositions)
		
		-- Apply results back to creatures
		for _, creature in ipairs(creaturesToUpdate) do
			local creatureId = tostring(creature.model)
			local result = lodResults[creatureId]
			
			if result then
				creature.lodLevel = result.lodLevel
				creature.lodUpdateRate = result.updateRate
				creature.lodLastUpdate = currentTime
				creature.lodNextUpdate = currentTime + (1 / math.max(creature.lodUpdateRate, 0.1))
			end
		end
	end
end

-- Main update loop for all creatures with LOD system
-- ============================================
-- MAIN UPDATE LOOP WITH BUDGET MANAGEMENT
-- ============================================

function AIManager:updateAllCreatures()
	if not self.isInitialized or #activeCreatures == 0 then
		return
	end
	
	local frameStartTime = os.clock()
	local currentTime = frameStartTime
	local deltaTime = currentTime - lastUpdateTime
	lastUpdateTime = currentTime
	
	updatePlayerPositionCache()
	self:updateCreatureLOD()
	
	local elapsedTime = os.clock() - frameStartTime
	if elapsedTime >= self.updateBudget then
		AIDebugger.logPerformanceWarning(elapsedTime, self.updateBudget, "LOD updates", 0, #activeCreatures)
		return
	end
	
	local updatedCreatures = 0
	
	-- Build per-LOD queues for fair budget allocation
	local queues = {
		Close = {},
		Medium = {},
		Far = {}
	}
	
	for _, creature in ipairs(activeCreatures) do
		if creature and creature.isActive and creature.model.Parent and creature.lodLevel ~= "Culled" then
			local shouldUpdate = (creature.lodUpdateRate >= 30) or (currentTime >= creature.lodNextUpdate)
			if shouldUpdate then
				table.insert(queues[creature.lodLevel], creature)
			end
		end
	end
	
	-- Allocate guaranteed budget per LOD band
	local BUDGET = {
		Close = 25,  -- Always serve close creatures first
		Medium = 15,
		Far = 10,
	}
	local MAX_TOTAL = 50  -- Safety cap
	
	local toUpdateThisFrame = {}
	local total = 0
	
	for level, list in pairs(queues) do
		local limit = math.min(#list, BUDGET[level])
		for i = 1, limit do
			if total >= MAX_TOTAL then break end
			table.insert(toUpdateThisFrame, list[i])
			total = total + 1
		end
	end
	
	-- Update the selected creatures
	for _, creature in ipairs(toUpdateThisFrame) do
		elapsedTime = os.clock() - frameStartTime
		if elapsedTime >= self.updateBudget then
			AIDebugger.logPerformanceWarning(elapsedTime, self.updateBudget, "creature updates", updatedCreatures, #activeCreatures)
			break
		end
		
		creature:update(deltaTime)
		updatedCreatures = updatedCreatures + 1
		
		-- Update next update time for timed creatures
		if creature.lodUpdateRate < 30 then
			creature.lodNextUpdate = currentTime + (1 / creature.lodUpdateRate)
		end
	end
	
	-- Batch cleanup using the new registry system
	AICreatureRegistry.collectInactiveCreatures(activeCreatures, toRemoveIndices)
	if #toRemoveIndices > 0 then
		AICreatureRegistry.batchRemoveCreatures(activeCreatures, toRemoveIndices)
		self.totalCreatures = #activeCreatures
		
		-- Reset LOD index if it's beyond the new array size
		if lodUpdateIndex > #activeCreatures then
			lodUpdateIndex = 1
		end
	end
	
	-- Performance logging (if debug enabled)
	local totalFrameTime = os.clock() - frameStartTime
	AIDebugger.logFramePerformance(totalFrameTime, self.updateBudget, updatedCreatures, #activeCreatures)
end

-- Get all creatures within a certain range of a position
-- ============================================
-- CREATURE QUERY FUNCTIONS
-- ============================================

function AIManager:getCreaturesInRange(position, range)
	local tempPositionCache = {position}
	return LODPolicy.getCreaturesInRange(activeCreatures, tempPositionCache, range, scratchArray)
end

function AIManager:getCreatureByModel(model)
	for _, creature in pairs(activeCreatures) do
		if creature.model == model then
			return creature
		end
	end
	return nil
end

function AIManager:getCreatureCount()
	return self.totalCreatures
end

function AIManager:getDebugInfo()
	return AIDebugger.getDebugInfo(
		activeCreatures,
		cachedPlayerPositions,
		self.totalCreatures,
		self.isInitialized,
		self.updateBudget,
		lodUpdateIndex,
		lodUpdateBatchSize
	)
end

function AIManager:getCreatureTypeBreakdown()
	return AIDebugger.getCreatureTypeBreakdown(activeCreatures)
end

function AIManager:shutdown()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	
	for _, creature in pairs(activeCreatures) do
		if creature and creature.destroy then
			creature:destroy()
		end
	end
	
	activeCreatures = {}
	self.totalCreatures = 0
	self.isInitialized = false
	
	if AIConfig.Settings.DebugMode then
		print("[AIManager] AI system shutdown")
	end
end

return AIManager
