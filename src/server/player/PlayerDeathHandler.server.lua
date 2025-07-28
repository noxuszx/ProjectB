-- src/server/player/PlayerDeathHandler.server.lua
-- Handles player death events and applies ragdoll physics

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RagdollModule = require(ReplicatedStorage.Shared.modules.RagdollModule)

local PlayerDeathHandler = {}

-- Track ragdolled players to prevent duplicate processing
local ragdolledPlayers = {}

local function onPlayerAdded(player)
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		
		-- Connect to death event
		humanoid.Died:Connect(function()
			if ragdolledPlayers[player.UserId] then
				return -- Already ragdolled
			end
			
			print("[PlayerDeathHandler] Player", player.Name, "died - applying ragdoll")
			
			-- Apply ragdoll using the existing module function
			local success = RagdollModule.Ragdoll(character)
			
			if success then
				ragdolledPlayers[player.UserId] = true
				print("[PlayerDeathHandler] Successfully ragdolled player:", player.Name)
			else
				warn("[PlayerDeathHandler] Failed to ragdoll player:", player.Name)
			end
		end)
	end
	
	-- Connect to current character if exists
	if player.Character then
		onCharacterAdded(player.Character)
	end
	
	-- Connect to future characters
	player.CharacterAdded:Connect(onCharacterAdded)
end

local function onPlayerRemoving(player)
	-- Clean up tracking when player leaves
	ragdolledPlayers[player.UserId] = nil
end

-- Connect to all current players
for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Connect to future players
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("[PlayerDeathHandler] Player death ragdoll system initialized")