-- src/server/ai/arena/ArenaAIManager.lua
-- Dedicated AI management system for Arena events
-- Handles arena creature lifecycle, player distribution, and combat coordination

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaAIManager = {}
ArenaAIManager.__index = ArenaAIManager

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
	-- Update rates
	UPDATE_RATE = 30, -- 30 Hz for arena creatures (high priority)
	RETARGET_INTERVAL = 2.0, -- Seconds between target redistribution
	PATH_RECALC_INTERVAL = 0.5, -- Recalculate paths frequently for dynamic combat
	
	-- Detection and combat
	DETECTION_RANGE = 150, -- Large range for instant engagement
	CHASE_SPEED_MULTIPLIER = 1.3, -- Speed boost when chasing
	ATTACK_RANGE = 5, -- Range to deal damage
	
	-- Player distribution
	MAX_CREATURES_PER_PLAYER = 5, -- Prevent overwhelming single players
	REDISTRIBUTION_RADIUS = 30, -- Range to check for nearby creatures
	
	-- Performance
	MAX_ARENA_CREATURES = 50, -- Hard limit for arena
	BATCH_UPDATE_SIZE = 10, -- Process in batches
}

-- ============================================
-- SINGLETON INSTANCE
-- ============================================
local instance = nil

-- Global pathfinding throttle
local PathfindingThrottle = {
	lastComputeTime = {},
	minInterval = 0.1, -- Minimum 100ms between path computations per creature
	globalLastCompute = 0,
	globalMinInterval = 0.05, -- Minimum 50ms between ANY path computation
}

function ArenaAIManager.getInstance()
	if not instance then
		instance = ArenaAIManager.new()
	end
	return instance
end

function ArenaAIManager.new()
	local self = setmetatable({}, ArenaAIManager)
	
	-- Core state
	self.isActive = false
	self.creatures = {} -- Array of active creatures
	self.creaturesByModel = {} -- Model -> creature lookup
	self.playerTargets = {} -- Track which creatures target which players
	self.lastRetargetTime = 0
	self.updateConnection = nil
	
	-- Performance tracking
	self.frameCount = 0
	self.lastUpdateTime = 0
	
	return self
end

-- ============================================
-- INITIALIZATION & LIFECYCLE
-- ============================================

function ArenaAIManager:start()
	if self.isActive then
		warn("[ArenaAIManager] Already active")
		return false
	end
	
	print("[ArenaAIManager] Starting arena AI system")
	self.isActive = true
	self.lastUpdateTime = os.clock()
	self.lastRetargetTime = os.clock()
	
	-- Clear any existing data
	self:cleanup()
	
	-- Start update loop
	self.updateConnection = RunService.Heartbeat:Connect(function(dt)
		self:update(dt)
	end)
	
	return true
end

function ArenaAIManager:stop()
	if not self.isActive then
		return false
	end
	
	print("[ArenaAIManager] Stopping arena AI system")
	self.isActive = false
	
	if self.updateConnection then
		self.updateConnection:Disconnect()
		self.updateConnection = nil
	end
	
	-- Destroy all creatures
	for _, creature in ipairs(self.creatures) do
		if creature and creature.destroy then
			creature:destroy()
		end
	end
	
	self:cleanup()
	return true
end

function ArenaAIManager:cleanup()
	table.clear(self.creatures)
	table.clear(self.creaturesByModel)
	table.clear(self.playerTargets)
	self.lastRetargetTime = 0
end

-- ============================================
-- CREATURE REGISTRATION
-- ============================================

