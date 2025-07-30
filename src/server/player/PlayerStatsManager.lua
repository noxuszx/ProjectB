-- src/server/player/PlayerStatsManager.lua
-- Central server-side management for player Health, Hunger, and Thirst
-- Handles stat decay, damage, and provides API for other systems

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStatsConfig = require(ReplicatedStorage.Shared.config.PlayerStatsConfig)
local PlayerStatsManager = {}
local playerStats = {}
local updatePlayerStatsRemote = nil
local ragdolledPlayers = {}

local lastDecayTime = 0
local decayConnection = nil

function PlayerStatsManager.init()
	print("[PlayerStatsManager] Initializing player stats system...")
	
	updatePlayerStatsRemote = ReplicatedStorage.Remotes:WaitForChild("UpdatePlayerStats", 10)
	if not updatePlayerStatsRemote then
		warn("[PlayerStatsManager] UpdatePlayerStats RemoteEvent not found! Create it manually in ReplicatedStorage.")
		return false
	end

	Players.PlayerAdded:Connect(PlayerStatsManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(PlayerStatsManager.onPlayerRemoving)

	for _, player in pairs(Players:GetPlayers()) do
		PlayerStatsManager.onPlayerAdded(player)
	end

	PlayerStatsManager.startDecayLoop()
	PlayerStatsManager.setupRagdollIntegration()

	print("[PlayerStatsManager] Player stats system initialized!")
	return true
end

function PlayerStatsManager.onPlayerAdded(player)
	local userId = player.UserId
	
	playerStats[userId] = {
		Health = PlayerStatsConfig.MAX_HEALTH,
		Hunger = PlayerStatsConfig.MAX_HUNGER,
		Thirst = PlayerStatsConfig.MAX_THIRST,
		LastUpdate = os.clock()
	}
	
	PlayerStatsManager.updateClientStats(player)
	
	if PlayerStatsConfig.DEBUG_MODE then
		print("[PlayerStatsManager] Initialized stats for", player.Name, "(" .. userId .. ")")
	end
end

-- Handle player leaving
function PlayerStatsManager.onPlayerRemoving(player)
	local userId = player.UserId
	
	playerStats[userId] = nil
	ragdolledPlayers[userId] = nil
	
	if PlayerStatsConfig.DEBUG_MODE then
		print("[PlayerStatsManager] Cleaned up stats for", player.Name, "(" .. userId .. ")")
	end
end

-- Start the persistent stat decay loop
function PlayerStatsManager.startDecayLoop()
	lastDecayTime = os.clock()
	
	decayConnection = RunService.Heartbeat:Connect(function()
		local currentTime = os.clock()
		
		-- Check if enough time has passed for a decay tick
		if currentTime - lastDecayTime >= PlayerStatsConfig.TICK_INTERVAL then
			PlayerStatsManager.processStatDecay()
			lastDecayTime = currentTime
		end
	end)
	
	print("[PlayerStatsManager] Stat decay loop started (interval:", PlayerStatsConfig.TICK_INTERVAL .. "s)")
end

-- Process stat decay for all players
function PlayerStatsManager.processStatDecay()
	for userId, stats in pairs(playerStats) do
		local player = Players:GetPlayerByUserId(userId)
		
		-- Skip if player doesn't exist or is ragdolled (dead)
		if not player or ragdolledPlayers[userId] then
			continue
		end
		
		-- Apply hunger and thirst decay
		local hungerDecay = PlayerStatsConfig.HUNGER_DECAY_PER_TICK
		local thirstDecay = PlayerStatsConfig.THIRST_DECAY_PER_TICK
		
		stats.Hunger = math.max(0, stats.Hunger - hungerDecay)
		stats.Thirst = math.max(0, stats.Thirst - thirstDecay)
		
		PlayerStatsManager.checkStarvationDamage(player, stats)
		PlayerStatsManager.updateClientStats(player)
		
		-- Debug log removed to reduce spam
		-- if PlayerStatsConfig.DEBUG_MODE then
		-- 	print("[PlayerStatsManager] Decay tick for", player.Name, 
		-- 		"- Hunger:", math.floor(stats.Hunger), "Thirst:", math.floor(stats.Thirst))
		-- end
	end
end

-- Check and apply starvation/dehydration damage
function PlayerStatsManager.checkStarvationDamage(player, stats)
	if not player.Character or not player.Character:FindFirstChild("Humanoid") then
		return
	end
	
	local humanoid = player.Character.Humanoid
	local totalDamage = 0
	
	-- Apply starvation damage
	if stats.Hunger <= 0 then
		totalDamage = totalDamage + PlayerStatsConfig.STARVATION_DAMAGE_PER_TICK
	end
	
	-- Apply dehydration damage
	if stats.Thirst <= 0 then
		totalDamage = totalDamage + PlayerStatsConfig.DEHYDRATION_DAMAGE_PER_TICK
	end
	
	-- Apply damage to Roblox's default health system
	if totalDamage > 0 then
		humanoid.Health = math.max(0, humanoid.Health - totalDamage)
		
		-- Debug log removed to reduce spam
		-- if PlayerStatsConfig.DEBUG_MODE then
		-- 	print("[PlayerStatsManager]", player.Name, "took", totalDamage, "starvation/dehydration damage")
		-- end
	end
end

-- Set up integration with existing ragdoll system
function PlayerStatsManager.setupRagdollIntegration()
	-- We need to hook into the existing PlayerDeathHandler's ragdolledPlayers table
	-- For now, we'll create our own tracking and let it be synchronized externally
	
	-- Connect to player character death events to track ragdoll state
	local function onPlayerAdded(player)
		local function onCharacterAdded(character)
			local humanoid = character:WaitForChild("Humanoid")
			
			humanoid.Died:Connect(function()
				ragdolledPlayers[player.UserId] = true
				if PlayerStatsConfig.DEBUG_MODE then
					print("[PlayerStatsManager] Player", player.Name, "died - pausing stat decay")
				end
			end)
		end
		
		if player.Character then
			onCharacterAdded(player.Character)
		end
		
		player.CharacterAdded:Connect(onCharacterAdded)
	end
	
	-- Connect to existing players
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	
	-- Connect to future players
	Players.PlayerAdded:Connect(onPlayerAdded)
end

-- Send updated stats to client
function PlayerStatsManager.updateClientStats(player)
	if not updatePlayerStatsRemote or not player or not player.Parent then
		return
	end
	
	local userId = player.UserId
	local stats = playerStats[userId]
	
	if not stats then
		return
	end
	
	-- Send stats to client for UI updates
	updatePlayerStatsRemote:FireClient(player, {
		Health = stats.Health,
		Hunger = stats.Hunger,
		Thirst = stats.Thirst
	})
end

-- API Functions for other systems

-- Take damage (affects health stat)
function PlayerStatsManager.TakeDamage(player, amount)
	local userId = player.UserId
	local stats = playerStats[userId]
	
	if not stats then
		warn("[PlayerStatsManager] No stats found for player:", player.Name)
		return false
	end
	
	stats.Health = math.max(0, stats.Health - amount)
	PlayerStatsManager.updateClientStats(player)
	
	if PlayerStatsConfig.DEBUG_MODE then
		print("[PlayerStatsManager]", player.Name, "took", amount, "damage - Health:", math.floor(stats.Health))
	end
	
	return true
end

-- Heal player (increases health)
function PlayerStatsManager.Heal(player, amount)
	local userId = player.UserId
	local stats = playerStats[userId]
	
	if not stats then
		warn("[PlayerStatsManager] No stats found for player:", player.Name)
		return false
	end
	
	stats.Health = math.min(PlayerStatsConfig.MAX_HEALTH, stats.Health + amount)
	PlayerStatsManager.updateClientStats(player)
	
	if PlayerStatsConfig.DEBUG_MODE then
		print("[PlayerStatsManager]", player.Name, "healed", amount, "- Health:", math.floor(stats.Health))
	end
	
	return true
end

-- Add hunger (food consumption)
function PlayerStatsManager.AddHunger(player, amount)
	local userId = player.UserId
	local stats = playerStats[userId]
	
	if not stats then
		warn("[PlayerStatsManager] No stats found for player:", player.Name)
		return false
	end
	
	stats.Hunger = math.min(PlayerStatsConfig.MAX_HUNGER, stats.Hunger + amount)
	PlayerStatsManager.updateClientStats(player)
	
	if PlayerStatsConfig.DEBUG_MODE then
		print("[PlayerStatsManager]", player.Name, "gained", amount, "hunger - Hunger:", math.floor(stats.Hunger))
	end
	
	return true
end

-- Add thirst (water consumption)
function PlayerStatsManager.AddThirst(player, amount)
	local userId = player.UserId
	local stats = playerStats[userId]
	
	if not stats then
		warn("[PlayerStatsManager] No stats found for player:", player.Name)
		return false
	end
	
	stats.Thirst = math.min(PlayerStatsConfig.MAX_THIRST, stats.Thirst + amount)
	PlayerStatsManager.updateClientStats(player)
	
	if PlayerStatsConfig.DEBUG_MODE then
		print("[PlayerStatsManager]", player.Name, "gained", amount, "thirst - Thirst:", math.floor(stats.Thirst))
	end
	
	return true
end

-- Respawn player (restore all stats to full)
function PlayerStatsManager.RespawnPlayer(player)
	local userId = player.UserId
	local stats = playerStats[userId]
	
	if not stats then
		warn("[PlayerStatsManager] No stats found for player:", player.Name)
		return false
	end
	
	-- Restore all stats to maximum
	stats.Health = PlayerStatsConfig.MAX_HEALTH
	stats.Hunger = PlayerStatsConfig.MAX_HUNGER
	stats.Thirst = PlayerStatsConfig.MAX_THIRST
	
	-- Clear ragdoll state
	ragdolledPlayers[userId] = nil
	
	PlayerStatsManager.updateClientStats(player)
	
	print("[PlayerStatsManager]", player.Name, "respawned - all stats restored to full")
	return true
end

-- Get player's current stats (utility function)
function PlayerStatsManager.GetPlayerStats(player)
	local userId = player.UserId
	return playerStats[userId]
end

-- Shutdown the system
function PlayerStatsManager.shutdown()
	if decayConnection then
		decayConnection:Disconnect()
		decayConnection = nil
	end
	
	playerStats = {}
	ragdolledPlayers = {}
	
	print("[PlayerStatsManager] Player stats system shutdown")
end

return PlayerStatsManager