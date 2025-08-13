-- src/server/economy/BuyZoneHandler.server.lua
-- Handles buy zone management and automatic item spawning

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local buyZoneItems = {}

local function ensureShopFolder()
	local folder = workspace:FindFirstChild("ShopItems")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ShopItems"
		folder.Parent = workspace
	end
	return folder
end

local function parseAllowedCategories(buyZone)
	local attr = buyZone:GetAttribute("BuyZoneCategory")
	if not attr or attr == "" then
		return nil
	end
	local allowed = {}
	for token in string.gmatch(string.lower(tostring(attr)), "[^,%s]+") do
		allowed[token] = true
	end
	return allowed
end

local function findItemConfig(itemName)
	for _, itemConfig in pairs(EconomyConfig.BuyableItems) do
		if itemConfig.ItemName == itemName then
			return itemConfig
		end
	end
	return nil
end

local function attachUsePrompt(itemModel, itemConfig)
	local actionText, objectText, useType

	if itemConfig.Type == "Tool" then
		actionText 		= "Equip " .. itemConfig.ItemName
		objectText 		= "Tool"
		useType 		= "GrantTool"
	elseif itemConfig.Type == "Ammo" then
		actionText 		= "Collect " .. itemConfig.ItemName .. " (+" .. itemConfig.AmmoAmount .. ")"
		objectText 		= "Ammo"
		useType 		= "AddAmmo"
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
	usePrompt.MaxActivationDistance = EconomyConfig.Zones.BuyZone.ProximityRange or 8
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
		if EconomyConfig.Debug and EconomyConfig.Debug.Enabled then
			print("[BuyZoneHandler] Attached UsePrompt to", itemConfig.ItemName, "- Type:", itemConfig.Type)
		end
	else
		warn("[BuyZoneHandler] Could not find part to attach UsePrompt to!")
		usePrompt:Destroy()
	end
end

-- Select an item from a filtered list, honoring RandomSpawnChance
local function selectItem(filteredItems)
	if #filteredItems == 0 then
		return nil
	end
	local useRandom = true
	if
		EconomyConfig.Zones
		and EconomyConfig.Zones.BuyZone
		and (typeof(EconomyConfig.Zones.BuyZone.RandomSpawnChance) == "boolean")
	then
		useRandom = EconomyConfig.Zones.BuyZone.RandomSpawnChance
	end
	if not useRandom then
		return filteredItems[1]
	end
	local totalWeight = 0
	for _, itemData in ipairs(filteredItems) do
		totalWeight += (itemData.SpawnWeight or 1)
	end
	local randomValue = math.random() * totalWeight
	local currentWeight = 0
	for _, itemData in ipairs(filteredItems) do
		currentWeight += (itemData.SpawnWeight or 1)
		if randomValue <= currentWeight then
			return itemData
		end
	end
	return filteredItems[1]
end

local function getItemsFolder()
	-- Maintain current behavior: look in ReplicatedStorage.Items
	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	return itemsFolder
end

-- Find a non-Tool display template for the given item name
local function findDisplayTemplateForItem(itemName)
	local itemsFolder = getItemsFolder()
	if not itemsFolder then return nil end

	-- Prefer exact name that is NOT a Tool
	local candidate = itemsFolder:FindFirstChild(itemName)
	if candidate and not candidate:IsA("Tool") then
		return candidate
	end
	-- Try common suffixes
	local altNames = { itemName .. "_Model", itemName .. "_Display" }
	for _, alt in ipairs(altNames) do
		local altChild = itemsFolder:FindFirstChild(alt)
		if altChild and not altChild:IsA("Tool") then
			return altChild
		end
	end
	-- Try a Displays subfolder if present
	local displays = itemsFolder:FindFirstChild("Displays")
	if displays then
		local disp = displays:FindFirstChild(itemName) or displays:FindFirstChild(itemName .. "_Model") or displays:FindFirstChild(itemName .. "_Display")
		if disp and not disp:IsA("Tool") then
			return disp
		end
	end
	-- Try Food subfolder
	local foodFolder = itemsFolder:FindFirstChild("Food")
	if foodFolder then
		local food = foodFolder:FindFirstChild(itemName)
			or foodFolder:FindFirstChild(itemName .. "_Model")
			or foodFolder:FindFirstChild(itemName .. "_Display")
		if food and not food:IsA("Tool") then
			return food
		end
	end
	return nil
