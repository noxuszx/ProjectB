-- src/server/player/PlayerDeathHandler.server.lua
-- Handles player death events and applies ragdoll physics

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RagdollModule = require(ReplicatedStorage.Shared.modules.RagdollModule)

-- Get death remotes
local deathRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Death")
local showUIRemote = deathRemotes:WaitForChild("ShowUI")
local requestRespawnRemote = deathRemotes:WaitForChild("RequestRespawn")

local PlayerDeathHandler = {}

-- Disable auto-respawn system
Players.CharacterAutoLoads = false

local ragdolledPlayers = {}
local deadPlayers = {} -- Track death state per player
local deathTimers = {} -- Track timeout timers per player

-- Check if all players are dead
local function areAllPlayersDead()
	local alivePlayers = 0
	local totalPlayers = 0
	
	for _, player in pairs(Players:GetPlayers()) do
		if player and player.UserId then
			totalPlayers = totalPlayers + 1
			if not deadPlayers[player.UserId] then
				alivePlayers = alivePlayers + 1
			end
		end
	end
	
	
	-- Need at least one player and all must be dead
	return totalPlayers > 0 and alivePlayers == 0
end

-- Handle respawn requests
local function handleRespawnRequest(player)
	if not deadPlayers[player.UserId] then
		return -- Player not dead, ignore
	end
	
	
	-- Cancel timeout timer
	if deathTimers[player.UserId] then
		task.cancel(deathTimers[player.UserId])
		deathTimers[player.UserId] = nil
	end
	
	-- Clear death state
	deadPlayers[player.UserId] = nil
	ragdolledPlayers[player.UserId] = nil
	
	-- Respawn player
	player:LoadCharacter()
end

-- Handle forced respawn after timeout
local function forceRespawn(player)
	if not deadPlayers[player.UserId] then
		return -- Player already respawned
	end
	
	handleRespawnRequest(player)
end

local function onPlayerAdded(player)
	-- Give initial character
	player:LoadCharacter()
	
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
        humanoid.BreakJointsOnDeath = false
        
        -- Clear death state on new character
        deadPlayers[player.UserId] = nil
        ragdolledPlayers[player.UserId] = nil
        
        -- Cancel any existing timer
        if deathTimers[player.UserId] then
        	task.cancel(deathTimers[player.UserId])
        	deathTimers[player.UserId] = nil
        end
		
		humanoid.Died:Connect(function()
			if ragdolledPlayers[player.UserId] or deadPlayers[player.UserId] then
				return -- Already handled
			end
			
			local success = RagdollModule.Ragdoll(character)
			
			if success then
				ragdolledPlayers[player.UserId] = true
				deadPlayers[player.UserId] = true
				
				-- Check if all players are now dead
				local allDead = areAllPlayersDead()
				
				if allDead then
					-- All players are now dead - show timer to ALL dead players
					
					for _, deadPlayer in pairs(Players:GetPlayers()) do
						if deadPlayers[deadPlayer.UserId] then
							showUIRemote:FireClient(deadPlayer, 30) -- 30 seconds timeout
								
							-- Start 30-second timeout timer for lobby return
							if deathTimers[deadPlayer.UserId] then
								task.cancel(deathTimers[deadPlayer.UserId])
							end
							deathTimers[deadPlayer.UserId] = task.delay(30, function()
								-- TODO: Send player back to lobby instead of respawning
								forceRespawn(deadPlayer)
							end)
						end
					end
				else
					-- Show death UI without timer (other players still alive)
					showUIRemote:FireClient(player, 0) -- 0 = no timer
				end
				
			else
				warn("[PlayerDeathHandler] Failed to ragdoll player:", player.Name)
			end
		end)
	end
	
	if player.Character then
		onCharacterAdded(player.Character)
	end
	
	player.CharacterAdded:Connect(onCharacterAdded)
end

local function onPlayerRemoving(player)
	-- Clean up player data
	ragdolledPlayers[player.UserId] = nil
	deadPlayers[player.UserId] = nil
	
	-- Cancel any active timers
	if deathTimers[player.UserId] then
		task.cancel(deathTimers[player.UserId])
		deathTimers[player.UserId] = nil
	end
end

-- Connect respawn request handler
requestRespawnRemote.OnServerEvent:Connect(handleRespawnRequest)

for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

