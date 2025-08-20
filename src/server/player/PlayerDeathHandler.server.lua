-- src/server/player/PlayerDeathHandler.server.lua
-- Handles player death events and applies ragdoll physics

local Players 			   = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local TeleportService      = game:GetService("TeleportService")
local RagdollModule 	   = require(ReplicatedStorage.Shared.modules.RagdollModule)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local ToolGrantService      = require(script.Parent.Parent.services.ToolGrantService)
local ArenaManager           = require(script.Parent.Parent.events.ArenaManager)
local TeleportConfig         = require(ReplicatedStorage.Shared.config.TeleportConfig)

local deathRemotes 		   = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Death")
local showUIRemote 		   = deathRemotes:WaitForChild("ShowUI")
local requestRespawnRemote = deathRemotes:WaitForChild("RequestRespawn")
local revivalFeedbackRemote = deathRemotes:WaitForChild("RevivalFeedback")
local requestPurchaseRemote = deathRemotes:FindFirstChild("RequestPurchase") or Instance.new("RemoteEvent")
requestPurchaseRemote.Name = "RequestPurchase"
requestPurchaseRemote.Parent = deathRemotes
-- Bindable event for server-initiated revives (from DevProductService)
local serverReviveBindable = deathRemotes:FindFirstChild("ServerRevive") or Instance.new("BindableEvent")
serverReviveBindable.Name = "ServerRevive"
serverReviveBindable.Parent = deathRemotes

-- Optional: listen for Back to Lobby clicks from Victory/Death UI
local arenaFolder = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Arena")
local postGameChoice = arenaFolder and arenaFolder:FindFirstChild("PostGameChoice")
if postGameChoice and postGameChoice:IsA("RemoteEvent") then
	postGameChoice.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) == "table" and payload.choice == "lobby" then
			local lobbyId = TeleportConfig and TeleportConfig.LobbyPlaceId or 0
			if lobbyId == 0 then
				warn("[PlayerDeathHandler] LobbyPlaceId not configured in TeleportConfig")
				return
			end
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(lobbyId, { player })
			end)
			if not ok then
				warn("[PlayerDeathHandler] TeleportAsync back to lobby failed for", player and player.Name, err)
			end
		end
	end)
end

Players.CharacterAutoLoads = false

local PlayerDeathHandler   = {}
local ragdolledPlayers     = {}
local deadPlayers 		   = {}
local deathTimers 		   = {}
local ragdollPositions 	   = {}
local revivalPrompts	   = {}
local forcedTeleportScheduled = false -- prevent duplicate lobby teleports when timers fire

-- Safely cancel a pending task.delay thread if still cancellable
local function safeCancelTimer(timerThread)
	if not timerThread then return end
	-- Only attempt cancel if it's a coroutine and still suspended
	local okStatus, status = pcall(coroutine.status, timerThread)
	if okStatus and status == "suspended" then
		pcall(task.cancel, timerThread)
	end
end

-- Locate item template by name in ReplicatedStorage/Items (and subfolders)
local function getItemTemplateByName(itemName)
	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	if not itemsFolder then return nil end
	local template = itemsFolder:FindFirstChild(itemName)
	if template then return template end
	-- Common subfolder
	local weaponsFolder = itemsFolder:FindFirstChild("Weapons")
	if weaponsFolder then
		local t2 = weaponsFolder:FindFirstChild(itemName)
		if t2 then return t2 end
	end
	return nil
end

-- Spawn a world item from Items template and toss it slightly
local function spawnDroppedItemFromTemplate(itemName, position)
	local template = getItemTemplateByName(itemName)
	if not template then return nil end
	local inst = template:Clone()
	-- Place
	local placePos = position + Vector3.new(math.random(-3,3), math.random(2,5), math.random(-3,3))
	if inst:IsA("BasePart") then
		inst.CFrame = CFrame.new(placePos)
	elseif inst:IsA("Tool") then
		local handle = inst:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CFrame = CFrame.new(placePos)
		end
	elseif inst.PrimaryPart then
		inst:SetPrimaryPartCFrame(CFrame.new(placePos))
	else
		inst:MoveTo(placePos)
	end
	-- Parent under SpawnedItems if present for organization
	local spawnedFolder = workspace:FindFirstChild("SpawnedItems")
	inst.Parent = spawnedFolder or workspace
	-- Mark as tool grant so ToolGrantBinder attaches a prompt (event-driven, no polling)
	local toolName = nil
	if ToolGrantService.hasToolTemplate and ToolGrantService.hasToolTemplate(itemName) then
		toolName = itemName
	else
		-- Fallback to instance name; Binder will still try using this
		toolName = itemName
	end
	inst:SetAttribute("ToolName", toolName)
	CollectionServiceTags.addTag(inst, CollectionServiceTags.TOOL_GRANT)
	-- Tag basic drag/store behavior similar to ItemSpawner
	if inst:IsA("BasePart") then
		CollectionServiceTags.addTag(inst, CollectionServiceTags.DRAGGABLE)
		CollectionServiceTags.addTag(inst, CollectionServiceTags.WELDABLE)
	elseif inst:IsA("Tool") then
		local handle = inst:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			CollectionServiceTags.addTag(handle, CollectionServiceTags.DRAGGABLE)
			CollectionServiceTags.addTag(handle, CollectionServiceTags.WELDABLE)
		end
	elseif inst:IsA("Model") then
		local primary = inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
		if primary then
			CollectionServiceTags.addTag(primary, CollectionServiceTags.DRAGGABLE)
			CollectionServiceTags.addTag(primary, CollectionServiceTags.WELDABLE)
		end
	end
	-- Give some outward velocity if possible
	local mainPart = nil
	if inst:IsA("BasePart") then mainPart = inst end
	if inst:IsA("Tool") then mainPart = inst:FindFirstChild("Handle") end
	if inst:IsA("Model") then mainPart = inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart") end
	if mainPart and mainPart:IsA("BasePart") then
		pcall(function()
			mainPart.AssemblyLinearVelocity = Vector3.new(math.random(-12,12), math.random(10,18), math.random(-12,12))
			mainPart.AssemblyAngularVelocity = Vector3.new(math.random(-6,6), math.random(-6,6), math.random(-6,6))
		end)
	end
	return inst
