-- src/server/spawning/ItemSpawner.lua
-- Server-side script for one-time world population with items
-- Handles batch processing of all ItemSpawnPoint tagged parts with performance optimizations

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)


local ItemSpawner = {}
local availableItems = {}
local spawnedItemsCount = 0
local processedSpawnersCount = 0
local SPAWN_TAG = "ItemSpawnPoint"
local SPAWN_TYPE_ATTRIBUTE = "SpawnType"

local itemFolder = Instance.new("Folder")
itemFolder.Name = "SpawnedItems"
itemFolder.Parent = workspace
local function debugPrint() end



local function discoverAvailableItems()


	local itemsFolder = ReplicatedStorage:FindFirstChild(ItemConfig.Settings.ItemsFolder)
	if not itemsFolder then
		warn("[ItemSpawner] Items folder not found in ReplicatedStorage:", ItemConfig.Settings.ItemsFolder)
		warn("[ItemSpawner] Please create a folder named '" .. ItemConfig.Settings.ItemsFolder .. "' in ReplicatedStorage")
		return
	end

	availableItems = {}
	local discoveredCount = 0
	local skippedItems = {}

	-- Function to scan items in a folder
	local function scanFolder(folder, folderName)

		for _, item in pairs(folder:GetChildren()) do
			if item:IsA("MeshPart") or item:IsA("Tool") then
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
					discoveredCount = discoveredCount + 1
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

	print("[ItemSpawner] Item discovery complete:")
	print("  - Valid items discovered:", discoveredCount)
	print("  - Items skipped:", #skippedItems)

	if #skippedItems > 0 then
		warn("[ItemSpawner] Skipped items with issues:")
		for _, skippedItem in pairs(skippedItems) do
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
		local minDistance = 2

		for _, existingPos in pairs(existingPositions) do
			local distance = (spawnPosition - existingPos).Magnitude
			if distance < minDistance then
				tooClose = true
				break
			end
		end

		if not tooClose then
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = {spawnerPart}

			local raycastResult = workspace:Raycast(
				Vector3.new(spawnPosition.X, spawnPosition.Y + 10, spawnPosition.Z),
				Vector3.new(0, -20, 0),
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

	for roll = 1, numRolls do
		local itemRolled = false
		local weightedItems = {}
		local totalWeight = 0

		for itemName, chance in pairs(spawnerConfig.PossibleLoot) do
			if availableItems[itemName] then
				table.insert(weightedItems, {name = itemName, weight = chance * 100})
				totalWeight = totalWeight + (chance * 100)
			end
		end

		if #weightedItems == 0 then
			debugPrint("No available items for this spawner type")
			continue
		end

		local randomValue = math.random() * totalWeight
		local currentWeight = 0

		for _, itemData in pairs(weightedItems) do
			currentWeight = currentWeight + itemData.weight
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

	local uniqueItems = {}
	local seen = {}
	for _, itemName in pairs(rolledItems) do
		if not seen[itemName] then
			table.insert(uniqueItems, itemName)
			seen[itemName] = true
		end
	end

	return uniqueItems
end

local function spawnItem(itemName, position)
	local itemTemplate = availableItems[itemName]
	if not itemTemplate then
		warn("[ItemSpawner] Item template not found:", itemName)
		return nil
	end
	
	local newItem = itemTemplate:Clone()
	
	-- Position the item based on its type
	if newItem:IsA("MeshPart") then
		-- MeshParts are positioned directly
		newItem.CFrame = CFrame.new(position)
	elseif newItem:IsA("Tool") then
		-- Tools are positioned via their Handle
		local handle = newItem:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CFrame = CFrame.new(position)
		else
			warn("[ItemSpawner] Tool spawned without Handle:", itemName)
		end
	elseif newItem.PrimaryPart then
		-- Fallback for Models (if any still exist)
		newItem:SetPrimaryPartCFrame(CFrame.new(position))
	else
		-- Final fallback
		newItem:MoveTo(position)
	end
	
newItem.Parent = itemFolder

    -- Tag the spawned item based on its type
	if newItem:IsA("MeshPart") then
		-- MeshParts are regular items - draggable and weldable
		CollectionServiceTags.addTag(newItem, CollectionServiceTags.DRAGGABLE)
		CollectionServiceTags.addTag(newItem, CollectionServiceTags.WELDABLE)
		debugPrint("Tagged MeshPart as draggable: " .. itemName)
	elseif newItem:IsA("Tool") then
		-- This is a regular tool - make it draggable
		local handle = newItem:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			CollectionServiceTags.addTag(handle, CollectionServiceTags.DRAGGABLE)
			CollectionServiceTags.addTag(handle, CollectionServiceTags.WELDABLE)
			debugPrint("Tagged Tool Handle as draggable: " .. itemName)
		end
		CollectionServiceTags.addTag(newItem, CollectionServiceTags.DRAGGABLE)
		CollectionServiceTags.addTag(newItem, CollectionServiceTags.WELDABLE)
	elseif newItem:IsA("Model") then
		-- For Models, tag all BaseParts within them
		for _, descendant in pairs(newItem:GetDescendants()) do
			if descendant:IsA("BasePart") then
				CollectionServiceTags.addTag(descendant, CollectionServiceTags.DRAGGABLE)
				CollectionServiceTags.addTag(descendant, CollectionServiceTags.WELDABLE)
			end
		end
		-- Also tag the Model itself
		CollectionServiceTags.addTag(newItem, CollectionServiceTags.DRAGGABLE)
		CollectionServiceTags.addTag(newItem, CollectionServiceTags.WELDABLE)
		debugPrint("Tagged Model and its parts as draggable: " .. itemName)
	end

	spawnedItemsCount = spawnedItemsCount + 1
	debugPrint("Spawned item: " .. itemName .. " (" .. newItem.ClassName .. ") at " .. tostring(position))

	return newItem
end

local function processSpawner(spawnerPart)
	local spawnType = spawnerPart:GetAttribute(SPAWN_TYPE_ATTRIBUTE)
	if not spawnType then
		warn("[ItemSpawner] Spawner missing SpawnType attribute:", spawnerPart:GetFullName())
		return
	end

	local spawnerConfig = ItemConfig.SpawnTypes[spawnType]
	if not spawnerConfig then
		warn("[ItemSpawner] Unknown spawn type:", spawnType)
		return
	end

	debugPrint("Processing spawner: " .. spawnType .. " at " .. tostring(spawnerPart.Position))
	local itemsToSpawn = performLootRoll(spawnerConfig)
	local usedPositions = {}

	for _, itemName in pairs(itemsToSpawn) do
		local spawnPosition = getRandomSpawnPosition(spawnerPart, usedPositions)
		spawnItem(itemName, spawnPosition)
	end

	processedSpawnersCount = processedSpawnersCount + 1
	debugPrint("Spawner processed. Items spawned: " .. #itemsToSpawn)
end

-- Clear all spawned items
function ItemSpawner.ClearSpawnedItems()
	debugPrint("Clearing spawned items...")
	for _, child in pairs(itemFolder:GetChildren()) do
		child:Destroy()
	end
	spawnedItemsCount = 0
	print("[ItemSpawner] All spawned items cleared!")
end

function ItemSpawner.PopulateWorld()
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
		return
	end
	
	for _, spawnerPart in pairs(spawnerParts) do
		processSpawner(spawnerPart)
	end
	
	print("[ItemSpawner] World population complete!")
	print("  - Processed spawners:", processedSpawnersCount)
	print("  - Total items spawned:", spawnedItemsCount)
	print("  - Available item types:", #availableItems)
end

-- Initialize the system (call this after world generation is complete)
function ItemSpawner.Initialize()
	-- For now, we'll populate immediately
	-- In a real implementation, this might be called by a world generation system
	ItemSpawner.PopulateWorld()
end

return ItemSpawner
