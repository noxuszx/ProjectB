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
	
	if AIConfig.Settings.DebugMode then
		print("[AIManager] AI system initialized")
	end
end

-- Register a creature with the AI system
function AIManager:registerCreature(creature)
	if not creature then
		warn("[AIManager] Attempted to register nil creature")
		return
	end
	
	table.insert(activeCreatures, creature)
	self.totalCreatures = #activeCreatures
	
	if AIConfig.Settings.DebugMode then
		print("[AIManager] Registered creature:", creature.creatureType, "Total:", self.totalCreatures)
	end
end

-- Unregister a creature from the AI system
function AIManager:unregisterCreature(creature)
	for i, activeCreature in ipairs(activeCreatures) do
		if activeCreature == creature then
			table.remove(activeCreatures, i)
			self.totalCreatures = #activeCreatures
			
			if AIConfig.Settings.DebugMode then
				print("[AIManager] Unregistered creature:", creature.creatureType, "Total:", self.totalCreatures)
			end
			break
		end
	end
end

-- Main update loop for all creatures
function AIManager:updateAllCreatures()
	if not self.isInitialized or #activeCreatures == 0 then
		return
	end
	
	local currentTime = tick()
	local deltaTime = currentTime - lastUpdateTime
	lastUpdateTime = currentTime
	
	-- Simple update - just call update on all creatures
	-- TODO: Add performance optimizations (LOD, batching, etc.) later
	for i = #activeCreatures, 1, -1 do -- Iterate backwards for safe removal
		local creature = activeCreatures[i]
		
		if creature and creature.isActive and creature.model.Parent then
			creature:update(deltaTime)
		else
			-- Remove inactive or destroyed creatures
			table.remove(activeCreatures, i)
			self.totalCreatures = #activeCreatures
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

-- Get total number of active creatures
function AIManager:getCreatureCount()
	return self.totalCreatures
end

-- Get debug information
function AIManager:getDebugInfo()
	return {
		totalCreatures = self.totalCreatures,
		isInitialized = self.isInitialized,
		updateBudget = self.updateBudget,
		activeCreatureTypes = self:getCreatureTypeBreakdown()
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
