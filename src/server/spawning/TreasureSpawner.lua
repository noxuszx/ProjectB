-- src/server/spawning/TreasureSpawner.lua
-- Spawns treasure items (goldpiles, chests, etc.) at specific tagged spawner locations
-- Uses name-based matching: "treasure-spawner-1" -> "goldpile1"

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local TreasureSpawner = {}

-- Constants
local TREASURE_FOLDER_NAME = "Treasure"
local SPAWNED_FOLDER_NAME = "SpawnedTreasure"

-- State tracking
local treasureTemplates = {}
local spawnedTreasures = {}
local treasureFolder = nil

-- Create spawned treasure folder in workspace
local spawnedFolder = Instance.new("Folder")
spawnedFolder.Name = SPAWNED_FOLDER_NAME
spawnedFolder.Parent = workspace

local function debugPrint(message)
	-- Debug prints removed for production
end

-- Load treasure templates from ServerStorage
local function loadTreasureTemplates()
	treasureTemplates = {}
	
	treasureFolder = ServerStorage:FindFirstChild(TREASURE_FOLDER_NAME)
	if not treasureFolder then
		warn("[TreasureSpawner] Treasure folder not found in ServerStorage:", TREASURE_FOLDER_NAME)
		return false
	end
	
	local templateCount = 0
	for _, template in pairs(treasureFolder:GetChildren()) do
		if template:IsA("MeshPart") then
			treasureTemplates[template.Name] = template
			templateCount = templateCount + 1
		end
	end
	
	return templateCount > 0
end

-- Parse spawner name to determine treasure type
local function parseSpawnerName(spawnerName)
	local treasureName = nil
	
	-- Handle "treasure-spawner-X" pattern
	local number = spawnerName:match("treasure%-spawner%-(%d+)")
	if number then
		treasureName = "goldpile" .. number
	else
		-- Handle "gold-spawner-X" pattern (legacy)
		number = spawnerName:match("gold%-spawner%-(%d+)")
		if number then
			treasureName = "goldpile" .. number
		else
			-- Handle "treasure-spawner-name" pattern
			local customName = spawnerName:match("treasure%-spawner%-(.+)")
			if customName then
				treasureName = customName
			end
		end
	end
	
	return treasureName
end

-- Apply standard tags to spawned treasure (optimized for MeshParts)
local function applyTreasureTags(treasure)
	CollectionServiceTags.addTag(treasure, CollectionServiceTags.DRAGGABLE)
	CollectionServiceTags.addTag(treasure, CollectionServiceTags.WELDABLE)
	CollectionServiceTags.addTag(treasure, CollectionServiceTags.STORABLE)
end

-- Spawn a single treasure at a spawner location
local function spawnTreasure(spawnerPart)
	local spawnerName = spawnerPart.Name
	local treasureName = parseSpawnerName(spawnerName)
	
	if not treasureName then
		warn("[TreasureSpawner] Could not parse treasure name from spawner:", spawnerName)
		return false
	end
	
	local template = treasureTemplates[treasureName]
	if not template then
		warn("[TreasureSpawner] Treasure template not found:", treasureName, "for spawner:", spawnerName)
		return false
	end
	
	-- Clone and position the treasure
	local treasure = template:Clone()
	treasure.Parent = spawnedFolder
	treasure.CFrame = CFrame.new(spawnerPart.Position)
	
	-- Apply standard treasure tags
	applyTreasureTags(treasure)
	
	-- Track spawned treasure
	table.insert(spawnedTreasures, treasure)
	
	return true
end

-- Clear all previously spawned treasures
function TreasureSpawner.ClearSpawned()
	for _, treasure in pairs(spawnedTreasures) do
		if treasure and treasure.Parent then
			treasure:Destroy()
		end
	end
	
	-- Also clear any remaining items in the spawned folder
	for _, child in pairs(spawnedFolder:GetChildren()) do
		child:Destroy()
	end
	
	spawnedTreasures = {}
end

-- Spawn all treasures at tagged spawner locations
function TreasureSpawner.SpawnAll()
	-- Load templates
	if not loadTreasureTemplates() then
		return false
	end
	
	-- Clear any existing spawned treasures
	TreasureSpawner.ClearSpawned()
	
	-- Find all treasure spawners
	local spawners = CollectionServiceTags.getLiveTagged(CollectionServiceTags.TREASURE_SPAWNER)
	
	if #spawners == 0 then
		return false
	end
	
	-- Spawn treasures at each spawner
	local successCount = 0
	for _, spawner in pairs(spawners) do
		if spawnTreasure(spawner) then
			successCount = successCount + 1
		end
	end
	
	return successCount > 0
end

-- Get count of spawned treasures
function TreasureSpawner.GetSpawnedCount()
	return #spawnedTreasures
end

-- Get list of available treasure templates
function TreasureSpawner.GetAvailableTemplates()
	local templateNames = {}
	for name, _ in pairs(treasureTemplates) do
		table.insert(templateNames, name)
	end
	return templateNames
end

-- Initialize the treasure spawning system
function TreasureSpawner.Initialize()
	-- Load and validate templates
	if not loadTreasureTemplates() then
		return false
	end
	
	-- Check for spawners and auto-spawn if found
	local spawners = CollectionServiceTags.getLiveTagged(CollectionServiceTags.TREASURE_SPAWNER)
	if #spawners > 0 then
		return TreasureSpawner.SpawnAll()
	end
	
	return true
end

-- Debug function to test name parsing
function TreasureSpawner.TestNameParsing(testNames)
	testNames = testNames or {
		"treasure-spawner-1",
		"treasure-spawner-2", 
		"treasure-spawner-diamond",
		"gold-spawner-1",
		"gold-spawner-3"
	}
	
	debugPrint("Testing name parsing...")
	for _, name in pairs(testNames) do
		local parsed = parseSpawnerName(name)
		debugPrint("  " .. name .. " -> " .. (parsed or "nil"))
	end
end

return TreasureSpawner