-- src/server/economy/BuyZoneHandler.server.lua
-- Handles buy zone management and automatic item spawning

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)
local CS_tags =
	require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)



local buyZoneItems = {}

local function selectRandomItem()
	local availableItems = EconomyConfig.BuyableItems
	if #availableItems == 0 then
		return nil
	end

	local totalWeight = 0
	for _, itemData in pairs(availableItems) do
		totalWeight = totalWeight + itemData.SpawnWeight
	end

	local randomValue = math.random() * totalWeight
	local selectedItem = nil
	local currentWeight = 0

	for _, itemData in pairs(availableItems) do
		currentWeight = currentWeight + itemData.SpawnWeight
		if randomValue <= currentWeight then
			selectedItem = itemData
			break
		end
	end

	return selectedItem or availableItems[1]
end

local function spawnItemAtBuyZone(buyZone)
	local selectedItem = selectRandomItem()
	if not selectedItem then
		warn("[BuyZoneHandler] No items available to spawn")
		return
	end

	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	if not itemsFolder then
		warn("[BuyZoneHandler] Items folder not found in ReplicatedStorage")
		return
	end

	local itemModel = itemsFolder:FindFirstChild(selectedItem.ItemName)
	if not itemModel then
		warn(
			"[BuyZoneHandler] Item",
			selectedItem.ItemName,
			"not found in Items folder"
		)
		return
	end

	local clonedItem = itemModel:Clone()
	clonedItem.Parent = workspace
	local spawnPosition = buyZone.Position + Vector3.new(0, 1, 0)

	if clonedItem.PrimaryPart then
		clonedItem:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
	else
		local firstPart = clonedItem:FindFirstChildOfClass("Part")
		if firstPart then
			firstPart.Position = spawnPosition
		else
			warn("[BuyZoneHandler] No parts found in cloned item!")
		end
	end

	CS_tags.addTag(clonedItem, CS_tags.DRAGGABLE)
	CS_tags.addTag(clonedItem, CS_tags.WELDABLE)
	CS_tags.addTag(clonedItem, CS_tags.STORABLE)

	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Name = "BuyPrompt"
	proximityPrompt.ActionText = "Buy " .. selectedItem.ItemName
	proximityPrompt.ObjectText = selectedItem.Cost .. " coins"
	proximityPrompt.HoldDuration = 0.5
	proximityPrompt.MaxActivationDistance = 8
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.Style = Enum.ProximityPromptStyle.Default

	local mainPart = clonedItem.PrimaryPart
	if not mainPart then
		mainPart =
			clonedItem:FindFirstChildOfClass(
				"Part"
			) or clonedItem:FindFirstChildOfClass("MeshPart")
	end

	if mainPart then

		proximityPrompt.Parent = mainPart
		proximityPrompt:SetAttribute("ItemName", selectedItem.ItemName)
		proximityPrompt:SetAttribute("ItemCost", selectedItem.Cost)
		proximityPrompt:SetAttribute("BuyZone", buyZone.Name)
	else
		warn(
			"[BuyZoneHandler] Could not find part to attach ProximityPrompt to!"
		)
		proximityPrompt:Destroy()
	end

	buyZoneItems[buyZone] = clonedItem

	return clonedItem
end

local function setupBuyZone(buyZone)
	if not buyZone:IsA("Part") and not buyZone:IsA("MeshPart") then
		warn(
			"[BuyZoneHandler] Buy zone",
			buyZone.Name,
			"is not a Part or MeshPart"
		)
		return
	end

	if buyZoneItems[buyZone] then return end
	spawnItemAtBuyZone(buyZone)

	buyZone.AncestryChanged:Connect(function()
		if not buyZone.Parent then
			if buyZoneItems[buyZone] then
				buyZoneItems[buyZone] = nil
			end
		end
	end)
end


local function onBuyZoneAdded(buyZone)
	setupBuyZone(buyZone)
end

local function onBuyZoneRemoved(buyZone)
	if buyZoneItems[buyZone] then
		buyZoneItems[buyZone] = nil
	end
end

local function getAllBuyZones()
	return CollectionService:GetTagged("BUY_ZONE")
end

local function getSpawnedItem(buyZone)
	return buyZoneItems[buyZone]
end

local function onProximityPromptTriggered(promptObject, player)
	if promptObject.Name ~= "BuyPrompt" then return end
	if not promptObject.Enabled then return end

	local itemName = promptObject:GetAttribute("ItemName")
	local itemCost = promptObject:GetAttribute("ItemCost")
	local buyZoneName = promptObject:GetAttribute("BuyZone")

	if not itemName or not itemCost then
		warn("[BuyZoneHandler] Missing item data on proximity prompt")
		return
	end

	local itemPart = promptObject.Parent
	local itemModel = itemPart.Parent

	if not itemModel or not itemModel:IsA("Model") then
		warn("[BuyZoneHandler] Could not find item model for purchase")
		return
	end

	local EconomyService = require(script.Parent.Parent.services.EconomyService)
	if not EconomyService.canAfford(player, itemCost) then return end

	if EconomyService.removeMoney(player, itemCost) then
		promptObject:Destroy()

		local buyZoneForRespawn = nil
		for buyZone, spawnedItem in pairs(buyZoneItems) do
			if spawnedItem == itemModel then
				buyZoneForRespawn = buyZone
				buyZoneItems[buyZone] = nil
				break
			end
		end

		-- The item remains in the world as a regular draggable object
		-- Player can now drag it, store it, weld it, etc.

		-- TODO: New items will spawn during specific times of day via time-based system
		-- For now, no instant respawning - buy zones become empty after purchase
	end
end

local function init()
	local buyZones = CollectionService:GetTagged("BUY_ZONE")

	for _, buyZone in pairs(buyZones) do
		onBuyZoneAdded(buyZone)
	end

	CollectionService:GetInstanceAddedSignal("BUY_ZONE"):Connect(onBuyZoneAdded)
	CollectionService:GetInstanceRemovedSignal("BUY_ZONE"):Connect(
		onBuyZoneRemoved
	)

	local ProximityPromptService = game:GetService("ProximityPromptService")
	ProximityPromptService.PromptTriggered:Connect(onProximityPromptTriggered)
end

-- Public API
local BuyZoneHandler = {
	getAllBuyZones = getAllBuyZones,
	getSpawnedItem = getSpawnedItem,
}

init()

return BuyZoneHandler
