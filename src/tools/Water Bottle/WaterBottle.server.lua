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

print("[WaterBottle] Found refill bindable:", refillBindable and refillBindable.Name or "nil")

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
		print("[WaterBottle]", player.Name, "tried to drink but bottle is empty (0/5 uses)")
		return
	end
	
	playerBottleUses[player.UserId] = usesLeft - 1
	local newUsesLeft = playerBottleUses[player.UserId]
	
	local success = PSM.AddThirst(player, THIRST_RESTORE_AMOUNT)
	
	if success then
		print("[WaterBottle]", player.Name, "drank water and restored", THIRST_RESTORE_AMOUNT, "thirst -", newUsesLeft .. "/" .. MAX_BOTTLE_USES, "uses left")
		updateBottleVisual(player, newUsesLeft)
	else
		playerBottleUses[player.UserId] = usesLeft
		warn("[WaterBottle] Failed to restore thirst for", player.Name)
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
	print("[WaterBottle]", player.Name, "refilled bottle to", MAX_BOTTLE_USES .. "/" .. MAX_BOTTLE_USES, "uses")
	updateBottleVisual(player, MAX_BOTTLE_USES)
	return true
end

-- Handle refill requests from proximity prompts
local function onRefillRequest(player)
	print("[WaterBottle] Received refill request for", player.Name)
	local success = refillBottle(player)
	print("[WaterBottle] Refill result:", success)
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
	print("[WaterBottle]", player.Name, "requested current bottle state:", uses .. "/" .. MAX_BOTTLE_USES, "uses")
end

drinkWaterRemote.OnServerEvent:Connect(onDrinkWater)
requestCurrentUsesRemote.OnServerEvent:Connect(onRequestCurrentUses)
refillWaterBottleRemote.OnServerEvent:Connect(onRefillRequest)

print("[WaterBottle] Connecting to refill bindable...")
refillBindable.Event:Connect(onRefillRequest)
print("[WaterBottle] Connected to refill bindable!")