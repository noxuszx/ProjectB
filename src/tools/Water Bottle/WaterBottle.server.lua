local RP = game:GetService("ReplicatedStorage")
local PSM = require(game.ServerScriptService.Server.player.PlayerStatsManager)

local THIRST_RESTORE_AMOUNT = 50
local MAX_BOTTLE_USES = 5

-- Track bottle uses for each player
local playerBottleUses = {}

local remotes = RP:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = RP
end

local drinkWaterRemote = remotes:FindFirstChild("DrinkWater")
if not drinkWaterRemote then
	drinkWaterRemote = Instance.new("RemoteEvent")
	drinkWaterRemote.Name = "DrinkWater"
	drinkWaterRemote.Parent = remotes
end

-- Remote to update bottle visual state
local updateBottleStateRemote = remotes:FindFirstChild("UpdateBottleState")
if not updateBottleStateRemote then
	updateBottleStateRemote = Instance.new("RemoteEvent")
	updateBottleStateRemote.Name = "UpdateBottleState"
	updateBottleStateRemote.Parent = remotes
end

-- Remote to request current bottle uses (for equip state persistence)
local requestCurrentUsesRemote = remotes:FindFirstChild("RequestCurrentUses")
if not requestCurrentUsesRemote then
	requestCurrentUsesRemote = Instance.new("RemoteEvent")
	requestCurrentUsesRemote.Name = "RequestCurrentUses"
	requestCurrentUsesRemote.Parent = remotes
end

-- Remote for refill system
local refillWaterBottleRemote = remotes:FindFirstChild("RefillWaterBottle")
if not refillWaterBottleRemote then
	refillWaterBottleRemote = Instance.new("RemoteEvent")
	refillWaterBottleRemote.Name = "RefillWaterBottle"
	refillWaterBottleRemote.Parent = remotes
end

-- BindableEvent for server-to-server communication
local refillBindable = RP:FindFirstChild("RefillWaterBottleBindable")
if not refillBindable then
	refillBindable = Instance.new("BindableEvent")
	refillBindable.Name = "RefillWaterBottleBindable"
	refillBindable.Parent = RP
end


local function updateBottleVisual(player, usesLeft)
	updateBottleStateRemote:FireClient(player, usesLeft)
end

local function onDrinkWater(player)
	if not player.Character then
		return
	end

	local tool = player.Character:FindFirstChild("Water Bottle")
	if not tool then
		return
	end
	
	if not playerBottleUses[player.UserId] then
		playerBottleUses[player.UserId] = MAX_BOTTLE_USES
	end
	
	local usesLeft = playerBottleUses[player.UserId]
	
	if usesLeft <= 0 then
		return
	end
	
	playerBottleUses[player.UserId] = usesLeft - 1
	local newUsesLeft = playerBottleUses[player.UserId]
	
	local success = PSM.AddThirst(player, THIRST_RESTORE_AMOUNT)
	
	if success then
		updateBottleVisual(player, newUsesLeft)
	else
		playerBottleUses[player.UserId] = usesLeft
	end
end

local function refillBottle(player)
	if not player then
		return false
	end
	
	-- Check if player has water bottle equipped
	if not player.Character or not player.Character:FindFirstChild("Water Bottle") then
		return false
	end
	
	playerBottleUses[player.UserId] = MAX_BOTTLE_USES
	updateBottleVisual(player, MAX_BOTTLE_USES)
	return true
end

-- Handle refill requests from proximity prompts
local function onRefillRequest(player)
	refillBottle(player)
end

game.Players.PlayerRemoving:Connect(function(player)
	playerBottleUses[player.UserId] = nil
end)

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(2)
		if character:FindFirstChild("Water Bottle") then
			playerBottleUses[player.UserId] = MAX_BOTTLE_USES
			updateBottleVisual(player, MAX_BOTTLE_USES)
		end
	end)
end)

local function onRequestCurrentUses(player)
	local uses = playerBottleUses[player.UserId] or MAX_BOTTLE_USES
	updateBottleVisual(player, uses)
end

drinkWaterRemote.OnServerEvent:Connect(onDrinkWater)
requestCurrentUsesRemote.OnServerEvent:Connect(onRequestCurrentUses)
refillWaterBottleRemote.OnServerEvent:Connect(onRefillRequest)

refillBindable.Event:Connect(onRefillRequest)
