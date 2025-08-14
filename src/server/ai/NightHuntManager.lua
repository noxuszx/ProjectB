-- src/server/ai/NightHuntManager.lua
-- Night Hunt system - spawns Mummies around players during NIGHT periods
-- Enforces caps, respects AI budget, and handles cleanup at sunrise

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local NightHuntConfig = require(ReplicatedStorage.Shared.config.ai.NightHuntConfig)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)
local DayNightCycle = require(script.Parent.Parent.environment.DayNightCycle)
local CreatureSpawner = require(script.Parent.CreatureSpawner)
local AIManager = require(script.Parent.AIManager)
local ChasingBehavior = require(script.Parent.behaviors.Chasing)

local NightHuntManager = {}

-- Internal state
local active = false
local perPlayer = {} -- [UserId] = { loopConnection, spawned = { aiController, ... }, nightSpawnCount = 0 }
local periodChangedConnection = nil

-- Cache frequently used values
local NIGHT_HUNT_TAG = "NIGHT_HUNT"

-- Select a random creature type based on weights
local function selectRandomCreatureType()
	local totalWeight = 0
	for _, weight in pairs(NightHuntConfig.CreatureTypes) do
		totalWeight = totalWeight + weight
	end
	
	local random = math.random() * totalWeight
	local currentWeight = 0
	
	for creatureType, weight in pairs(NightHuntConfig.CreatureTypes) do
		currentWeight = currentWeight + weight
		if random <= currentWeight then
			return creatureType
		end
	end
	
	-- Fallback to first creature type
	for creatureType, _ in pairs(NightHuntConfig.CreatureTypes) do
		return creatureType
	end
	
	return "Mummy" -- Ultimate fallback
end

-- Get total active Night Hunt creatures across all players
local function getTotalActiveNightHunt()
	local total = 0
	for _, playerData in pairs(perPlayer) do
		total = total + #playerData.spawned
	end
	return total
end

-- Get total spawns this night across all players
local function getTotalNightSpawns()
	local total = 0
	for _, playerData in pairs(perPlayer) do
		total = total + (playerData.nightSpawnCount or 0)
	end
	return total
end

-- Get dynamic global cap based on current player count
local function getDynamicGlobalCap()
	local playerCount = 0
	for _ in pairs(perPlayer) do
		playerCount = playerCount + 1
	end
	return playerCount * NightHuntConfig.PerPlayerNightLimit
end

-- Check if spawn preconditions are met
local function canSpawn(player)
	if not active then return false, "Night Hunt not active" end
	if not (player and player.Character and player.Character.PrimaryPart) then
		return false, "Player character invalid"
	end
	
	local aiManager = AIManager.getInstance()
	if aiManager:getCreatureCount() >= AIConfig.Settings.MaxCreatures then
		return false, "AI creature limit reached"
	end
	
	local playerData = perPlayer[player.UserId]
	if not playerData then
		return false, "Player data not found"
	end
	
	-- Check per-player concurrent cap
	if #playerData.spawned >= NightHuntConfig.PerPlayerCap then
		return false, "Per-player concurrent cap reached (" .. NightHuntConfig.PerPlayerCap .. ")"
	end
	
	-- Check per-player night limit (lifetime spawns this night)
	if playerData.nightSpawnCount >= NightHuntConfig.PerPlayerNightLimit then
		return false, "Per-player night limit reached (" .. NightHuntConfig.PerPlayerNightLimit .. ")"
	end
	
	-- Check dynamic global night limit
	local totalNightSpawns = getTotalNightSpawns()
	local dynamicGlobalCap = getDynamicGlobalCap()
	if totalNightSpawns >= dynamicGlobalCap then
		return false, "Global night limit reached (" .. dynamicGlobalCap .. ")"
	end
	
	return true, "Can spawn"
end

-- Find valid spawn position using ground raycast
local function findSpawnPosition(playerPosition)
	for attempt = 1, NightHuntConfig.MaxPlacementAttempts do
		-- Choose random angle and calculate target position
		local angle = math.random() * 2 * math.pi
		local targetPosition = playerPosition + Vector3.new(
			math.cos(angle) * NightHuntConfig.Radius,
			0,
			math.sin(angle) * NightHuntConfig.Radius
		)
		
		-- Raycast downward from elevated position to find ground
		local rayOrigin = targetPosition + Vector3.new(0, 50, 0)
		local rayDirection = Vector3.new(0, -NightHuntConfig.MaxGroundRaycast - 50, 0)
		
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = {workspace:FindFirstChild("NPCs")}
		
		local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
		
		if result then
			local groundPosition = result.Position
			local spawnPosition = groundPosition + Vector3.new(0, NightHuntConfig.SpawnHeight, 0)
			
			-- Check minimum clearance from player
			local distanceToPlayer = (spawnPosition - playerPosition).Magnitude
			if distanceToPlayer >= NightHuntConfig.MinPlayerClearance then
				return spawnPosition
			end
		end
	end
	
	return nil -- Failed to find valid position
