-- src/server/economy/BuyZoneHandler.server.lua
-- Handles buy zone management and automatic item spawning

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local buyZoneItems = {}

-- Helper function to find item config by ItemName
local function findItemConfig(itemName)
	for _, itemConfig in pairs(EconomyConfig.BuyableItems) do
		if itemConfig.ItemName == itemName then
			return itemConfig
		end
	end
	return nil
end

-- Helper function to attach UsePrompt to purchased items
local function attachUsePrompt(itemModel, itemConfig)
	-- Determine prompt text based on item type
	local actionText, objectText, useType
	
	if itemConfig.Type == "Tool" then
		actionText = "Equip " .. itemConfig.ItemName
		objectText = "Tool"
		useType = "GrantTool"
	elseif itemConfig.Type == "Ammo" then
		actionText = "Collect " .. itemConfig.ItemName .. " (+" .. itemConfig.AmmoAmount .. ")"
		objectText = "Ammo"
		useType = "AddAmmo"
	else
		warn("[BuyZoneHandler] Unsupported item type for UsePrompt:", itemConfig.Type)
		return
	end
	
	-- Create UsePrompt
	local usePrompt = Instance.new("ProximityPrompt")
	usePrompt.Name = "UsePrompt"
	usePrompt.ActionText = actionText
	usePrompt.ObjectText = objectText
	usePrompt.HoldDuration = 0 -- Instant pickup
	usePrompt.MaxActivationDistance = 8
	usePrompt.RequiresLineOfSight = false
	usePrompt.Style = Enum.ProximityPromptStyle.Default
	
	-- Set attributes for ItemUseHandler routing
	usePrompt:SetAttribute("UseType", useType)
	usePrompt:SetAttribute("ItemName", itemConfig.ItemName)
	
	if itemConfig.Type == "Tool" then
		usePrompt:SetAttribute("ToolTemplate", itemConfig.GiveToolName)
	elseif itemConfig.Type == "Ammo" then
		usePrompt:SetAttribute("AmmoType", itemConfig.AmmoType)
		usePrompt:SetAttribute("AmmoAmount", itemConfig.AmmoAmount)
	end
	
	-- Find a part to host the prompt (same logic as BuyPrompt)
	local mainPart
	if itemModel:IsA("BasePart") then
		mainPart = itemModel
	else
		mainPart = itemModel.PrimaryPart
		if not mainPart then
			mainPart = itemModel:FindFirstChildOfClass("BasePart")
		end
	end
	
	if mainPart then
		usePrompt.Parent = mainPart
		print("[BuyZoneHandler] Attached UsePrompt to", itemConfig.ItemName, "- Type:", itemConfig.Type)
	else
		warn("[BuyZoneHandler] Could not find part to attach UsePrompt to!")
		usePrompt:Destroy()
	end
