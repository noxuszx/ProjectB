-- WaterRefillManager.lua
-- Manages water refill points using CollectionService tags
-- Players can refill water bottles at tagged water sources

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

-- Create BindableEvent for server-to-server communication with water bottle
local refillBindable = ReplicatedStorage:FindFirstChild("RefillWaterBottleBindable")
if not refillBindable then
	refillBindable = Instance.new("BindableEvent")
	refillBindable.Name = "RefillWaterBottleBindable"
	refillBindable.Parent = ReplicatedStorage
end

print("[WaterRefillManager] Created/found refill bindable:", refillBindable.Name)

local WaterRefillManager = {}
local refillPrompts = {}
local playerConnections = {} -- Track player equipment connections

local function updatePromptVisibility(part, player, hasWaterBottle)
	local prompt = refillPrompts[part]
	if not prompt then
		return
	end
	
	-- Show prompt only to players who have water bottle equipped
	if hasWaterBottle then
		prompt.Enabled = true
	else
		prompt.Enabled = false
	end
end

local function checkAllPlayersForBottle(part)
	-- Check all players and update prompt visibility accordingly
	local anyPlayerHasBottle = false
	
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("Water Bottle") then
			anyPlayerHasBottle = true
			break
		end
	end
	
	local prompt = refillPrompts[part]
	if prompt then
		prompt.Enabled = anyPlayerHasBottle
	end
end

local function createProximityPrompt(part)
	if refillPrompts[part] then
		return
	end
	
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Refill"
	prompt.ObjectText = "Water Bottle"
	prompt.HoldDuration = 2.0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = part
	
	-- Store reference
	refillPrompts[part] = prompt
	
	local function onPromptTriggered(player)
		-- Use BindableEvent to communicate with water bottle script
		print("[WaterRefillManager] Firing refill bindable for", player.Name)
		refillBindable:Fire(player)
		print("[WaterRefillManager]", player.Name, "refilled water bottle at", part.Name)
	end
	
	prompt.Triggered:Connect(onPromptTriggered)
	
	-- Check initial state
	checkAllPlayersForBottle(part)
	
	print("[WaterRefillManager] Created refill prompt on", part.Name)
end

local function removeProximityPrompt(part)
	local prompt = refillPrompts[part]
	if prompt then
		prompt:Destroy()
		refillPrompts[part] = nil
		print("[WaterRefillManager] Removed refill prompt from", part.Name)
	end
end

local function updateAllPrompts()
	for part, _ in pairs(refillPrompts) do
		checkAllPlayersForBottle(part)
	end
end

local function setupPlayerTracking(player)
	local function onCharacterAdded(character)
		if playerConnections[player] then
			for _, connection in pairs(playerConnections[player]) do
				connection:Disconnect()
			end
		end
		playerConnections[player] = {}
		local function onChildAdded(child)
			if child.Name == "Water Bottle" then
				updateAllPrompts()
			end
		end
		
		local function onChildRemoved(child)
			if child.Name == "Water Bottle" then
				updateAllPrompts()
			end
		end
		
		playerConnections[player][#playerConnections[player] + 1] = character.ChildAdded:Connect(onChildAdded)
		playerConnections[player][#playerConnections[player] + 1] = character.ChildRemoved:Connect(onChildRemoved)
		
		-- Initial update
		updateAllPrompts()
	end
	
	if player.Character then
		onCharacterAdded(player.Character)
	end
	
	player.CharacterAdded:Connect(onCharacterAdded)
end

local function cleanupPlayerTracking(player)
	if playerConnections[player] then
		for _, connection in pairs(playerConnections[player]) do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end
	
	-- Update prompts since player left
	updateAllPrompts()
end

function WaterRefillManager.init()
	print("[WaterRefillManager] Initializing water refill system...")
	
	-- Set up existing tagged parts
	local taggedParts = CollectionService:GetTagged(CollectionServiceTags.WATER_REFILL_SOURCE)
	for _, part in pairs(taggedParts) do
		createProximityPrompt(part)
	end
	
	-- Listen for new tagged parts
	CollectionService:GetInstanceAddedSignal(CollectionServiceTags.WATER_REFILL_SOURCE):Connect(createProximityPrompt)
	
	-- Listen for removed tagged parts
	CollectionService:GetInstanceRemovedSignal(CollectionServiceTags.WATER_REFILL_SOURCE):Connect(removeProximityPrompt)
	
	-- Set up player tracking for existing players
	for _, player in pairs(Players:GetPlayers()) do
		setupPlayerTracking(player)
	end
	
	-- Set up player tracking for new players
	Players.PlayerAdded:Connect(setupPlayerTracking)
	Players.PlayerRemoving:Connect(cleanupPlayerTracking)
	
	print("[WaterRefillManager] Water refill system initialized with", #taggedParts, "water sources")
	return true
end

function WaterRefillManager.shutdown()
	-- Clean up all prompts
	for part, prompt in pairs(refillPrompts) do
		prompt:Destroy()
	end
	refillPrompts = {}
	
	-- Clean up all player connections
	for player, connections in pairs(playerConnections) do
		for _, connection in pairs(connections) do
			connection:Disconnect()
		end
	end
	playerConnections = {}
	
	print("[WaterRefillManager] Water refill system shutdown")
end

return WaterRefillManager