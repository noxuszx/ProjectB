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

-- Handle respawn requests
local function handleRespawnRequest(player)
	if not deadPlayers[player.UserId] then
		return -- Player not dead, ignore
	end
	
	print("[PlayerDeathHandler] Respawning player:", player.Name)
	
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
	
	print("[PlayerDeathHandler] Force respawning player after timeout:", player.Name)
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
			
			print("[PlayerDeathHandler] Player", player.Name, "died - applying ragdoll")
			local success = RagdollModule.Ragdoll(character)
			
			if success then
				ragdolledPlayers[player.UserId] = true
				deadPlayers[player.UserId] = true
				
				-- Show death UI to player
				showUIRemote:FireClient(player, 30) -- 30 seconds timeout
				print("[PlayerDeathHandler] Death UI shown to player:", player.Name)
				
				-- Start 30-second timeout timer
				deathTimers[player.UserId] = task.delay(30, function()
					forceRespawn(player)
				end)
				
				print("[PlayerDeathHandler] Successfully ragdolled player:", player.Name)
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

print("[PlayerDeathHandler] Player death ragdoll system initialized")
print("[PlayerDeathHandler] Auto-respawn disabled, manual respawn system active")