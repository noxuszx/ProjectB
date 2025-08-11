-- src/server/events/EventItemSpawner.lua
-- Handles spawning of arena event items (Ankh and Orbs) on designated pedestals
-- Items spawn directly on top of tagged pedestal parts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local CS_tags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local EventItemSpawner = {}

-- Item to pedestal mapping
local ITEM_PEDESTAL_MAP = {
	Ankh = CS_tags.PYRAMID_PEDESTAL,
	Orb1 = CS_tags.BATTLE_TOWER_PEDESTAL_1,
	Orb2 = CS_tags.BATTLE_TOWER_PEDESTAL_2,
	Orb3 = CS_tags.BATTLE_TOWER_PEDESTAL_3,
}

-- Item template locations (assuming they're in ReplicatedStorage.Items)
local ITEM_TEMPLATES = {
	Ankh = "Ankh",
	Orb1 = "Orb1",
	Orb2 = "Orb2", 
	Orb3 = "Orb3",
}

-- Special tags to apply to spawned items
local ITEM_TAGS = {
	Ankh = CS_tags.ARENA_ANKH, -- AnkhController listens for this tag
	Orb1 = nil, -- No special tag needed for orbs yet
	Orb2 = nil,
	Orb3 = nil,
}

local spawnedItems = {} -- Track spawned items for cleanup

-- Get the Artifacts folder from ReplicatedStorage.Items
local function getArtifactsFolder()
	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	if not itemsFolder then
		return nil
	end
	
	local artifactsFolder = itemsFolder:FindFirstChild("Artifacts")
	if not artifactsFolder then
		return nil
	end
	
	return artifactsFolder
end

-- Find pedestal part by tag
local function findPedestalByTag(tag)
	local taggedParts = CollectionService:GetTagged(tag)
	for _, part in ipairs(taggedParts) do
		if part:IsA("BasePart") and part:IsDescendantOf(Workspace) then
			return part
		end
	end
	return nil
end

-- Calculate spawn position on top of pedestal
local function getSpawnPositionOnPedestal(pedestal)
	local pedestalTop = pedestal.Position.Y + (pedestal.Size.Y / 2)
	local spawnPos = Vector3.new(pedestal.Position.X, pedestalTop + 0.5, pedestal.Position.Z) -- Just slightly above pedestal surface
	return spawnPos
end

-- Clone and configure item
local function createItemFromTemplate(itemName, position)
	local artifactsFolder = getArtifactsFolder()
	if not artifactsFolder then return nil end
	
	local template = artifactsFolder:FindFirstChild(ITEM_TEMPLATES[itemName])
	if not template then
		return nil
	end
	
	local item = template:Clone()
	
	-- Position the item (with rotation for Ankh)
	local cframe = CFrame.new(position)
	if itemName == "Ankh" then
		-- Make Ankh face world origin (0,0) like the pyramid does
		local targetPosition = Vector3.new(0, position.Y, 0) -- Keep same Y, but look at 0,0
		cframe = CFrame.lookAt(position, targetPosition)
		-- Then rotate 90 degrees around Y-axis (green axis) to fix front orientation
		cframe = cframe * CFrame.Angles(0, math.rad(90), 0)
	end
	
	if item:IsA("MeshPart") then
		item.CFrame = cframe
		item.CanCollide = true
		item.Anchored = false -- Allow physics/dragging
	elseif item:IsA("Model") and item.PrimaryPart then
		item:SetPrimaryPartCFrame(cframe)
		item.PrimaryPart.CanCollide = true
		item.PrimaryPart.Anchored = false
	elseif item:IsA("Tool") then
		local handle = item:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CFrame = cframe
			handle.CanCollide = true
			handle.Anchored = false
		end
	end
	
	item.Parent = Workspace
	
	-- Apply special tags
	local specialTag = ITEM_TAGS[itemName]
	if specialTag then
		CollectionService:AddTag(item, specialTag)
	end
	
	-- Make items draggable
	CollectionService:AddTag(item, CS_tags.DRAGGABLE)
	CollectionService:AddTag(item, CS_tags.WELDABLE)
	
	return item
end

-- Spawn a specific item on its designated pedestal
function EventItemSpawner.spawnItem(itemName)
	local pedestalTag = ITEM_PEDESTAL_MAP[itemName]
	if not pedestalTag then
		return false
	end
	
	local pedestal = findPedestalByTag(pedestalTag)
	if not pedestal then
		return false
	end
	
	-- Clean up existing item if any
	if spawnedItems[itemName] then
		spawnedItems[itemName]:Destroy()
		spawnedItems[itemName] = nil
	end
	
	local spawnPosition = getSpawnPositionOnPedestal(pedestal)
	local item = createItemFromTemplate(itemName, spawnPosition)
	
	if item then
		spawnedItems[itemName] = item
		return true
	else
		return false
	end
end

-- Spawn all event items
function EventItemSpawner.spawnAllItems()
	local success = 0
	local total = 0
	
	for itemName, _ in pairs(ITEM_PEDESTAL_MAP) do
		total = total + 1
		if EventItemSpawner.spawnItem(itemName) then
			success = success + 1
		end
	end
	
	return success == total
end

-- Clean up all spawned items
function EventItemSpawner.cleanupAllItems()
	for itemName, item in pairs(spawnedItems) do
		if item and item.Parent then
			item:Destroy()
		end
		spawnedItems[itemName] = nil
	end
end

-- Respawn a specific item (useful for when items are taken/used)
function EventItemSpawner.respawnItem(itemName, delay)
	delay = delay or 0
	
	if delay > 0 then
		task.spawn(function()
			task.wait(delay)
			EventItemSpawner.spawnItem(itemName)
		end)
	else
		EventItemSpawner.spawnItem(itemName)
	end
end

-- Check if all pedestals are available
function EventItemSpawner.validatePedestals()
	local valid = true
	
	for itemName, pedestalTag in pairs(ITEM_PEDESTAL_MAP) do
		local pedestal = findPedestalByTag(pedestalTag)
		if not pedestal then
			valid = false
		end
	end
	
	return valid
end

-- Check if all item templates exist
function EventItemSpawner.validateTemplates()
	local artifactsFolder = getArtifactsFolder()
	if not artifactsFolder then return false end
	
	local valid = true
	
	for itemName, templateName in pairs(ITEM_TEMPLATES) do
		local template = artifactsFolder:FindFirstChild(templateName)
		if not template then
			valid = false
		end
	end
	
	return valid
end

-- Initialize the system (validate and spawn items)
function EventItemSpawner.initialize()
	
	local pedestalsValid = EventItemSpawner.validatePedestals()
	local templatesValid = EventItemSpawner.validateTemplates()
	
	if pedestalsValid and templatesValid then
		return EventItemSpawner.spawnAllItems()
	else
		return false
	end
end

-- Get status info for debugging
function EventItemSpawner.getStatus()
	local status = {
		spawnedItems = {},
		pedestalStatus = {},
		templateStatus = {},
	}
	
	-- Check spawned items
	for itemName, item in pairs(spawnedItems) do
		status.spawnedItems[itemName] = {
			exists = item and item.Parent ~= nil,
			position = item and item:IsA("BasePart") and item.Position or nil,
		}
	end
	
	-- Check pedestals
	for itemName, pedestalTag in pairs(ITEM_PEDESTAL_MAP) do
		local pedestal = findPedestalByTag(pedestalTag)
		status.pedestalStatus[itemName] = {
			found = pedestal ~= nil,
			name = pedestal and pedestal.Name or nil,
			position = pedestal and pedestal.Position or nil,
		}
	end
	
	-- Check templates
	local artifactsFolder = getArtifactsFolder()
	for itemName, templateName in pairs(ITEM_TEMPLATES) do
		local template = artifactsFolder and artifactsFolder:FindFirstChild(templateName)
		status.templateStatus[itemName] = {
			found = template ~= nil,
			className = template and template.ClassName or nil,
		}
	end
	
	return status
end

return EventItemSpawner