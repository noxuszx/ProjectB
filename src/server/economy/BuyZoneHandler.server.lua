-- src/server/economy/BuyZoneHandler.server.lua
-- Handles buy zone management and automatic item spawning

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)
local CS_tags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

-- Tracking
local buyZoneItems = {} -- Track which items are spawned at which zones

-- Select random item from buyable items using weighted selection
local function selectRandomItem()
	local availableItems = EconomyConfig.BuyableItems
	if #availableItems == 0 then
		return nil
	end
	
	-- Calculate weighted random selection
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
	
	return selectedItem or availableItems[1] -- Fallback to first item
end

-- Spawn an item at a buy zone
local function spawnItemAtBuyZone(buyZone)
	-- Select random item
	local selectedItem = selectRandomItem()
	if not selectedItem then
		warn("[BuyZoneHandler] No items available to spawn")
		return
	end
	
	-- Find the item in ReplicatedStorage.Items
	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	if not itemsFolder then
		warn("[BuyZoneHandler] Items folder not found in ReplicatedStorage")
		return
	end
	
	local itemModel = itemsFolder:FindFirstChild(selectedItem.ItemName)
	if not itemModel then
		warn("[BuyZoneHandler] Item", selectedItem.ItemName, "not found in Items folder")
		return
	end
	
	-- Clone and spawn the item
	local clonedItem = itemModel:Clone()
	clonedItem.Parent = workspace
	
	-- Position the item exactly 1 stud above the buy zone
	local spawnPosition = buyZone.Position + Vector3.new(0, 1, 0)
	
	if clonedItem.PrimaryPart then
		clonedItem:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
	else
		-- Fallback: position the first part found
		local firstPart = clonedItem:FindFirstChildOfClass("Part")
		if firstPart then
			firstPart.Position = spawnPosition
		else
			warn("[BuyZoneHandler] No parts found in cloned item!")
		end
	end
	
	-- Make the item draggable using proper tag format
	CS_tags.addTag(clonedItem, CS_tags.DRAGGABLE)
	CS_tags.addTag(clonedItem, CS_tags.WELDABLE)
	CS_tags.addTag(clonedItem, CS_tags.STORABLE)
	
	-- Add ProximityPrompt for buying
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Name = "BuyPrompt"
	proximityPrompt.ActionText = "Buy " .. selectedItem.ItemName
	proximityPrompt.ObjectText = selectedItem.Cost .. " coins"
	proximityPrompt.HoldDuration = 0.5 -- Half second hold to buy
	proximityPrompt.MaxActivationDistance = 8
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.Style = Enum.ProximityPromptStyle.Default
	
	-- Find the main part to attach the prompt to
	local mainPart = clonedItem.PrimaryPart
	if not mainPart then
		mainPart = clonedItem:FindFirstChildOfClass("Part") or clonedItem:FindFirstChildOfClass("MeshPart")
	end
	
	if mainPart then
		proximityPrompt.Parent = mainPart
		
		-- Store item data for purchase handling
		proximityPrompt:SetAttribute("ItemName", selectedItem.ItemName)
		proximityPrompt:SetAttribute("ItemCost", selectedItem.Cost)
		proximityPrompt:SetAttribute("BuyZone", buyZone.Name)
	else
		warn("[BuyZoneHandler] Could not find part to attach ProximityPrompt to!")
		proximityPrompt:Destroy()
	end
	
	-- Store reference to the spawned item
	buyZoneItems[buyZone] = clonedItem
	
	if EconomyConfig.Debug.Enabled then
		print("[BuyZoneHandler] Spawned", selectedItem.ItemName, "at buy zone", buyZone.Name)
	end
	
	return clonedItem
end

-- Set up a buy zone with automatic item spawning
local function setupBuyZone(buyZone)
	if not buyZone:IsA("Part") and not buyZone:IsA("MeshPart") then
		warn("[BuyZoneHandler] Buy zone", buyZone.Name, "is not a Part or MeshPart")
		return
	end
	
	-- Check if this buy zone already has an item spawned
	if buyZoneItems[buyZone] then
		return
	end
	
	-- Automatically spawn an item at this buy zone
	spawnItemAtBuyZone(buyZone)
	
	-- Clean up when buy zone is removed
	buyZone.AncestryChanged:Connect(function()
		if not buyZone.Parent then
			-- Clean up spawned item reference
			if buyZoneItems[buyZone] then
				buyZoneItems[buyZone] = nil
			end
		end
	end)
	
	if EconomyConfig.Debug.Enabled then
		print("[BuyZoneHandler] Set up buy zone with auto-spawn:", buyZone.Name)
	end
