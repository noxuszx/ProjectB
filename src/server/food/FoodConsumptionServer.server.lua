-- src/server/food/FoodConsumptionServer.server.lua
-- Handles server-side food consumption logic
-- Integrates with centralized PlayerStatsManager for hunger system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local PlayerStatsManager = require(script.Parent.Parent.player.PlayerStatsManager)

local consumeFoodRemote = ReplicatedStorage:FindFirstChild("ConsumeFood")
if not consumeFoodRemote then
	consumeFoodRemote = Instance.new("RemoteEvent")
	consumeFoodRemote.Name = "ConsumeFood"
	consumeFoodRemote.Parent = ReplicatedStorage
end

local FoodConsumptionServer = {}

local Config = {
	MaxInteractionDistance = 15,
}

function FoodConsumptionServer.init()
	print("[FoodConsumptionServer] Initializing server-side food consumption...")
	consumeFoodRemote.OnServerEvent:Connect(FoodConsumptionServer.onConsumeFoodRequest)
	print("[FoodConsumptionServer] Server-side food consumption ready!")
end

function FoodConsumptionServer.onConsumeFoodRequest(player, foodModel)
	if not FoodConsumptionServer.validateConsumptionRequest(player, foodModel) then
		return
	end
	
	local foodType = foodModel:GetAttribute("FoodType")
	local hungerValue = foodModel:GetAttribute("HungerValue") or 0
	local isCooked = foodModel:GetAttribute("IsCooked") or false
	FoodConsumptionServer.consumeFood(player, foodModel, hungerValue, isCooked)
	
	print("[FoodConsumptionServer]", player.Name, "consumed", foodType, "(+" .. hungerValue, "hunger)")
end

function FoodConsumptionServer.validateConsumptionRequest(player, foodModel)
	if not player or not player.Character or not player.Character.PrimaryPart then
		warn("[FoodConsumptionServer] Invalid player or character for", player and player.Name or "unknown")
		return false
	end
	
	if not foodModel or not foodModel.Parent or not foodModel.PrimaryPart then
		warn("[FoodConsumptionServer] Invalid food model for", player.Name)
		return false
	end
	
	if not CollectionService:HasTag(foodModel, "Consumable") then
		warn("[FoodConsumptionServer] Food model not tagged as consumable for", player.Name)
		return false
	end
	
	local playerPosition = player.Character.PrimaryPart.Position
	local foodPosition = foodModel.PrimaryPart.Position
	local distance = (playerPosition - foodPosition).Magnitude
	
	if distance > Config.MaxInteractionDistance then
		warn("[FoodConsumptionServer] Food too far away for", player.Name, "(distance:", distance .. ")")
		return false
	end
	
	return true
end

function FoodConsumptionServer.consumeFood(player, foodModel, hungerValue, isCooked)
	local success = PlayerStatsManager.AddHunger(player, hungerValue)
	
	if not success then
		warn("[FoodConsumptionServer] Failed to add hunger for", player.Name)
		return
	end
	FoodConsumptionServer.createConsumptionEffects(player, foodModel, hungerValue, isCooked)
	foodModel:Destroy()
	
	print("[FoodConsumptionServer]", player.Name, "consumed", foodModel:GetAttribute("FoodType"), "(+" .. hungerValue .. " hunger)")
end

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


function FoodConsumptionServer.getPlayerStats(player)
	return PlayerStatsManager.GetPlayerStats(player)
end

FoodConsumptionServer.init()

return FoodConsumptionServer