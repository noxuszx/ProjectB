-- src/server/food/FoodConsumptionServer.server.lua
-- Handles server-side food consumption logic
-- Integrates with centralized PlayerStatsManager for hunger system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local PlayerStatsManager = require(script.Parent.Parent.player.PlayerStatsManager)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)

-- Get ConsumeFood RemoteEvent (defined in default.project.json)
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local consumeFoodRemote = remotesFolder:WaitForChild("ConsumeFood")

local FoodConsumptionServer = {}

local Config = {
	MaxInteractionDistance = 15,
}

function FoodConsumptionServer.init()
	if EconomyConfig.Debug.Enabled then print("[FoodConsumptionServer] Initializing server-side food consumption...") end
	consumeFoodRemote.OnServerEvent:Connect(FoodConsumptionServer.onConsumeFoodRequest)
	if EconomyConfig.Debug.Enabled then print("[FoodConsumptionServer] Server-side food consumption ready!") end
end

function FoodConsumptionServer.onConsumeFoodRequest(player, foodInstance)
	if EconomyConfig.Debug.Enabled then
		print("[FoodConsumptionServer] Request from", player.Name, "for", foodInstance and foodInstance.Name or "nil")
	end
	if not FoodConsumptionServer.validateConsumptionRequest(player, foodInstance) then
		return
	end
	
	local foodType = foodInstance:GetAttribute("FoodType")
	local hungerValue = foodInstance:GetAttribute("HungerValue") or 0
	local isCooked = foodInstance:GetAttribute("IsCooked") or false
	FoodConsumptionServer.consumeFood(player, foodInstance, hungerValue, isCooked)
	
	if EconomyConfig.Debug.Enabled then
		print("[FoodConsumptionServer]", player.Name, "consumed", foodType, "(+" .. hungerValue, "hunger)")
	end
end

function FoodConsumptionServer.validateConsumptionRequest(player, foodInstance)
	if not player or not player.Character or not player.Character.PrimaryPart then
		warn("[FoodConsumptionServer] Invalid player or character for", player and player.Name or "unknown")
		return false
	end
	
	if not foodInstance or not foodInstance.Parent then
		warn("[FoodConsumptionServer] Invalid food instance for", player.Name)
		return false
	end
	
	if not CollectionService:HasTag(foodInstance, CollectionServiceTags.CONSUMABLE) then
		warn("[FoodConsumptionServer] Food instance not tagged as consumable for", player.Name)
		return false
	end
	
	local playerPosition = player.Character.PrimaryPart.Position
	local foodPosition
	if foodInstance:IsA("Model") and foodInstance.PrimaryPart then
		foodPosition = foodInstance.PrimaryPart.Position
	elseif foodInstance:IsA("BasePart") then
		foodPosition = foodInstance.Position
	else
		warn("[FoodConsumptionServer] Unsupported food instance type for", player.Name, foodInstance.ClassName)
		return false
	end
	local distance = (playerPosition - foodPosition).Magnitude
	
	if distance > Config.MaxInteractionDistance then
		warn("[FoodConsumptionServer] Food too far away for", player.Name, "(distance:", distance .. ")")
		return false
	end
	
	return true
end

function FoodConsumptionServer.consumeFood(player, foodInstance, hungerValue, isCooked)
	local success = PlayerStatsManager.AddHunger(player, hungerValue)
	
	if not success then
		warn("[FoodConsumptionServer] Failed to add hunger for", player.Name)
		return
	end
	FoodConsumptionServer.createConsumptionEffects(player, foodInstance, hungerValue, isCooked)
	foodInstance:Destroy()
	
	if EconomyConfig.Debug.Enabled then
		print("[FoodConsumptionServer]", player.Name, "consumed", foodInstance:GetAttribute("FoodType"), "(+" .. hungerValue .. " hunger)")
	end
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