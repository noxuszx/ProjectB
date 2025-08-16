local RP = game:GetService("ReplicatedStorage")

local WaterBottleService = require(game.ServerScriptService.Server.food.WaterBottleService)


local remotes = RP:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = RP
end

-- Reference pre-defined remotes (create if missing)
local drinkWaterRemote = remotes:FindFirstChild("DrinkWater") or Instance.new("RemoteEvent")
drinkWaterRemote.Name = "DrinkWater"
drinkWaterRemote.Parent = remotes

local updateBottleStateRemote = remotes:FindFirstChild("UpdateBottleState") or Instance.new("RemoteEvent")
updateBottleStateRemote.Name = "UpdateBottleState"
updateBottleStateRemote.Parent = remotes

local requestCurrentUsesRemote = remotes:FindFirstChild("RequestCurrentUses") or Instance.new("RemoteEvent")
requestCurrentUsesRemote.Name = "RequestCurrentUses"
requestCurrentUsesRemote.Parent = remotes

local refillWaterBottleRemote = remotes:FindFirstChild("RefillWaterBottle") or Instance.new("RemoteEvent")
refillWaterBottleRemote.Name = "RefillWaterBottle"
refillWaterBottleRemote.Parent = remotes

local function onDrinkWater(player)
	WaterBottleService.Drink(player)
end

local function onRefillRequest(player)
	WaterBottleService.Refill(player)
end

local function onRequestCurrentUses(player)
	WaterBottleService.SyncToClient(player)
end

-- Wire up remotes
if drinkWaterRemote and drinkWaterRemote.OnServerEvent then
	drinkWaterRemote.OnServerEvent:Connect(onDrinkWater)
end
if requestCurrentUsesRemote and requestCurrentUsesRemote.OnServerEvent then
	requestCurrentUsesRemote.OnServerEvent:Connect(onRequestCurrentUses)
end
if refillWaterBottleRemote and refillWaterBottleRemote.OnServerEvent then
	refillWaterBottleRemote.OnServerEvent:Connect(onRefillRequest)
end