end

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
		warn("[BuyZoneHandler] Item", selectedItem.ItemName, "not found in Items folder")
		return
	end

	local clonedItem = itemModel:Clone()
	clonedItem.Parent = workspace
	local spawnPosition = buyZone.Position + Vector3.new(0, 1, 0)

	-- Position cloned item depending on its type
	if clonedItem:IsA("Model") then
		if clonedItem.PrimaryPart then
			clonedItem:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
		else
			local firstPart = clonedItem:FindFirstChildOfClass("BasePart")
			if firstPart then
				firstPart.CFrame = CFrame.new(spawnPosition)
			else
				warn("[BuyZoneHandler] Model has no PrimaryPart or BasePart child to position!")
			end
		end
	elseif clonedItem:IsA("BasePart") then
		-- MeshPart/Part directly under Items
		clonedItem.CFrame = CFrame.new(spawnPosition)
	else
		-- Fallback: try to find any BasePart descendant
		local firstDescPart = clonedItem:FindFirstChildOfClass("BasePart")
		if firstDescPart then
			firstDescPart.CFrame = CFrame.new(spawnPosition)
		else
			warn("[BuyZoneHandler] Could not position cloned item (no BasePart found):", clonedItem.Name)
		end
	end

	CollectionServiceTags.addTag(clonedItem, CollectionServiceTags.DRAGGABLE)
	CollectionServiceTags.addTag(clonedItem, CollectionServiceTags.WELDABLE)
	CollectionServiceTags.addTag(clonedItem, CollectionServiceTags.STORABLE)

	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Name = "BuyPrompt"
	proximityPrompt.ActionText = "Buy " .. selectedItem.ItemName
	proximityPrompt.ObjectText = selectedItem.Cost .. " coins"
	proximityPrompt.HoldDuration = 0.5
	proximityPrompt.MaxActivationDistance = 8
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.Style = Enum.ProximityPromptStyle.Default

	-- Choose a part to host the prompt
	local mainPart
	if clonedItem:IsA("BasePart") then
		mainPart = clonedItem
	else
		mainPart = clonedItem.PrimaryPart
		if not mainPart then
			mainPart = clonedItem:FindFirstChildOfClass("BasePart")
		end
	end

	if mainPart then
		proximityPrompt.Parent = mainPart
		proximityPrompt:SetAttribute("ItemName", selectedItem.ItemName)
		proximityPrompt:SetAttribute("ItemCost", selectedItem.Cost)
		proximityPrompt:SetAttribute("BuyZone", buyZone.Name)
	else
		warn("[BuyZoneHandler] Could not find part to attach ProximityPrompt to!")
		proximityPrompt:Destroy()
	end

	buyZoneItems[buyZone] = clonedItem

	return clonedItem
end

local function setupBuyZone(buyZone)
	if not buyZone:IsA("Part") and not buyZone:IsA("MeshPart") then
		warn("[BuyZoneHandler] Buy zone", buyZone.Name, "is not a Part or MeshPart")
		return
	end

	if buyZoneItems[buyZone] then
		return
	end
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
	return CollectionServiceTags.getLiveTagged("BUY_ZONE")
end

local function getSpawnedItem(buyZone)
	return buyZoneItems[buyZone]
end

local function onProximityPromptTriggered(promptObject, player)
	if promptObject.Name ~= "BuyPrompt" then
		return
	end
	if not promptObject.Enabled then
		return
	end

	local itemName = promptObject:GetAttribute("ItemName")
	local itemCost = promptObject:GetAttribute("ItemCost")
	local buyZoneName = promptObject:GetAttribute("BuyZone")

	if not itemName or not itemCost then
		warn("[BuyZoneHandler] Missing item data on proximity prompt")
		return
	end

	local itemPart = promptObject.Parent
	-- Determine the root of the spawned item: could be a Model or a BasePart in workspace
	local spawnedRoot
	if itemPart and itemPart:IsA("BasePart") then
		if itemPart.Parent == workspace then
			spawnedRoot = itemPart -- BasePart item
		else
			spawnedRoot = itemPart.Parent -- Likely a Model
		end
	end
	if not spawnedRoot then
		warn("[BuyZoneHandler] Could not resolve purchased item root")
		return
	end

	local EconomyService = require(script.Parent.Parent.services.EconomyService)
	if not EconomyService.canAfford(player, itemCost) then
		return
	end

	if EconomyService.removeMoney(player, itemCost) then
		-- Remove buy prompt and detach zone mapping
		promptObject:Destroy()

		for buyZone, spawnedItem in pairs(buyZoneItems) do
			if spawnedItem == spawnedRoot then
				buyZoneItems[buyZone] = nil
				break
			end
		end

		-- Attach UsePrompt for Tool/Ammo types based on config
		local itemConfig = findItemConfig(itemName)
		if itemConfig and (itemConfig.Type == "Tool" or itemConfig.Type == "Ammo") then
			attachUsePrompt(spawnedRoot, itemConfig)
		end

		-- Item remains in the world; buy zone stays empty until time-based respawn (future)
	end
end

local function init()
	local buyZones = CollectionServiceTags.getLiveTagged("BUY_ZONE")

	for _, buyZone in pairs(buyZones) do
		onBuyZoneAdded(buyZone)
	end

	CollectionService:GetInstanceAddedSignal("BUY_ZONE"):Connect(onBuyZoneAdded)
	CollectionService:GetInstanceRemovedSignal("BUY_ZONE"):Connect(onBuyZoneRemoved)

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