end

-- Monitor for new buy zones
local function onBuyZoneAdded(buyZone)
	setupBuyZone(buyZone)
end

local function onBuyZoneRemoved(buyZone)
	-- Clean up spawned item reference
	if buyZoneItems[buyZone] then
		buyZoneItems[buyZone] = nil
	end
	
	if EconomyConfig.Debug.Enabled then
		print("[BuyZoneHandler] Removed buy zone:", buyZone.Name)
	end
end

-- Get all buy zones (for client highlighting)
local function getAllBuyZones()
	return CollectionService:GetTagged("BUY_ZONE")
end

-- Get spawned item at a buy zone
local function getSpawnedItem(buyZone)
	return buyZoneItems[buyZone]
end

-- Handle proximity prompt purchases
local function onProximityPromptTriggered(promptObject, player)
	-- Check if this is a buy prompt
	if promptObject.Name ~= "BuyPrompt" then
		return
	end
	
	-- Check if prompt is still enabled (prevent double purchases)
	if not promptObject.Enabled then
		return
	end
	
	-- Get item data from prompt attributes
	local itemName = promptObject:GetAttribute("ItemName")
	local itemCost = promptObject:GetAttribute("ItemCost")
	local buyZoneName = promptObject:GetAttribute("BuyZone")
	
	if not itemName or not itemCost then
		warn("[BuyZoneHandler] Missing item data on proximity prompt")
		return
	end
	
	-- Get the item model (parent of the part containing the prompt)
	local itemPart = promptObject.Parent
	local itemModel = itemPart.Parent
	
	if not itemModel or not itemModel:IsA("Model") then
		warn("[BuyZoneHandler] Could not find item model for purchase")
		return
	end
	
	if EconomyConfig.Debug.Enabled then
		print("[BuyZoneHandler]", player.Name, "triggered buy prompt for", itemName, "costing", itemCost)
	end
	
	-- Get EconomyService and process purchase directly
	local EconomyService = require(script.Parent.Parent.services.EconomyService)
	
	-- Check if player can afford the item
	if not EconomyService.canAfford(player, itemCost) then
		if EconomyConfig.Debug.Enabled then
			print("[BuyZoneHandler]", player.Name, "cannot afford", itemName, "- costs", itemCost)
		end
		return
	end
	
	-- Process the purchase
	if EconomyService.removeMoney(player, itemCost) then
		-- Remove the ProximityPrompt to indicate item is purchased
		promptObject:Destroy()
		
		-- Find which buy zone this item belongs to and clear reference
		local buyZoneForRespawn = nil
		for buyZone, spawnedItem in pairs(buyZoneItems) do
			if spawnedItem == itemModel then
				buyZoneForRespawn = buyZone
				buyZoneItems[buyZone] = nil -- Clear reference so new item can spawn
				break
			end
		end
		
		-- The item remains in the world as a regular draggable object
		-- Player can now drag it, store it, weld it, etc.
		
		-- TODO: New items will spawn during specific times of day via time-based system
		-- For now, no instant respawning - buy zones become empty after purchase
		
		if EconomyConfig.Debug.Enabled then
			print("[BuyZoneHandler]", player.Name, "successfully bought", itemName, "for", itemCost, "coins - item remains draggable")
		end
	else
		if EconomyConfig.Debug.Enabled then
			print("[BuyZoneHandler] Failed to remove money for", player.Name)
		end
	end
end

-- Initialize the handler
local function init()
	-- Set up existing buy zones (auto-spawn items)
	local buyZones = CollectionService:GetTagged("BUY_ZONE")
	
	for _, buyZone in pairs(buyZones) do
		onBuyZoneAdded(buyZone)
	end
	
	-- Monitor for new/removed buy zones
	CollectionService:GetInstanceAddedSignal("BUY_ZONE"):Connect(onBuyZoneAdded)
	CollectionService:GetInstanceRemovedSignal("BUY_ZONE"):Connect(onBuyZoneRemoved)
	
	-- Handle proximity prompt purchases
	local ProximityPromptService = game:GetService("ProximityPromptService")
	ProximityPromptService.PromptTriggered:Connect(onProximityPromptTriggered)
end

-- Public API
local BuyZoneHandler = {
	getAllBuyZones = getAllBuyZones,
	getSpawnedItem = getSpawnedItem,
}

-- Start the handler
init()

return BuyZoneHandler