end

local function itemCategoryMatches(itemConfig, allowed)
	if not allowed then
		return true -- no filter
	end
	-- allowed keys are lowercased
	local category = itemConfig.Category and string.lower(itemConfig.Category) or ""
	if allowed["all"] then
		return true
	end
	return category ~= "" and allowed[category] == true
end

local function buildFilteredItemList(buyZone)
	local allowed = parseAllowedCategories(buyZone)
	local filtered = {}
	for _, item in ipairs(EconomyConfig.BuyableItems) do
		if itemCategoryMatches(item, allowed) then
			table.insert(filtered, item)
		end
	end
	return filtered
end

local function spawnItemAtBuyZone(buyZone)
	local candidates = buildFilteredItemList(buyZone)
	local selectedItem = selectItem(candidates)
	if not selectedItem then
		warn("[BuyZoneHandler] No items available to spawn for zone:", buyZone.Name)
		return
	end

	local itemsFolder = getItemsFolder()
	if not itemsFolder then
		warn("[BuyZoneHandler] Items folder not found in ReplicatedStorage")
		return
	end

	local template = findDisplayTemplateForItem(selectedItem.ItemName)
	if not template then
		warn("[BuyZoneHandler] No display/model template found for item:", selectedItem.ItemName, "(tools are not spawned)")
		return
	end

	local clonedItem = template:Clone()
	clonedItem.Parent = ensureShopFolder()

	local spawnHeight = (
		EconomyConfig.Zones
		and EconomyConfig.Zones.BuyZone
		and EconomyConfig.Zones.BuyZone.SpawnHeight
	) or 1
	local spawnPosition = buyZone.Position + Vector3.new(0, spawnHeight, 0)

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
	proximityPrompt.MaxActivationDistance = (
		EconomyConfig.Zones
		and EconomyConfig.Zones.BuyZone
		and EconomyConfig.Zones.BuyZone.ProximityRange
	) or 8
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

	-- Cleanup mapping if item is removed from workspace
	clonedItem.AncestryChanged:Connect(function()
		if not clonedItem:IsDescendantOf(workspace) then
			if buyZoneItems[buyZone] == clonedItem then
				buyZoneItems[buyZone] = nil
			end
		end
	end)

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
	-- Debounce to prevent double-spend
	promptObject.Enabled = false

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
		if itemPart.Parent == workspace or itemPart.Parent == ensureShopFolder() then
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
		-- Re-enable prompt if purchase not completed
		if promptObject and promptObject.Parent then
			promptObject.Enabled = true
		end
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

		-- Attach UsePrompt for Tool/Ammo types based on config, or enable consumption for Food
		local itemConfig = findItemConfig(itemName)
		if itemConfig then
			if itemConfig.Type == "Tool" or itemConfig.Type == "Ammo" then
				attachUsePrompt(spawnedRoot, itemConfig)
			elseif (itemConfig.Category and string.lower(itemConfig.Category) == "food") then
				-- Make purchased food consumable now
				CollectionServiceTags.addTag(spawnedRoot, CollectionServiceTags.CONSUMABLE)
				-- Ensure expected attributes exist for server logic (non-destructive defaults)
				if spawnedRoot:GetAttribute("FoodType") == nil then
					spawnedRoot:SetAttribute("FoodType", itemConfig.ItemName)
				end
				if spawnedRoot:GetAttribute("HungerValue") == nil then
					spawnedRoot:SetAttribute("HungerValue", 10)
				end
			end
		end

		-- Item remains in the world; buy zone stays empty until time-based respawn (future)
	else
		-- Failed to remove money; re-enable
		if promptObject and promptObject.Parent then
			promptObject.Enabled = true
		end
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
