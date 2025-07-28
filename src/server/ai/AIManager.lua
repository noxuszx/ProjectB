-- src/server/ai/AIManager.lua
-- Central AI management system - handles creature lifecycle and updates
-- Singleton pattern for global access

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AIConfig = require(ReplicatedStorage.Shared.config.ai.ai)

local AIManager = {}
AIManager.__index = AIManager
local instance = nil

-- Private properties
local activeCreatures = {}
local lastUpdateTime = 0
local updateConnection = nil

-- LOD system properties
local lodUpdateIndex = 1 -- Current creature index for LOD checking
local lodUpdateBatchSize = 15 -- Number of creatures to check LOD per frame
local lodCacheDuration = 0.5 -- How long to cache LOD results (seconds)

-- Singleton access
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
	self.updateBudget = AIConfig.Settings.UpdateBudgetMs / 1000 -- Convert to seconds
	
	return self
end

-- Initialize the AI system
function AIManager:init()
	if self.isInitialized then
		warn("[AIManager] Already initialized")
		return
	end
	
	self.isInitialized = true
	lastUpdateTime = tick()
	
	-- Start update loop
	updateConnection = RunService.Heartbeat:Connect(function()
		self:updateAllCreatures()
	end)
	

end

-- Calculate LOD level for a creature based on nearest player distance
local function calculateLODLevel(creature)
	local nearestPlayerDistance = math.huge
	
	-- Find nearest player
	for _, player in pairs(game.Players:GetPlayers()) do
		if player.Character and player.Character.PrimaryPart then
			local distance = (creature.position - player.Character.PrimaryPart.Position).Magnitude
			nearestPlayerDistance = math.min(nearestPlayerDistance, distance)
		end
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

-- Register a creature with the AI system
function AIManager:registerCreature(creature)
	if not creature then
		warn("[AIManager] Attempted to register nil creature")
		return
	end
	
	-- Initialize LOD properties
	creature.lodLevel = "Close"
	creature.lodUpdateRate = 30
	creature.lodLastUpdate = 0
	creature.lodNextUpdate = 0
	
	table.insert(activeCreatures, creature)
	self.totalCreatures = #activeCreatures
end

-- Unregister a creature from the AI system
function AIManager:unregisterCreature(creature)
	for i, activeCreature in ipairs(activeCreatures) do
		if activeCreature == creature then
			table.remove(activeCreatures, i)
			self.totalCreatures = #activeCreatures
			break
		end
	end
end

-- Staggered LOD update system - updates a batch of creatures' LOD levels each frame
function AIManager:updateCreatureLOD()
	if #activeCreatures == 0 then return end
	
	local currentTime = tick()
	local endIndex = math.min(lodUpdateIndex + lodUpdateBatchSize - 1, #activeCreatures)
	
	-- Update LOD for current batch of creatures
	for i = lodUpdateIndex, endIndex do
		local creature = activeCreatures[i]
		if creature and creature.isActive then
			-- Only recalculate LOD if cache has expired
			if currentTime - creature.lodLastUpdate >= lodCacheDuration then
				creature.lodLevel, creature.lodUpdateRate = calculateLODLevel(creature)
				creature.lodLastUpdate = currentTime
				creature.lodNextUpdate = currentTime + (1 / creature.lodUpdateRate)
			end
		end
	end
	
	-- Move to next batch, wrap around if we've reached the end
	lodUpdateIndex = endIndex + 1
	if lodUpdateIndex > #activeCreatures then
		lodUpdateIndex = 1
	end
end

-- Main update loop for all creatures with LOD system
function AIManager:updateAllCreatures()
	if not self.isInitialized or #activeCreatures == 0 then
		return
	end
	
	local currentTime = tick()
	local deltaTime = currentTime - lastUpdateTime
	lastUpdateTime = currentTime
	
	-- Update LOD levels for a batch of creatures each frame
	self:updateCreatureLOD()
	
	-- Batch cleanup system to prevent lag spikes from multiple table.remove() calls
	local toRemove = {}  -- Collect indices of creatures to remove
	
	-- Update creatures based on their LOD level and update rate
	for i = 1, #activeCreatures do
		local creature = activeCreatures[i]
		
		if creature and creature.isActive and creature.model.Parent then
			-- Check if this creature should be updated this frame based on LOD
			local shouldUpdate = false
			
			if creature.lodLevel == "Culled" then
				-- Don't update culled creatures
				shouldUpdate = false
			elseif creature.lodUpdateRate >= 30 then
				-- Close creatures: update every frame
				shouldUpdate = true
			else
				-- Medium/Far creatures: update based on their scheduled time
				shouldUpdate = currentTime >= creature.lodNextUpdate
				if shouldUpdate then
					creature.lodNextUpdate = currentTime + (1 / creature.lodUpdateRate)
				end
			end
			
			if shouldUpdate then
				creature:update(deltaTime)
			end
			
			-- Check if creature became inactive during update (e.g., missing PrimaryPart)
			if not creature.isActive then
				table.insert(toRemove, i)
			end
		else
			-- Mark inactive or destroyed creatures for removal
			table.insert(toRemove, i)
		end
	end
	
	-- Batch remove all inactive creatures (in reverse order to avoid index shifting issues)
	for i = #toRemove, 1, -1 do
		table.remove(activeCreatures, toRemove[i])
	end
	
	-- Update total count once after batch removal
	if #toRemove > 0 then
		self.totalCreatures = #activeCreatures
		-- Reset LOD index if it's beyond the new array size
		if lodUpdateIndex > #activeCreatures then
			lodUpdateIndex = 1
		end
	end
end

-- Get all creatures within a certain range of a position
function AIManager:getCreaturesInRange(position, range)
	local creaturesInRange = {}
	
	for _, creature in pairs(activeCreatures) do
		if creature.isActive and creature.model.Parent then
			local distance = (creature.position - position).Magnitude
			if distance <= range then
				table.insert(creaturesInRange, creature)
			end
		end
	end
	
	return creaturesInRange
end

-- Get creature instance by its Roblox model
function AIManager:getCreatureByModel(model)
	for _, creature in pairs(activeCreatures) do
		if creature.model == model then
			return creature
		end
	end
	return nil
end

-- Get total number of active creatures
function AIManager:getCreatureCount()
	return self.totalCreatures
end

-- Get debug information
function AIManager:getDebugInfo()
	-- Calculate LOD distribution
	local lodBreakdown = {Close = 0, Medium = 0, Far = 0, Culled = 0}
	for _, creature in pairs(activeCreatures) do
		if creature.isActive then
			lodBreakdown[creature.lodLevel] = (lodBreakdown[creature.lodLevel] or 0) + 1
		end
	end
	
	return {
		totalCreatures = self.totalCreatures,
		isInitialized = self.isInitialized,
		updateBudget = self.updateBudget,
		activeCreatureTypes = self:getCreatureTypeBreakdown(),
		lodDistribution = lodBreakdown,
		lodUpdateIndex = lodUpdateIndex,
		lodBatchSize = lodUpdateBatchSize
	}
end

-- Get breakdown of creature types
function AIManager:getCreatureTypeBreakdown()
	local breakdown = {}
	
	for _, creature in pairs(activeCreatures) do
		if creature.isActive then
			local creatureType = creature.creatureType
			breakdown[creatureType] = (breakdown[creatureType] or 0) + 1
		end
	end
	
	return breakdown
end

-- Cleanup and shutdown
function AIManager:shutdown()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	
	-- Cleanup all creatures
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