end

-- Remove creature from tracking when it dies or is destroyed
local function onCreatureRemoved(aiController, player)
	local playerData = perPlayer[player.UserId]
	if not playerData then return end
	
	for i, trackedController in ipairs(playerData.spawned) do
		if trackedController == aiController then
			table.remove(playerData.spawned, i)
			
			-- Unregister from AIManager
			local aiManager = AIManager.getInstance()
			aiManager:unregisterCreature(aiController)
			
			if NightHuntConfig.Debug.LogCleanup then
				print("[NightHuntManager] Removed destroyed creature from tracking for " .. player.Name)
			end
			break
		end
	end
end

-- Spawn a single Night Hunt creature for a player
local function spawnNightHuntCreature(player)
	local canSpawnResult, reason = canSpawn(player)
	if not canSpawnResult then
		if NightHuntConfig.Debug.LogSpawns then
			print("[NightHuntManager] Cannot spawn for " .. player.Name .. ": " .. reason)
		end
		return
	end
	
	local playerPosition = player.Character.PrimaryPart.Position
	local spawnPosition = findSpawnPosition(playerPosition)
	
	if not spawnPosition then
		if NightHuntConfig.Debug.LogSpawns then
			print("[NightHuntManager] Failed to find valid spawn position for " .. player.Name)
		end
		return
	end
	
	-- Select and spawn random creature type
	local creatureType = selectRandomCreatureType()
	local aiController = CreatureSpawner.spawnCreature(creatureType, spawnPosition, { activationMode = "Event" })
	
	if not aiController then
		if NightHuntConfig.Debug.LogSpawns then
			print("[NightHuntManager] Failed to spawn " .. creatureType .. " for " .. player.Name)
		end
		return
	end
	
	-- CRITICAL: Register with AIManager for updates (CreatureSpawner doesn't do this automatically)
	local aiManager = AIManager.getInstance()
	local registered = aiManager:registerCreature(aiController)
	if not registered then
		warn("[NightHuntManager] Failed to register creature with AIManager - destroying")
		if aiController.model then
			aiController.model:Destroy()
		end
		return
	end
	
	-- Apply Night Hunt overrides - MUST set detection range BEFORE behavior
	local originalDetectionRange = aiController.detectionRange
	aiController.detectionRange = NightHuntConfig.DetectionRangeOverride
	
	-- Force immediate chasing behavior with the new detection range
	local chasingBehavior = ChasingBehavior.new(player)
	aiController:setBehavior(chasingBehavior)
	
	if NightHuntConfig.Debug.LogSpawns then
		print("[NightHuntManager] Detection range override: " .. originalDetectionRange .. " -> " .. aiController.detectionRange)
		print("[NightHuntManager] Set chasing behavior targeting: " .. player.Name)
	end
	
	-- Tag the model for cleanup tracking
	if aiController.model then
		aiController.model:SetAttribute("NightHunt", true)
		CollectionService:AddTag(aiController.model, NIGHT_HUNT_TAG)
	end
	
	-- Track the creature
	local playerData = perPlayer[player.UserId]
	if playerData then
		table.insert(playerData.spawned, aiController)
		playerData.nightSpawnCount = playerData.nightSpawnCount + 1  -- Increment lifetime spawn count
		
		-- Set up cleanup when creature dies
		if aiController.model and aiController.model:FindFirstChild("Humanoid") then
			aiController.model.Humanoid.Died:Connect(function()
				onCreatureRemoved(aiController, player)
			end)
		end
		
		-- Set up cleanup if model is destroyed
		if aiController.model then
			aiController.model.AncestryChanged:Connect(function()
				if not aiController.model.Parent then
					onCreatureRemoved(aiController, player)
				end
			end)
		end
	end
	
	if NightHuntConfig.Debug.LogSpawns then
		local playerData = perPlayer[player.UserId]
		print("[NightHuntManager] Spawned Night Hunt " .. creatureType .. " for " .. player.Name .. " at distance " .. 
			string.format("%.1f", (spawnPosition - playerPosition).Magnitude) .. 
			" (Active: " .. #playerData.spawned .. "/" .. NightHuntConfig.PerPlayerCap .. 
			", Night total: " .. playerData.nightSpawnCount .. "/" .. NightHuntConfig.PerPlayerNightLimit .. ")")
	end
end

-- Per-player spawn loop (runs every IntervalSeconds)
local function createPlayerSpawnLoop(player)
	local connection = task.spawn(function()
		while active and player.Parent do
			spawnNightHuntCreature(player)
			task.wait(NightHuntConfig.IntervalSeconds)
		end
	end)
	
	return connection
end

-- Clean up all Night Hunt creatures for a player (or all players if nil)
local function cleanupNightHuntCreatures(targetPlayer)
	local playersToCleanup = targetPlayer and {targetPlayer} or Players:GetPlayers()
	
	for _, player in ipairs(playersToCleanup) do
		local playerData = perPlayer[player.UserId]
		if not playerData then continue end
		
		-- Clean up tracked creatures
		local aiManager = AIManager.getInstance()
		for _, aiController in ipairs(playerData.spawned) do
			-- Unregister from AIManager first
			aiManager:unregisterCreature(aiController)
			
			if aiController.model and aiController.model.Parent then
				if NightHuntConfig.DespawnOnSunrise == "Pool" and NightHuntConfig.UsePooling then
					-- Phase 2: Use pooling when implemented
					-- CreaturePoolManager.poolCreature(aiController.model, aiController.creatureType)
					aiController.model:Destroy() -- Fallback to destroy for Phase 1
				else
					aiController.model:Destroy()
				end
			end
		end
		
		playerData.spawned = {}
		
		if NightHuntConfig.Debug.LogCleanup then
			print("[NightHuntManager] Cleaned up Night Hunt creatures for " .. player.Name)
		end
	end
end

-- Handle player leaving during Night Hunt
local function onPlayerLeaving(player)
	if not perPlayer[player.UserId] then return end
	
	-- Stop spawn loop
	if perPlayer[player.UserId].loopConnection then
		task.cancel(perPlayer[player.UserId].loopConnection)
	end
	
	-- Clean up their creatures
	cleanupNightHuntCreatures(player)
	
	-- Remove from tracking
	perPlayer[player.UserId] = nil
	
	if NightHuntConfig.Debug.LogCleanup then
		print("[NightHuntManager] Player " .. player.Name .. " left during Night Hunt")
	end
end

-- Handle period changes
local function onPeriodChanged(newPeriod, currentTime)
	if NightHuntConfig.Debug.LogPeriodChanges then
		print("[NightHuntManager] Period changed to: " .. newPeriod)
	end
	
	if newPeriod == "NIGHT" and not active then
		NightHuntManager.start()
	elseif (newPeriod == "DAWN" or newPeriod == "SUNRISE") and active then
		NightHuntManager.stop()
	end
end

-- Public API
function NightHuntManager.init()
	-- Set up player event handlers
	Players.PlayerRemoving:Connect(onPlayerLeaving)
	
	-- Connect to period changes
	local periodChangedServer = ReplicatedStorage:WaitForChild("PeriodChangedServer")
	periodChangedConnection = periodChangedServer.Event:Connect(onPeriodChanged)
	
	-- Start immediately if already night
	local currentPeriod = DayNightCycle.getCurrentPeriod()
	if currentPeriod == "NIGHT" then
		NightHuntManager.start()
	end
	
	print("[NightHuntManager] Initialized - Current period: " .. (currentPeriod or "Unknown"))
end

function NightHuntManager.start()
	if active then return end
	
	active = true
	
	-- Start spawn loops for all current players
	for _, player in ipairs(Players:GetPlayers()) do
		perPlayer[player.UserId] = {
			loopConnection = createPlayerSpawnLoop(player),
			spawned = {},
			nightSpawnCount = 0  -- Reset spawn count for new night
		}
	end
	
	-- Handle players joining during night
	Players.PlayerAdded:Connect(function(player)
		if active then
			perPlayer[player.UserId] = {
				loopConnection = createPlayerSpawnLoop(player),
				spawned = {},
				nightSpawnCount = 0  -- New player starts with 0 spawns this night
			}
			
			if NightHuntConfig.Debug.LogSpawns then
				print("[NightHuntManager] Player " .. player.Name .. " joined during Night Hunt")
			end
		end
	end)
	
	print("[NightHuntManager] Night Hunt started!")
end

function NightHuntManager.stop()
	if not active then return end
	
	active = false
	
	-- Stop all spawn loops
	for userId, playerData in pairs(perPlayer) do
		if playerData.loopConnection then
			task.cancel(playerData.loopConnection)
		end
	end
	
	-- Clean up all Night Hunt creatures
	cleanupNightHuntCreatures()
	
	-- Clear all player data
	perPlayer = {}
	
	print("[NightHuntManager] Night Hunt stopped - all creatures cleaned up")
end

function NightHuntManager.getDebugInfo()
	local playerCounts = {}
	local playerNightCounts = {}
	for userId, playerData in pairs(perPlayer) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			playerCounts[player.Name] = #playerData.spawned
			playerNightCounts[player.Name] = playerData.nightSpawnCount
		end
	end
	
	return {
		active = active,
		totalActiveNightHunt = getTotalActiveNightHunt(),
		totalNightSpawns = getTotalNightSpawns(),
		dynamicGlobalCap = getDynamicGlobalCap(),
		playerConcurrentCounts = playerCounts,
		playerNightCounts = playerNightCounts,
		perPlayerCap = NightHuntConfig.PerPlayerCap,
		perPlayerNightLimit = NightHuntConfig.PerPlayerNightLimit
	}
end

return NightHuntManager