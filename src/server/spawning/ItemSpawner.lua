-- src/server/spawning/ItemSpawner.lua
-- Server-side script for one-time world population with items
-- Handles batch processing of all ItemSpawnPoint tagged parts with performance optimizations

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ItemConfig             = require(ReplicatedStorage.Shared.config.ItemConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local ToolGrantService      = require(script.Parent.Parent.services.ToolGrantService)


local ItemSpawner   = {}
local availableItems = {}
local availableItemCount = 0

local spawnedItemsCount    = 0
local processedSpawnersCount = 0
local isPopulating = false

local SPAWN_TAG = "ItemSpawnPoint"
local SPAWN_TYPE_ATTRIBUTE = "SpawnType"
local EXTRA_SPAWN_TYPE_ATTRIBUTE = "ExtraSpawnType"
local SPAWN_EXACT_ATTRIBUTE = "SpawnExact"

local itemFolder = Instance.new("Folder")
itemFolder.Name = "SpawnedItems"
itemFolder.Parent = workspace

local function debugPrint() end

------------------------------------------------------------------------------------------------

local function discoverAvailableItems()

	local itemsFolder = ReplicatedStorage:FindFirstChild(ItemConfig.Settings.ItemsFolder)
	if not itemsFolder then
		warn("[ItemSpawner] Items folder not found in ReplicatedStorage:", ItemConfig.Settings.ItemsFolder)
		warn("[ItemSpawner] Please create a folder named '" .. ItemConfig.Settings.ItemsFolder .. "' in ReplicatedStorage")
		availableItems = {}
		availableItemCount = 0
		return
	end

	availableItems = {}
	local discoveredCount = 0
	local skippedItems = {}

	-- Function to scan items in a folder
	local function scanFolder(folder, folderName)

		for _, item in ipairs(folder:GetChildren()) do
			if item:IsA("MeshPart") or item:IsA("Tool") or item:IsA("Model") then
				local isValid = true
				local issues = {}

				local size
				if item:IsA("MeshPart") then
					size = item.Size
				elseif item:IsA("Tool") then
					local handle = item:FindFirstChild("Handle")
					if handle and handle:IsA("BasePart") then
						size = handle.Size
					else
						table.insert(issues, "No Handle found in Tool")
						isValid = false
					end
				elseif item:IsA("Model") then
					local anyPart = item.PrimaryPart or item:FindFirstChildOfClass("BasePart")
					if anyPart then
						size = anyPart.Size or Vector3.new(1,1,1)
					else
						table.insert(issues, "Model has no BasePart/PrimaryPart")
						isValid = false
					end
				end

				if size then
					if size.X > 50 or size.Y > 50 or size.Z > 50 then
						table.insert(issues, "Item too large (>50 studs)")
					elseif size.X < 0.1 or size.Y < 0.1 or size.Z < 0.1 then
						table.insert(issues, "Item too small (<0.1 studs)")
					end
				end

				if isValid then
					availableItems[item.Name] = item
					discoveredCount += 1
					debugPrint("Discovered item: " .. item.Name .. " (" .. item.ClassName .. ") from " .. folderName ..
						(#issues > 0 and " (warnings: " .. table.concat(issues, ", ") .. ")" or ""))
				else
					table.insert(skippedItems, {name = item.Name, issues = issues})
					debugPrint("Skipped invalid item: " .. item.Name .. " from " .. folderName .. " (issues: " .. table.concat(issues, ", ") .. ")")
				end
			else
				debugPrint("Skipped unsupported object: " .. item.Name .. " (" .. item.ClassName .. ") from " .. folderName .. " - Only MeshParts and Tools are supported")
			end
		end
	end

	scanFolder(itemsFolder, "Items")
	local weaponsFolder = itemsFolder:FindFirstChild("Weapons")
	if weaponsFolder then
		scanFolder(weaponsFolder, "Weapons")
	else
		debugPrint("Weapons subfolder not found - create ReplicatedStorage.Items.Weapons for weapon Tools")
	end

	availableItemCount = discoveredCount
	print("[ItemSpawner] Item discovery complete:")
	print("  - Valid items discovered:", discoveredCount)
	print("  - Items skipped:", #skippedItems)

	if #skippedItems > 0 then
		warn("[ItemSpawner] Skipped items with issues:")
		for _, skippedItem in ipairs(skippedItems) do
			warn("  - " .. skippedItem.name .. ": " .. table.concat(skippedItem.issues, ", "))
		end
	end
end

local function validateLootTables()
	debugPrint("Validating loot tables...")
	
	local missingItems = {}
	
	for spawnerType, config in pairs(ItemConfig.SpawnTypes) do
		for itemName, _ in pairs(config.PossibleLoot) do
			if not availableItems[itemName] then
				table.insert(missingItems, itemName)
			end
		end
	end
	
	if #missingItems > 0 then
		warn("[ItemSpawner] Missing items referenced in loot tables:", table.concat(missingItems, ", "))
	else
		debugPrint("All loot table items validated successfully")
	end
end

local function getRandomSpawnPosition(spawnerPart, existingPositions)
	local spawnerPosition = spawnerPart.Position
	local settings = ItemConfig.Settings
	existingPositions = existingPositions or {}

	-- If spawner requests exact placement, spawn centered on top of the spawner part
	local spawnExact = spawnerPart:GetAttribute(SPAWN_EXACT_ATTRIBUTE)
	if spawnExact == true then
		local topY = spawnerPosition.Y
		if spawnerPart:IsA("BasePart") then
			topY = spawnerPosition.Y + (spawnerPart.Size.Y / 2)
		end
		local exactPos = Vector3.new(
			spawnerPosition.X,
			topY + (settings.SpawnHeight or 0) + 0.5,
			spawnerPosition.Z
		)
		-- Track this position to reduce overlap if multiple items are spawned
		table.insert(existingPositions, exactPos)
		return exactPos
	end

	local probeHeight = settings.RaycastProbeHeight or 100
	local downLength = settings.RaycastDownLength or 200
	local minDistance = settings.MinSpawnSpacing or 2

	for attempt = 1, settings.MaxScatterAttempts do
		local angle = math.random() * 2 * math.pi
		local distance = math.random() * settings.ScatterRadius

		local randomX = math.cos(angle) * distance
		local randomZ = math.sin(angle) * distance

		local spawnPosition = Vector3.new(
			spawnerPosition.X + randomX,
			spawnerPosition.Y + settings.SpawnHeight,
			spawnerPosition.Z + randomZ
		)

		local tooClose = false
		for _, existingPos in ipairs(existingPositions) do
			local d = (spawnPosition - existingPos).Magnitude
			if d < minDistance then
				tooClose = true
				break
			end
		end

		if not tooClose then
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = { spawnerPart, itemFolder }

			local raycastResult = workspace:Raycast(
				Vector3.new(spawnPosition.X, spawnerPosition.Y, spawnPosition.Z),
				Vector3.new(0, -downLength, 0),
				raycastParams
			)

			if raycastResult then
				spawnPosition = Vector3.new(
					spawnPosition.X,
					raycastResult.Position.Y + 1,
					spawnPosition.Z
				)
			end

			table.insert(existingPositions, spawnPosition)
			debugPrint("Found valid spawn position at " .. tostring(spawnPosition) .. " (attempt " .. attempt .. ")")
			return spawnPosition
		end
	end

	local fallbackPosition = Vector3.new(
		spawnerPosition.X,
		spawnerPosition.Y + settings.SpawnHeight,
		spawnerPosition.Z
	)

	debugPrint("Using fallback position after " .. settings.MaxScatterAttempts .. " attempts")
	return fallbackPosition
end

local function performLootRoll(spawnerConfig)
	local rolledItems = {}
	local numRolls = math.random(spawnerConfig.MinRolls, spawnerConfig.MaxRolls)
	debugPrint("Performing " .. numRolls .. " loot rolls")

	for _ = 1, numRolls do
		local itemRolled = false
		local weightedItems = {}
		local totalWeight = 0

		for itemName, chance in pairs(spawnerConfig.PossibleLoot) do
			if availableItems[itemName] then
				table.insert(weightedItems, {name = itemName, weight = chance * 100})
				totalWeight += (chance * 100)
			end
		end

		if #weightedItems == 0 then
			debugPrint("No available items for this spawner type")
			continue
		end

		local randomValue = math.random() * totalWeight
		local currentWeight = 0

		for _, itemData in ipairs(weightedItems) do
			currentWeight += itemData.weight
			if randomValue <= currentWeight then
				table.insert(rolledItems, itemData.name)
				debugPrint("Rolled item: " .. itemData.name .. " (chance: " .. itemData.weight/100 .. ")")
				itemRolled = true
				break
			end
		end

		if not itemRolled then
			debugPrint("Empty roll - no item spawned for this roll")
		end
	end

	-- Filter duplicates unless AllowDuplicates is true
	if spawnerConfig.AllowDuplicates then
		-- Return all rolled items including duplicates
		return rolledItems
	else
		-- Keep unique items as previous behavior
		local uniqueItems = {}
		local seen = {}
		for _, itemName in ipairs(rolledItems) do
			if not seen[itemName] then
				table.insert(uniqueItems, itemName)
				seen[itemName] = true
			end
		end
		
		return uniqueItems
	end
end

local function spawnItem(itemName, position)
	local itemTemplate = availableItems[itemName]
	if not itemTemplate then
		warn("[ItemSpawner] Item template not found:", itemName)
		return nil
	end
	
	local newItem = itemTemplate:Clone()
	if newItem:IsA("MeshPart") then
		newItem.CFrame = CFrame.new(position)

	elseif newItem:IsA("Tool") then

		local handle = newItem:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CFrame = CFrame.new(position)
		else
			warn("[ItemSpawner] Tool no Handle:", itemName)
		end
	elseif newItem.PrimaryPart then
		newItem:SetPrimaryPartCFrame(CFrame.new(position))
	else
		newItem:MoveTo(position)
	end
	
	newItem.Parent = itemFolder

	-- Copy all tags from template to spawned item, then add standard spawning tags
	local function copyTagsFromTemplate(template, spawned)
		for _, tag in pairs(CollectionService:GetTags(template)) do
			CollectionServiceTags.addTag(spawned, tag)
		end
	end
	
	-- Tag the spawned item based on its type
	if newItem:IsA("MeshPart") then
		-- Copy tags from template first
		copyTagsFromTemplate(itemTemplate, newItem)
		-- Then add standard spawning tags
		CollectionServiceTags.addTag(newItem, CollectionServiceTags.DRAGGABLE)
		CollectionServiceTags.addTag(newItem, CollectionServiceTags.WELDABLE)
		debugPrint("Tagged MeshPart as draggable: " .. itemName)
	elseif newItem:IsA("Tool") then
		-- Copy tags from template first
		copyTagsFromTemplate(itemTemplate, newItem)
		-- Tag only the handle/baseparts for tools
		local handle = newItem:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			-- Copy tags from template handle to spawned handle
			local templateHandle = itemTemplate:FindFirstChild("Handle")
			if templateHandle then
				copyTagsFromTemplate(templateHandle, handle)
			end
			CollectionServiceTags.addTag(handle, CollectionServiceTags.DRAGGABLE)
			CollectionServiceTags.addTag(handle, CollectionServiceTags.WELDABLE)
			debugPrint("Tagged Tool Handle as draggable: " .. itemName)
		end
	elseif newItem:IsA("Model") then
		-- Copy tags from template first
		copyTagsFromTemplate(itemTemplate, newItem)
		-- Tag all BasePart descendants using helper
		CollectionServiceTags.tagDescendants(newItem, CollectionServiceTags.DRAGGABLE)
		CollectionServiceTags.tagDescendants(newItem, CollectionServiceTags.WELDABLE)
		debugPrint("Tagged Model and its parts as draggable: " .. itemName)
	end

	-- If this spawned object should grant a Tool on pickup, mark it now
	local toolNameAttr = nil
	-- Priority: explicit attribute on template, config mapping, then heuristics
	if itemTemplate:GetAttribute("ToolName") then
		toolNameAttr = itemTemplate:GetAttribute("ToolName")
	elseif ItemConfig.ToolMappings and ItemConfig.ToolMappings[itemName] then
		toolNameAttr = ItemConfig.ToolMappings[itemName]
	else
		-- Heuristics: if template or spawned instance is flagged as a weapon/heal, or if a tool template exists
		local flaggedAsToolPickup = false
		local function isTrueAttr(inst, attrName)
			local v = inst:GetAttribute(attrName)
			return v == true or v == "true" or v == 1
		end
		flaggedAsToolPickup = isTrueAttr(itemTemplate, "weapons") or isTrueAttr(itemTemplate, "heals")
		if not flaggedAsToolPickup then
			flaggedAsToolPickup = isTrueAttr(newItem, "weapons") or isTrueAttr(newItem, "heals")
		end
		-- If explicitly flagged, prefer using the itemName unless a ToolName is already provided
		if flaggedAsToolPickup and not toolNameAttr then
			if ToolGrantService.hasToolTemplate and ToolGrantService.hasToolTemplate(itemName) then
				toolNameAttr = itemName
			end
		end
		-- As a final fallback, if a matching tool template exists with the same name, use it
		if not toolNameAttr and ToolGrantService.hasToolTemplate and ToolGrantService.hasToolTemplate(itemName) then
			toolNameAttr = itemName
		end
	end
	if toolNameAttr then
		newItem:SetAttribute("ToolName", toolNameAttr)
		CollectionServiceTags.addTag(newItem, CollectionServiceTags.TOOL_GRANT)
		-- Also attach a UsePrompt so it behaves like BuyZone pickups
		local mainPart
		if newItem:IsA("BasePart") then
			mainPart = newItem
		elseif newItem:IsA("Tool") then
			mainPart = newItem:FindFirstChild("Handle")
		elseif newItem:IsA("Model") then
			mainPart = newItem.PrimaryPart or newItem:FindFirstChildOfClass("BasePart")
		else
			mainPart = newItem:FindFirstChildOfClass("BasePart")
		end
		if mainPart then
			local usePrompt = Instance.new("ProximityPrompt")
			usePrompt.Name = "UsePrompt"
			usePrompt.ActionText = "Equip " .. tostring(toolNameAttr)
			usePrompt.ObjectText = "Tool"
			usePrompt.HoldDuration = 0
			usePrompt.MaxActivationDistance = 8
			usePrompt.RequiresLineOfSight = false
			usePrompt.Style = Enum.ProximityPromptStyle.Default
			-- Attributes used by ItemUseHandler
			usePrompt:SetAttribute("UseType", "GrantTool")
			usePrompt:SetAttribute("ToolTemplate", toolNameAttr)
			usePrompt.Parent = mainPart
		end
	end

	spawnedItemsCount += 1
	debugPrint("Spawned item: " .. itemName .. " (" .. newItem.ClassName .. ") at " .. tostring(position))

	return newItem
end

local function processForType(spawnerPart, typeName, usedPositions)
	if not typeName or typeName == "" then return 0 end
	local spawnerConfig = ItemConfig.SpawnTypes[typeName]
	if not spawnerConfig then
		warn("[ItemSpawner] Unknown spawn type:", typeName)
		return 0
	end
	debugPrint("Processing spawner type: " .. typeName .. " at " .. tostring(spawnerPart.Position))
	local itemsToSpawn = performLootRoll(spawnerConfig)
	local count = 0
	for _, itemName in ipairs(itemsToSpawn) do
		local spawnPosition = getRandomSpawnPosition(spawnerPart, usedPositions)
		if spawnItem(itemName, spawnPosition) then
			count += 1
		end
	end
	return count
end

local function processSpawner(spawnerPart)
	local primaryType = spawnerPart:GetAttribute(SPAWN_TYPE_ATTRIBUTE)
	if not primaryType then
		warn("[ItemSpawner] Spawner missing SpawnType attribute:", spawnerPart:GetFullName())
		return
	end

	local extraType = spawnerPart:GetAttribute(EXTRA_SPAWN_TYPE_ATTRIBUTE)
	local usedPositions = {}
	local totalSpawned = 0

	totalSpawned += processForType(spawnerPart, primaryType, usedPositions)
	totalSpawned += processForType(spawnerPart, extraType, usedPositions)

	processedSpawnersCount += 1
	debugPrint("Spawner processed. Items spawned: " .. totalSpawned)
end

-- Clear all spawned items
function ItemSpawner.ClearSpawnedItems()
	debugPrint("Clearing spawned items...")
	for _, child in ipairs(itemFolder:GetChildren()) do
		child:Destroy()
	end
	spawnedItemsCount = 0
	print("[ItemSpawner] All spawned items cleared!")
end

function ItemSpawner.PopulateWorld()
	if isPopulating then
		warn("[ItemSpawner] PopulateWorld is already running; skipping re-entry")
		return
	end
	isPopulating = true
	debugPrint("Starting world population...")
	
	-- Clear any existing spawned items first
	ItemSpawner.ClearSpawnedItems()
	
	spawnedItemsCount = 0
	processedSpawnersCount = 0
	
	discoverAvailableItems()
	validateLootTables()
	
	local spawnerParts = CollectionServiceTags.getLiveTagged(SPAWN_TAG)
	debugPrint("Found " .. #spawnerParts .. " spawner parts")
	
	if #spawnerParts == 0 then
		debugPrint("No spawner parts found. Make sure parts are tagged with: " .. SPAWN_TAG)
		isPopulating = false
		return
	end

	local batchSize = ItemConfig.Settings.SpawnerBatchSize or 50
	for i = 1, #spawnerParts, batchSize do
		for j = i, math.min(i + batchSize - 1, #spawnerParts) do
			local spawnerPart = spawnerParts[j]
			processSpawner(spawnerPart)
		end
		-- Yield to avoid long frame hitches
		task.wait()
	end
	
	print("[ItemSpawner] World population complete!")
	print("  - Processed spawners:", processedSpawnersCount)
	print("  - Total items spawned:", spawnedItemsCount)
	print("  - Available item types:", availableItemCount)
	isPopulating = false
end

-- Initialize the system (call this after world generation is complete)
function ItemSpawner.Initialize()
	-- For now, we'll populate immediately
	-- In a real implementation, this might be called by a world generation system
	ItemSpawner.PopulateWorld()
end

return ItemSpawner
