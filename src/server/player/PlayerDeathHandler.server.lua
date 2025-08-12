-- src/server/player/PlayerDeathHandler.server.lua
-- Handles player death events and applies ragdoll physics

local Players 			   = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local RagdollModule 	   = require(ReplicatedStorage.Shared.modules.RagdollModule)

local deathRemotes 		   = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Death")
local showUIRemote 		   = deathRemotes:WaitForChild("ShowUI")
local requestRespawnRemote = deathRemotes:WaitForChild("RequestRespawn")
local revivalFeedbackRemote = deathRemotes:WaitForChild("RevivalFeedback")

Players.CharacterAutoLoads = false

local PlayerDeathHandler   = {}
local ragdolledPlayers     = {}
local deadPlayers 		   = {}
local deathTimers 		   = {}
local ragdollPositions 	   = {}
local revivalPrompts	   = {}

local function areAllPlayersDead()
	local alivePlayers 	   = 0
	local totalPlayers     = 0

	for _, player in pairs(Players:GetPlayers()) do
		if player and player.UserId then
			totalPlayers = totalPlayers + 1
			if not deadPlayers[player.UserId] then
				alivePlayers = alivePlayers + 1
			end
		end
	end
	return totalPlayers > 0 and alivePlayers == 0
end


local function handleRespawnRequest(player)
	if not deadPlayers[player.UserId] then
		return
	end

	-- Prefer current body position (in case the body was dragged), fallback to original death position
	local spawnPosition
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		spawnPosition = hrp.Position
	else
		spawnPosition = ragdollPositions[player.UserId]
	end

	if deathTimers  [player.UserId] then
		task.cancel (deathTimers[player.UserId])
		deathTimers [player.UserId]  = nil
	end

	deadPlayers		[player.UserId] = nil
	ragdolledPlayers[player.UserId] = nil
	ragdollPositions[player.UserId] = nil
	
	-- Clean up revival prompt
	if revivalPrompts[player.UserId] then
		revivalPrompts[player.UserId]:Destroy()
		revivalPrompts[player.UserId] = nil
	end

	if spawnPosition then
		-- Set position immediately when character spawns
		local connection
		connection = player.CharacterAdded:Connect(function(character)
			connection:Disconnect()
			local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
			humanoidRootPart.CFrame = CFrame.new(spawnPosition)
		end)
	end
	
	player:LoadCharacter()
end


local function forceRespawn(player)
	if not deadPlayers[player.UserId] then
		return
	end
	handleRespawnRequest(player)
end

local function onPlayerAdded(player)
	player:LoadCharacter()

	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.BreakJointsOnDeath = false

		deadPlayers[player.UserId] = nil
		ragdolledPlayers[player.UserId] = nil
		ragdollPositions[player.UserId] = nil
		
		-- Clean up revival prompt
		if revivalPrompts[player.UserId] then
			revivalPrompts[player.UserId]:Destroy()
			revivalPrompts[player.UserId] = nil
		end

		if deathTimers[player.UserId] then
			task.cancel(deathTimers[player.UserId])
			deathTimers[player.UserId] = nil
		end

		humanoid.Died:Connect(function()
			if ragdolledPlayers[player.UserId] or deadPlayers[player.UserId] then
				return
			end

			local success = RagdollModule.Ragdoll(character)

			if success then
				ragdolledPlayers[player.UserId] = true
				deadPlayers[player.UserId] = true
				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				if humanoidRootPart then
					ragdollPositions[player.UserId] = humanoidRootPart.Position
					
					-- Create revival proximity prompt
					local proximityPrompt = Instance.new("ProximityPrompt")
					proximityPrompt.Name = "RevivalPrompt"
					proximityPrompt.ActionText = "Revive Player"
					proximityPrompt.ObjectText = player.Name
					proximityPrompt.HoldDuration = 5
					proximityPrompt.MaxActivationDistance = 12 -- restored to ensure reliability
					proximityPrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
					proximityPrompt.RequiresLineOfSight = false -- ensure others can see/trigger even if parts obstruct
					proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E -- explicit "Hold E"
					proximityPrompt.UIOffset = Vector2.new(0, -12) -- nudge it slightly off-center
					proximityPrompt.Parent = humanoidRootPart
					revivalPrompts[player.UserId] = proximityPrompt
					
					-- Hide the prompt from the dead player themselves
					proximityPrompt:SetAttribute("HiddenFromPlayer", player.UserId)
					
					-- Handle revival attempts
					proximityPrompt.Triggered:Connect(function(reviverPlayer)
						if reviverPlayer == player then
							return -- Dead player can't revive themselves
						end
						
						-- Check if reviver has bandage or medkit
						local backpack = reviverPlayer:FindFirstChild("Backpack")
						local character = reviverPlayer.Character
						local hasBandage = (backpack and backpack:FindFirstChild("Bandage")) or (character and character:FindFirstChild("Bandage"))
						local hasMedkit = (backpack and backpack:FindFirstChild("Medkit")) or (character and character:FindFirstChild("Medkit"))
						
						if hasBandage or hasMedkit then
							-- Consume the healing item
							local healingTool = nil
							if hasBandage then
								healingTool = (backpack and backpack:FindFirstChild("Bandage")) or (character and character:FindFirstChild("Bandage"))
							else
								healingTool = (backpack and backpack:FindFirstChild("Medkit")) or (character and character:FindFirstChild("Medkit"))
							end
							
							if healingTool then
								healingTool:Destroy()
								
								-- Revive the player at their death location
								handleRespawnRequest(player)
							end
						else
							-- Show "requires healing item" message
							revivalFeedbackRemote:FireClient(reviverPlayer, "requires_healing_item")
						end
					end)
				end

				local allDead = areAllPlayersDead()

				if allDead then
					for _, deadPlayer in pairs(Players:GetPlayers()) do
						if deadPlayers[deadPlayer.UserId] then
							showUIRemote:FireClient(deadPlayer, 30)
							if deathTimers[deadPlayer.UserId] then
								task.cancel(deathTimers[deadPlayer.UserId])
							end
							deathTimers[deadPlayer.UserId] = task.delay(30, function()
								forceRespawn(deadPlayer)
							end)
						end
					end
				else
					showUIRemote:FireClient(player, 0)
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
	ragdolledPlayers[player.UserId] = nil
	deadPlayers[player.UserId] = nil
	ragdollPositions[player.UserId] = nil
	
	-- Clean up revival prompt
	if revivalPrompts[player.UserId] then
		revivalPrompts[player.UserId]:Destroy()
		revivalPrompts[player.UserId] = nil
	end

	if deathTimers[player.UserId] then
		task.cancel(deathTimers[player.UserId])
		deathTimers[player.UserId] = nil
	end
end

requestRespawnRemote.OnServerEvent:Connect(handleRespawnRequest)

for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
