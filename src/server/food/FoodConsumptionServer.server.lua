-- src/server/food/FoodConsumptionServer.server.lua
-- Handles server-side food consumption logic
-- Manages hunger system and food item removal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Create RemoteEvent for food consumption
local consumeFoodRemote = ReplicatedStorage:FindFirstChild("ConsumeFood")
if not consumeFoodRemote then
	consumeFoodRemote = Instance.new("RemoteEvent")
	consumeFoodRemote.Name = "ConsumeFood"
	consumeFoodRemote.Parent = ReplicatedStorage
end

local FoodConsumptionServer = {}

-- Configuration
local Config = {
	MaxInteractionDistance = 15, -- Slightly larger than client for lag tolerance
	MaxHunger = 100, -- Maximum hunger value
	HungerDecayRate = 1, -- Hunger lost per minute (future implementation)
}

-- Player hunger data
local playerHunger = {}

-- Initialize the server-side consumption system
function FoodConsumptionServer.init()
	print("[FoodConsumptionServer] Initializing server-side food consumption...")
	
	-- Set up remote event handling
	consumeFoodRemote.OnServerEvent:Connect(FoodConsumptionServer.onConsumeFoodRequest)
	
	-- Set up player data management
	Players.PlayerAdded:Connect(FoodConsumptionServer.onPlayerAdded)
	Players.PlayerRemoving:Connect(FoodConsumptionServer.onPlayerRemoving)
	
	-- Initialize existing players
	for _, player in pairs(Players:GetPlayers()) do
		FoodConsumptionServer.onPlayerAdded(player)
	end
	
	print("[FoodConsumptionServer] Server-side food consumption ready!")
end

-- Handle new player joining
function FoodConsumptionServer.onPlayerAdded(player)
	-- Initialize hunger data
	playerHunger[player] = Config.MaxHunger
	
	print("[FoodConsumptionServer] Initialized hunger for", player.Name)
end

-- Handle player leaving
function FoodConsumptionServer.onPlayerRemoving(player)
	-- Clean up hunger data
	playerHunger[player] = nil
end

-- Handle food consumption requests from clients
function FoodConsumptionServer.onConsumeFoodRequest(player, foodModel)
	-- Validate request
	if not FoodConsumptionServer.validateConsumptionRequest(player, foodModel) then
		return
	end
	
	-- Get food properties
	local foodType = foodModel:GetAttribute("FoodType")
	local hungerValue = foodModel:GetAttribute("HungerValue") or 0
	local isCooked = foodModel:GetAttribute("IsCooked") or false
	
	-- Consume the food
	FoodConsumptionServer.consumeFood(player, foodModel, hungerValue, isCooked)
	
	print("[FoodConsumptionServer]", player.Name, "consumed", foodType, "(+" .. hungerValue, "hunger)")
end

-- Validate that a consumption request is legitimate
function FoodConsumptionServer.validateConsumptionRequest(player, foodModel)
	-- Check if player exists and has character
	if not player or not player.Character or not player.Character.PrimaryPart then
		warn("[FoodConsumptionServer] Invalid player or character for", player and player.Name or "unknown")
		return false
	end
	
	-- Check if food model exists and is valid
	if not foodModel or not foodModel.Parent or not foodModel.PrimaryPart then
		warn("[FoodConsumptionServer] Invalid food model for", player.Name)
		return false
	end
	
	-- Check if model is actually consumable
	if not CollectionService:HasTag(foodModel, "Consumable") then
		warn("[FoodConsumptionServer] Food model not tagged as consumable for", player.Name)
		return false
	end
	
	-- Check distance
	local playerPosition = player.Character.PrimaryPart.Position
	local foodPosition = foodModel.PrimaryPart.Position
	local distance = (playerPosition - foodPosition).Magnitude
	
	if distance > Config.MaxInteractionDistance then
		warn("[FoodConsumptionServer] Food too far away for", player.Name, "(distance:", distance .. ")")
		return false
	end
	
	return true
end

-- Actually consume the food and apply effects
function FoodConsumptionServer.consumeFood(player, foodModel, hungerValue, isCooked)
	-- Get current hunger
	local currentHunger = playerHunger[player] or 0
	
	-- Apply hunger restoration
	local newHunger = math.min(Config.MaxHunger, currentHunger + hungerValue)
	playerHunger[player] = newHunger
	
	-- Create consumption effects
	FoodConsumptionServer.createConsumptionEffects(player, foodModel, hungerValue, isCooked)
	
	-- Remove the food model
	foodModel:Destroy()
	
	-- Update player's displayed hunger (if you have a GUI system)
	FoodConsumptionServer.updatePlayerHungerDisplay(player, newHunger)
	
	print("[FoodConsumptionServer]", player.Name, "hunger:", currentHunger, "->", newHunger)
end

-- Create visual/audio effects for food consumption
function FoodConsumptionServer.createConsumptionEffects(player, foodModel, hungerValue, isCooked)
	-- You could create particle effects, sounds, etc. here
	-- For now, just create a simple message
	
	local foodType = foodModel:GetAttribute("FoodType") or "Food"
	local state = isCooked and "Cooked" or "Raw"
	
	-- Create a temporary GUI message (simple approach)
	local message = state .. " " .. foodType .. " consumed! (+" .. hungerValue .. " hunger)"
	
	-- You could send this to a GUI system or create floating text
	-- For now, we'll just print it locally
	print("[FoodConsumption]", player.Name, "->", message)
end

-- Update player's hunger display (placeholder for GUI system)
function FoodConsumptionServer.updatePlayerHungerDisplay(player, newHunger)
	-- This is where you'd update a hunger bar GUI
	-- For now, we'll just store it in leaderstats for debugging
	
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	
	local hungerStat = leaderstats:FindFirstChild("Hunger")
	if not hungerStat then
		hungerStat = Instance.new("IntValue")
		hungerStat.Name = "Hunger"
		hungerStat.Parent = leaderstats
	end
	
	hungerStat.Value = math.floor(newHunger)
end

-- Get player's current hunger (utility function)
function FoodConsumptionServer.getPlayerHunger(player)
	return playerHunger[player] or 0
end

-- Set player's hunger (utility function)
function FoodConsumptionServer.setPlayerHunger(player, hunger)
	playerHunger[player] = math.max(0, math.min(Config.MaxHunger, hunger))
	FoodConsumptionServer.updatePlayerHungerDisplay(player, playerHunger[player])
end

-- Initialize the system
FoodConsumptionServer.init()

return FoodConsumptionServer