function ArenaAIManager:registerCreature(creature)
	if not self.isActive then
		warn("[ArenaAIManager] Cannot register creature - system not active")
		return false
	end
	
	if #self.creatures >= CONFIG.MAX_ARENA_CREATURES then
		warn("[ArenaAIManager] Max arena creatures reached:", CONFIG.MAX_ARENA_CREATURES)
		return false
	end
	
	-- Add to tracking
	table.insert(self.creatures, creature)
	self.creaturesByModel[creature.model] = creature
	
	-- Set arena-specific properties
	creature.isArenaCreature = true
	creature.detectionRange = CONFIG.DETECTION_RANGE
	creature.attackRange = CONFIG.ATTACK_RANGE
	
	-- Assign initial target
	local target = self:findBestTargetForCreature(creature)
	if target then
		creature:setTarget(target)
	end
	
	print(string.format("[ArenaAIManager] Registered %s (Total: %d)", 
		creature.creatureType, #self.creatures))
	
	return true
end

function ArenaAIManager:unregisterCreature(creature)
	-- Remove from creatures array
	for i, c in ipairs(self.creatures) do
		if c == creature then
			table.remove(self.creatures, i)
			break
		end
	end
	
	-- Remove from lookup
	self.creaturesByModel[creature.model] = nil
	
	-- Clean up player targets
	for playerId, creatures in pairs(self.playerTargets) do
		for i, c in ipairs(creatures) do
			if c == creature then
				table.remove(creatures, i)
				break
			end
		end
	end
	
	print(string.format("[ArenaAIManager] Unregistered creature (Remaining: %d)", #self.creatures))
end

-- ============================================
-- TARGET DISTRIBUTION SYSTEM
-- ============================================

function ArenaAIManager:getActivePlayers()
	local activePlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			local humanoid = player.Character.Humanoid
			if humanoid.Health > 0 then
				table.insert(activePlayers, player)
			end
		end
	end
	return activePlayers
end

function ArenaAIManager:findBestTargetForCreature(creature)
	local activePlayers = self:getActivePlayers()
	if #activePlayers == 0 then
		return nil
	end
	
	-- Count creatures targeting each player
	local targetCounts = {}
	for _, player in ipairs(activePlayers) do
		targetCounts[player] = 0
	end
	
	for _, otherCreature in ipairs(self.creatures) do
		if otherCreature ~= creature and otherCreature.currentTarget then
			local target = otherCreature.currentTarget
			if targetCounts[target] then
				targetCounts[target] = targetCounts[target] + 1
			end
		end
	end
	
	-- Find player with least creatures targeting them
	local bestTarget = nil
	local minCount = math.huge
	local creaturePos = creature.model.PrimaryPart.Position
	
	for player, count in pairs(targetCounts) do
		if count < minCount and count < CONFIG.MAX_CREATURES_PER_PLAYER then
			if player.Character and player.Character.PrimaryPart then
				local distance = (player.Character.PrimaryPart.Position - creaturePos).Magnitude
				-- Prefer closer players when counts are equal
				if count < minCount or (count == minCount and distance < 100) then
					minCount = count
					bestTarget = player
				end
			end
		end
	end
	
	-- Fallback to closest player if all are at max
	if not bestTarget then
		local closestDist = math.huge
		for _, player in ipairs(activePlayers) do
			if player.Character and player.Character.PrimaryPart then
				local distance = (player.Character.PrimaryPart.Position - creaturePos).Magnitude
				if distance < closestDist then
					closestDist = distance
					bestTarget = player
				end
			end
		end
	end
	
	return bestTarget
end

function ArenaAIManager:redistributeTargets()
	local currentTime = os.clock()
	if currentTime - self.lastRetargetTime < CONFIG.RETARGET_INTERVAL then
		return
	end
	self.lastRetargetTime = currentTime
	
	local activePlayers = self:getActivePlayers()
	if #activePlayers == 0 then
		return
	end
	
	-- Build current distribution
	local distribution = {}
	for _, player in ipairs(activePlayers) do
		distribution[player] = {}
	end
	
	-- Reassign creatures that lost their target or need rebalancing
	for _, creature in ipairs(self.creatures) do
		if creature.isActive then
			local needsNewTarget = false
			
			-- Check if current target is valid
			if not creature.currentTarget or not self:isValidTarget(creature.currentTarget) then
				needsNewTarget = true
			else
				-- Check if this player has too many creatures
				local targetCount = #(distribution[creature.currentTarget] or {})
				if targetCount >= CONFIG.MAX_CREATURES_PER_PLAYER then
					needsNewTarget = true
				end
			end
			
			if needsNewTarget then
				local newTarget = self:findBestTargetForCreature(creature)
				if newTarget and newTarget ~= creature.currentTarget then
					creature:setTarget(newTarget)
					print(string.format("[ArenaAIManager] Redistributed %s to %s", 
						creature.creatureType, newTarget.Name))
				end
			end
			
			-- Track distribution
			if creature.currentTarget and distribution[creature.currentTarget] then
				table.insert(distribution[creature.currentTarget], creature)
			end
		end
	end
end

function ArenaAIManager:isValidTarget(player)
	return player and player.Parent and player.Character 
		and player.Character:FindFirstChild("Humanoid")
		and player.Character.Humanoid.Health > 0
end

-- ============================================
-- MAIN UPDATE LOOP
-- ============================================

function ArenaAIManager:update(deltaTime)
	if not self.isActive or #self.creatures == 0 then
		return
	end
	
	local currentTime = os.clock()
	self.frameCount = self.frameCount + 1
	
	-- Redistribute targets periodically
	self:redistributeTargets()
	
	-- Update creatures in batches for performance
	self:updateCreatureBatch(deltaTime)
	
	-- Clean up dead creatures
	if self.frameCount % 60 == 0 then -- Every 2 seconds at 30Hz
		self:cleanupDeadCreatures()
	end
	
	self.lastUpdateTime = currentTime
end

function ArenaAIManager:cleanupDeadCreatures()
	local toRemove = {}
	
	for i, creature in ipairs(self.creatures) do
		if not creature.isActive or not creature.model.Parent then
			table.insert(toRemove, i)
		end
	end
	
	-- Remove in reverse order to maintain indices
	for i = #toRemove, 1, -1 do
		local creature = self.creatures[toRemove[i]]
		self:unregisterCreature(creature)
	end
	
	if #toRemove > 0 then
		print(string.format("[ArenaAIManager] Cleaned up %d dead creatures", #toRemove))
	end
end

-- Batch update function to improve performance
function ArenaAIManager:updateCreatureBatch(deltaTime)
	local batchSize = math.min(CONFIG.BATCH_UPDATE_SIZE, #self.creatures)
	local startIdx = ((self.frameCount - 1) % math.ceil(#self.creatures / batchSize)) * batchSize + 1
	local endIdx = math.min(startIdx + batchSize - 1, #self.creatures)
	
	-- Process batch
	for i = startIdx, endIdx do
		local creature = self.creatures[i]
		if creature and creature.isActive then
			-- Update creature behavior
			creature:update(deltaTime)
		end
	end
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

function ArenaAIManager:getCreatureCount()
	return #self.creatures
end

function ArenaAIManager:getCreaturesByTarget(player)
	local targeting = {}
	for _, creature in ipairs(self.creatures) do
		if creature.currentTarget == player then
			table.insert(targeting, creature)
		end
	end
	return targeting
end

function ArenaAIManager:canComputePath(creatureId)
	local currentTime = os.clock()
	
	-- Check global throttle
	if currentTime - PathfindingThrottle.globalLastCompute < PathfindingThrottle.globalMinInterval then
		return false
	end
	
	-- Check per-creature throttle
	local lastTime = PathfindingThrottle.lastComputeTime[creatureId] or 0
	if currentTime - lastTime < PathfindingThrottle.minInterval then
		return false
	end
	
	return true
end

function ArenaAIManager:recordPathCompute(creatureId)
	local currentTime = os.clock()
	PathfindingThrottle.lastComputeTime[creatureId] = currentTime
	PathfindingThrottle.globalLastCompute = currentTime
end

function ArenaAIManager:getDebugInfo()
	local info = {
		isActive = self.isActive,
		creatureCount = #self.creatures,
		playerCount = #self:getActivePlayers(),
		distribution = {},
	}
	
	-- Build distribution info
	for _, player in ipairs(self:getActivePlayers()) do
		local count = #self:getCreaturesByTarget(player)
		info.distribution[player.Name] = count
	end
	
	return info
end

return ArenaAIManager