end

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

local function cancelAllDeathTimers()
	for uid, timerThread in pairs(deathTimers) do
		safeCancelTimer(timerThread)
		deathTimers[uid] = nil
	end
	forcedTeleportScheduled = false
end

local function teleportAllPlayersToLobby()
	local lobbyId = TeleportConfig and TeleportConfig.LobbyPlaceId or 0
	if lobbyId == 0 then
		warn("[PlayerDeathHandler] TeleportConfig.LobbyPlaceId is not set")
		return
	end
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do table.insert(list, plr) end
	if #list == 0 then return end
	local ok, err = pcall(function()
		TeleportService:TeleportPartyAsync(lobbyId, list)
	end)
	if not ok then
		warn("[PlayerDeathHandler] TeleportPartyAsync failed:", err)
		for _, p in ipairs(list) do
			pcall(function() TeleportService:TeleportAsync(lobbyId, {p}) end)
		end
	end
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

	if deathTimers[player.UserId] then
		safeCancelTimer(deathTimers[player.UserId])
		deathTimers[player.UserId] = nil
	end

	deadPlayers		[player.UserId] = nil
	ragdolledPlayers[player.UserId] = nil
	ragdollPositions[player.UserId] = nil
	-- Clear any lingering heal cooldown on revive
	player:SetAttribute("HealCooldownUntil", nil)
	-- Notify Arena that this player is revived/alive again
	pcall(function()
		if ArenaManager and ArenaManager.NotifyPlayerRespawned then
			ArenaManager.NotifyPlayerRespawned(player)
		end
	end)
	
	-- Proactively stop global forced-return timers and update remaining dead players immediately
	cancelAllDeathTimers()
	for _, other in ipairs(Players:GetPlayers()) do
		if other and other.UserId and deadPlayers[other.UserId] then
			showUIRemote:FireClient(other, 0)
		end
	end
	
	-- Clean up revival prompt
	if revivalPrompts[player.UserId] then
		revivalPrompts[player.UserId]:Destroy()
		revivalPrompts[player.UserId] = nil
	end

	if spawnPosition then
		-- Set position immediately when character spawns and grant temporary invulnerability
		local connection
		connection = player.CharacterAdded:Connect(function(character)
			connection:Disconnect()
			local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
			humanoidRootPart.CFrame = CFrame.new(spawnPosition)

			-- Grant 5 seconds of invulnerability using Roblox's default ForceField
			local forceField = Instance.new("ForceField")
			forceField.Visible = true
			forceField.Parent = character
			task.delay(5, function()
				if forceField and forceField.Parent then
					forceField:Destroy()
				end
			end)
		end)
	else
		-- Even if we don't have a spawn position, still grant temporary invulnerability on revival
		local connection
		connection = player.CharacterAdded:Connect(function(character)
			connection:Disconnect()
			local forceField = Instance.new("ForceField")
			forceField.Visible = true
			forceField.Parent = character
			task.delay(5, function()
				if forceField and forceField.Parent then
					forceField:Destroy()
				end
			end)
		end)
	end
	
	player:LoadCharacter()
end


local function forceRespawn(player)
	if not player then return end
	if not deadPlayers[player.UserId] then
		return
	end
	handleRespawnRequest(player)
end

local function reviveAll(triggeringPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		if deadPlayers[p.UserId] then
			handleRespawnRequest(p)
		end
	end
end

local function onPlayerAdded(player)
	player:LoadCharacter()

		local function onCharacterAdded(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.BreakJointsOnDeath = false

			deadPlayers[player.UserId] = nil
			ragdolledPlayers[player.UserId] = nil
			ragdollPositions[player.UserId] = nil
			-- Clear any lingering heal cooldown on new character
			player:SetAttribute("HealCooldownUntil", nil)
			-- Someone is alive again: cancel any global forced-return timers
			cancelAllDeathTimers()
			-- Also update remaining dead players to show no-timer UI, since not all are dead anymore
			for _, other in ipairs(Players:GetPlayers()) do
				if other and other.UserId and deadPlayers[other.UserId] then
					showUIRemote:FireClient(other, 0)
				end
			end
		
			-- Clean up revival prompt
			if revivalPrompts[player.UserId] then
				revivalPrompts[player.UserId]:Destroy()
				revivalPrompts[player.UserId] = nil
			end

		if deathTimers[player.UserId] then
			safeCancelTimer(deathTimers[player.UserId])
			deathTimers[player.UserId] = nil
		end

		humanoid.Died:Connect(function()
			if ragdolledPlayers[player.UserId] or deadPlayers[player.UserId] then
				return
			end

			-- Drop all Roblox Tools from Character and Backpack as world items from ReplicatedStorage/Items
			pcall(function()
				local origin = (character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart.Position)
					or (character.PrimaryPart and character.PrimaryPart.Position) or Vector3.new()
				-- Detach equipped tools
				pcall(function() humanoid:UnequipTools() end)
				-- Collect tools from Character
				local charTools = {}
				for _, child in ipairs(character:GetChildren()) do
					if child:IsA("Tool") then table.insert(charTools, child) end
				end
				for _, tool in ipairs(charTools) do
					spawnDroppedItemFromTemplate(tool.Name, origin)
					tool:Destroy()
				end
				-- Collect tools from Roblox Backpack
				local rbBackpack = player:FindFirstChild("Backpack")
				if rbBackpack then
					local packTools = {}
					for _, child in ipairs(rbBackpack:GetChildren()) do
						if child:IsA("Tool") then table.insert(packTools, child) end
					end
					for _, tool in ipairs(packTools) do
						spawnDroppedItemFromTemplate(tool.Name, origin)
						tool:Destroy()
					end
				end
			end)

			local success = RagdollModule.Ragdoll(character)

			if success then
				ragdolledPlayers[player.UserId] = true
				deadPlayers[player.UserId] = true
				-- Notify Arena that this player is downed (ragdolled)
				pcall(function()
					if ArenaManager and ArenaManager.NotifyPlayerDowned then
						ArenaManager.NotifyPlayerDowned(player)
					end
				end)
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

					-- Create an always-on-top red highlight on the body (visible to others only)
					local highlight = Instance.new("Highlight")
					highlight.Name = "DeathHighlight"
					highlight.Adornee = character -- highlight entire character
					highlight.FillColor = Color3.fromRGB(255, 60, 60)
					highlight.OutlineColor = Color3.fromRGB(255, 120, 120)
					highlight.FillTransparency = 0.6
					highlight.OutlineTransparency = 0
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Parent = character
					highlight:SetAttribute("HiddenFromPlayer", player.UserId)

					-- Create a floating name/"Downed" label above the body
					local billboard = Instance.new("BillboardGui")
					billboard.Name = "DeathBillboard"
					billboard.Adornee = humanoidRootPart
					billboard.AlwaysOnTop = true
					billboard.Size = UDim2.new(0, 140, 0, 36)
					billboard.StudsOffset = Vector3.new(0, 3, 0)
					billboard.Parent = humanoidRootPart
					billboard:SetAttribute("HiddenFromPlayer", player.UserId)

					local label = Instance.new("TextLabel")
					label.Name = "Text"
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.Text = player.Name
					label.TextColor3 = Color3.new(1, 0.85, 0.85)
					label.TextStrokeTransparency = 0.4
					label.FontFace = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Light)
					label.TextScaled = true
					label.Parent = billboard
					
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
					local seconds = (TeleportConfig and TeleportConfig.ForcedReturnSeconds) or 15
					for _, deadPlayer in pairs(Players:GetPlayers()) do
						if deadPlayers[deadPlayer.UserId] then
							showUIRemote:FireClient(deadPlayer, seconds)
							if deathTimers[deadPlayer.UserId] then
								safeCancelTimer(deathTimers[deadPlayer.UserId])
							end
							deathTimers[deadPlayer.UserId] = task.delay(seconds, function()
								if forcedTeleportScheduled then return end
								-- Only proceed if everyone is still dead at timer end
								if areAllPlayersDead() then
									forcedTeleportScheduled = true
									teleportAllPlayersToLobby()
								end
							end)
						end
					end
				else
					-- Someone is still alive: show no-timer Death UI for this player and cancel any running forced timers
					showUIRemote:FireClient(player, 0)
					cancelAllDeathTimers()
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
		safeCancelTimer(deathTimers[player.UserId])
		deathTimers[player.UserId] = nil
	end
end

requestRespawnRemote.OnServerEvent:Connect(handleRespawnRequest)

-- Listen for server initiated revives (developer products)
serverReviveBindable.Event:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local t = payload.type
	local p = payload.player
	if t == "SELF_REVIVE" and p then
		forceRespawn(p)
	elseif t == "REVIVE_ALL" then
		reviveAll(p)
	end
end)

for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
