-- Spawns AI creatures from ReplicatedStorage models
-- Integrates with existing spawning patterns and chunk system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local AIConfig = require(ReplicatedStorage.Shared.config.ai.ai)
local CreatureSpawnConfig = require(ReplicatedStorage.Shared.config.ai.creatureSpawning)
local DayNightCycle = require(script.Parent.Parent.environment.dayNightCycle)
local PassiveCreature = require(script.Parent.creatures.passive)
local HostileCreature = require(script.Parent.creatures.hostile)
local AIManager = require(script.Parent.aiManager)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local CreatureSpawner = {}
local availableCreatures = {
	PassiveCreatures = {},
	HostileCreatures = {}
}
local spawnedCreaturesCount = 0
local processedSpawnersCount = 0

local creatureFolder = Instance.new("Folder")
creatureFolder.Name = "SpawnedCreatures"
creatureFolder.Parent = workspace

local passiveCreatureFolder = Instance.new("Folder")
passiveCreatureFolder.Name = "PassiveCreatures"
passiveCreatureFolder.Parent = creatureFolder

local hostileCreatureFolder = Instance.new("Folder")
hostileCreatureFolder.Name = "HostileCreatures"
hostileCreatureFolder.Parent = creatureFolder

local function debugPrint(message)
	if AIConfig.Settings.DebugMode then
		print("[CreatureSpawner]", message)
	end
end

local function shouldSpawnBasedOnTime(creatureType)
	local currentPeriod = DayNightCycle.getCurrentPeriod()
	local nightOnlyCreatures = CreatureSpawnConfig.Settings.NightOnlyCreatures
	for _, nightCreature in ipairs(nightOnlyCreatures) do
		if creatureType == nightCreature then
			return currentPeriod == "NIGHT" or currentPeriod == "DUSK"
		end
	end

	return true
end

local function validateCreatureModel(model, creatureType)
	local issues = {}

	-- Check if model has PrimaryPart
	if not model.PrimaryPart then
		table.insert(issues, "No PrimaryPart set")
	elseif not model.PrimaryPart.Parent then
		table.insert(issues, "PrimaryPart reference is invalid")
	end

	-- Check for essential parts
	local hasHumanoid = model:FindFirstChild("Humanoid") ~= nil
	if not hasHumanoid then
		table.insert(issues, "No Humanoid found")
	end

	-- Check for common body parts
	local bodyParts = {"HumanoidRootPart", "Torso", "UpperTorso", "Head"}
	local foundParts = {}
	for _, partName in ipairs(bodyParts) do
		if model:FindFirstChild(partName) then
			table.insert(foundParts, partName)
		end
	end

	if #foundParts == 0 then
		table.insert(issues, "No standard body parts found (HumanoidRootPart, Torso, UpperTorso, Head)")
	end

	-- Report issues
	if #issues > 0 then
		warn("[CreatureSpawner] Model validation issues for " .. creatureType .. ":")
		for _, issue in ipairs(issues) do
			warn("  - " .. issue)
		end
		if #foundParts > 0 then
			warn("  Available parts: " .. table.concat(foundParts, ", "))
		end
		return false
	end

	return true
end

local function discoverAvailableCreatures()
	debugPrint("Discovering available creature models...")
	local creaturesFolder = ReplicatedStorage:FindFirstChild(AIConfig.Settings.CreaturesFolder)
	if not creaturesFolder then
		warn("[CreatureSpawner] Creatures folder not found in ReplicatedStorage:", AIConfig.Settings.CreaturesFolder)
		return
	end

	local passiveFolder = creaturesFolder:FindFirstChild("PassiveCreatures")
	if passiveFolder then
		for _, model in pairs(passiveFolder:GetChildren()) do
			if model:IsA("Model") then
				if validateCreatureModel(model, model.Name) then
					table.insert(availableCreatures.PassiveCreatures, model)
					debugPrint("Found valid passive creature: " .. model.Name)
				else
					warn("[CreatureSpawner] Skipping invalid passive creature: " .. model.Name)
				end
			end
		end
	end

	local hostileFolder = creaturesFolder:FindFirstChild("HostileCreatures")
	if hostileFolder then
		for _, model in pairs(hostileFolder:GetChildren()) do
			if model:IsA("Model") then
				if validateCreatureModel(model, model.Name) then
					table.insert(availableCreatures.HostileCreatures, model)
					debugPrint("Found valid hostile creature: " .. model.Name)
				else
					warn("[CreatureSpawner] Skipping invalid hostile creature: " .. model.Name)
				end
			end
		end
	end

	local totalCreatures = #availableCreatures.PassiveCreatures + #availableCreatures.HostileCreatures
	debugPrint("Total creature models found: " .. totalCreatures)
end

-- Diagnostic function to help debug PrimaryPart issues
function CreatureSpawner.diagnosePrimaryPartIssues()
	print("[CreatureSpawner] Running PrimaryPart diagnostics...")

	local creaturesFolder = ReplicatedStorage:FindFirstChild(AIConfig.Settings.CreaturesFolder)
	if not creaturesFolder then
		warn("Creatures folder not found in ReplicatedStorage:", AIConfig.Settings.CreaturesFolder)
		return
	end

	local function checkFolder(folder, folderType)
		if not folder then return end

		print("Checking " .. folderType .. " creatures:")
		for _, model in pairs(folder:GetChildren()) do
			if model:IsA("Model") then
				print("  Model: " .. model.Name)

				if model.PrimaryPart then
					print("    ✓ PrimaryPart: " .. model.PrimaryPart.Name)
				else
					print("    ✗ No PrimaryPart set!")

					-- List available parts
					local parts = {}
					for _, child in pairs(model:GetChildren()) do
						if child:IsA("BasePart") then
							table.insert(parts, child.Name)
						end
					end

					if #parts > 0 then
						print("    Available parts: " .. table.concat(parts, ", "))
					else
						print("    No BaseParts found in model!")
					end
				end

				-- Check for Humanoid
				local humanoid = model:FindFirstChild("Humanoid")
				if humanoid then
					print("    ✓ Has Humanoid")
				else
					print("    ✗ No Humanoid found")
				end
			end
		end
	end

	checkFolder(creaturesFolder:FindFirstChild("PassiveCreatures"), "Passive")
	checkFolder(creaturesFolder:FindFirstChild("HostileCreatures"), "Hostile")

	print("[CreatureSpawner] Diagnostics complete")
end

-- Function to attempt to fix PrimaryPart issues on models in ReplicatedStorage
function CreatureSpawner.fixPrimaryPartIssues()
	print("[CreatureSpawner] Attempting to fix PrimaryPart issues...")

	local creaturesFolder = ReplicatedStorage:FindFirstChild(AIConfig.Settings.CreaturesFolder)
	if not creaturesFolder then
		warn("Creatures folder not found in ReplicatedStorage:", AIConfig.Settings.CreaturesFolder)
		return
	end

	local function fixFolder(folder, folderType)
		if not folder then return end

		print("Fixing " .. folderType .. " creatures:")
		for _, model in pairs(folder:GetChildren()) do
			if model:IsA("Model") and not model.PrimaryPart then
				print("  Fixing: " .. model.Name)

				-- Try to find and set a suitable PrimaryPart
				local candidates = {"HumanoidRootPart", "Torso", "UpperTorso", "Head"}
				local fixed = false

				for _, partName in ipairs(candidates) do
					local part = model:FindFirstChild(partName)
					if part and part:IsA("BasePart") then
						model.PrimaryPart = part
						print("    ✓ Set " .. partName .. " as PrimaryPart")
						fixed = true
						break
					end
				end

				if not fixed then
					-- Last resort: use any BasePart
					for _, child in pairs(model:GetChildren()) do
						if child:IsA("BasePart") then
							model.PrimaryPart = child
							print("    ✓ Set " .. child.Name .. " as PrimaryPart (fallback)")
							fixed = true
							break
						end
					end
				end

				if not fixed then
					warn("    ✗ Could not fix " .. model.Name .. " - no BaseParts found")
				end
			end
		end
	end

	fixFolder(creaturesFolder:FindFirstChild("PassiveCreatures"), "Passive")
	fixFolder(creaturesFolder:FindFirstChild("HostileCreatures"), "Hostile")

	print("[CreatureSpawner] Fix attempt complete")
end

function CreatureSpawner.init()
	debugPrint("Initializing creature spawner...")

	-- Set up physics collision groups (only if PhysicsService is available)
	local success, err = pcall(function()
		PhysicsService:CreateCollisionGroup("Creature")
		PhysicsService:SetPartCollisionGroup(game.Workspace.Terrain, "Default")
		PhysicsService:CollisionGroupSetCollidable("Creature", "Default", true)
	end)

	if not success then
		warn("[CreatureSpawner] Failed to set up collision groups:", err)
	end

	debugPrint("Creature spawner initialized")
	CreatureSpawner.populateWorld()
	return true
end

function CreatureSpawner.getCreatureTemplate(creatureType)
	local config = AIConfig.CreatureTypes[creatureType]
	if not config then
		warn("[CreatureSpawner] Unknown creature type:", creatureType)
		return nil
	end

	local folderName = config.ModelFolder
	local creatureList = availableCreatures[folderName] or {}

	for _, model in pairs(creatureList) do
		if model.Name == creatureType then
			return model
		end
	end

	warn("[CreatureSpawner] Model not found for creature type:", creatureType)
	return nil
end

function CreatureSpawner.spawnCreature(creatureType, position, config)
	local template = CreatureSpawner.getCreatureTemplate(creatureType)
	if not template then
		debugPrint("Failed to spawn " .. creatureType .. " - no template found")
		return nil
	end

	-- Validate template has PrimaryPart before cloning
	if not template.PrimaryPart then
		warn("[CreatureSpawner] Template " .. creatureType .. " has no PrimaryPart set!")
		return nil
	end

	-- Store the original PrimaryPart name for recovery
	local originalPrimaryPartName = template.PrimaryPart.Name

	local creatureModel = template:Clone()
	creatureModel.Name = creatureType .. "_" .. tick()

	-- Enhanced PrimaryPart validation and recovery system
	local function findAndSetPrimaryPart(model, preferredName)
		-- First try to use the original PrimaryPart name
		if preferredName then
			local originalPart = model:FindFirstChild(preferredName)
			if originalPart and originalPart:IsA("BasePart") then
				model.PrimaryPart = originalPart
				debugPrint("Restored original PrimaryPart (" .. preferredName .. ") for " .. creatureType)
				return true
			end
		end

		-- Try standard creature part names in order of preference
		local candidateParts = {
			"HumanoidRootPart",
			"Torso",
			"UpperTorso",
			"LowerTorso",
			"Head",
			"Root"
		}

		for _, partName in ipairs(candidateParts) do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				model.PrimaryPart = part
				debugPrint("Set " .. partName .. " as PrimaryPart for " .. creatureType)
				return true
			end
		end

		-- Last resort: find any BasePart in the model
		for _, child in pairs(model:GetChildren()) do
			if child:IsA("BasePart") then
				model.PrimaryPart = child
				warn("[CreatureSpawner] Using fallback BasePart (" .. child.Name .. ") as PrimaryPart for " .. creatureType)
				return true
			end
		end

		return false
	end

	-- Validate PrimaryPart after cloning and attempt recovery if needed
	if not creatureModel.PrimaryPart then
		warn("[CreatureSpawner] PrimaryPart lost during cloning for " .. creatureType .. "! Attempting recovery...")

		if not findAndSetPrimaryPart(creatureModel, originalPrimaryPartName) then
			warn("[CreatureSpawner] Could not find any suitable PrimaryPart for " .. creatureType .. "! Skipping spawn.")
			creatureModel:Destroy()
			return nil
		end
	else
		-- Even if PrimaryPart exists, validate it's still valid
		if not creatureModel.PrimaryPart.Parent then
			warn("[CreatureSpawner] PrimaryPart reference is invalid for " .. creatureType .. "! Attempting recovery...")
			creatureModel.PrimaryPart = nil -- Clear invalid reference

			if not findAndSetPrimaryPart(creatureModel, originalPrimaryPartName) then
				warn("[CreatureSpawner] Could not recover PrimaryPart for " .. creatureType .. "! Skipping spawn.")
				creatureModel:Destroy()
				return nil
			end
		end
	end

	if creatureModel.PrimaryPart then
		creatureModel:SetPrimaryPartCFrame(CFrame.new(position))
	else
		creatureModel:MoveTo(position)
	end

	local creatureConfig = AIConfig.CreatureTypes[creatureType]
	if creatureConfig and creatureConfig.Type == "Passive" then
		creatureModel.Parent = passiveCreatureFolder
	elseif creatureConfig and creatureConfig.Type == "Hostile" then
		creatureModel.Parent = hostileCreatureFolder
	else
		creatureModel.Parent = creatureFolder
	end

	if creatureModel.PrimaryPart then
    creatureModel.PrimaryPart.CollisionGroup = "Creature"
end

	-- Tag the creature as non-draggable to prevent drag-drop interference
	CollectionServiceTags.tagCreatureAsNonDraggable(creatureModel)

	local aiController = nil

	if creatureConfig and creatureConfig.Type == "Passive" then
		aiController = PassiveCreature.new(creatureModel, creatureType, position)
	elseif creatureConfig and creatureConfig.Type == "Hostile" then
		aiController = HostileCreature.new(creatureModel, creatureType, position)
	else
		warn("[CreatureSpawner] Unknown creature AI type for:", creatureType)
		creatureModel:Destroy()
		return nil
	end

	spawnedCreaturesCount = spawnedCreaturesCount + 1
	debugPrint("Spawned " .. creatureType .. " at " .. tostring(position))

	return aiController
end

local function getRandomSpawnPosition(spawnerPart, usedPositions)
	local spawnerPosition = spawnerPart.Position
	local scatterRadius = CreatureSpawnConfig.Settings.ScatterRadius
	local maxAttempts = CreatureSpawnConfig.Settings.MaxScatterAttempts

	for attempt = 1, maxAttempts do
		local angle = math.random() * math.pi * 2
		local distance = math.random() * scatterRadius

		local offsetX = math.sin(angle) * distance
		local offsetZ = math.cos(angle) * distance

		local testPosition = Vector3.new(
			spawnerPosition.X + offsetX,
			spawnerPosition.Y + CreatureSpawnConfig.Settings.SpawnHeight,
			spawnerPosition.Z + offsetZ
		)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = {spawnerPart}

		local rayOrigin = testPosition + Vector3.new(0, 10, 0)
		local rayDirection = Vector3.new(0, -20, 0)

		local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if raycastResult then
			local groundPosition = raycastResult.Position + Vector3.new(0, 0.5, 0) -- Just slightly above ground

			local tooClose = false
			for _, usedPos in pairs(usedPositions) do
				if (groundPosition - usedPos).Magnitude < 5 then -- Minimum 5 studs apart
					tooClose = true
					break
				end
			end

			if not tooClose then
				table.insert(usedPositions, groundPosition)
				return groundPosition
			end
		end
	end

	return spawnerPosition + Vector3.new(0, 2, 0)
end

local function performCreatureRoll(spawnConfig)
	local creaturesToSpawn = {}
	local numRolls = math.random(spawnConfig.MinSpawns, spawnConfig.MaxSpawns)

	if math.random() > spawnConfig.SpawnChance then
		return creaturesToSpawn
	end

	for i = 1, numRolls do
		for creatureType, chance in pairs(spawnConfig.PossibleCreatures) do
			if shouldSpawnBasedOnTime(creatureType) and math.random() <= chance then
				table.insert(creaturesToSpawn, creatureType)
				break
			end
		end
	end

	return creaturesToSpawn
end

-- Process a single spawner part
local function processSpawner(spawnerPart)
	local spawnType = spawnerPart:GetAttribute(CreatureSpawnConfig.Settings.SpawnTypeAttribute)
	if not spawnType then
		warn("[CreatureSpawner] Spawner missing SpawnType attribute:", spawnerPart:GetFullName())
		return
	end

	local spawnerConfig = CreatureSpawnConfig.SpawnTypes[spawnType]
	if not spawnerConfig then
		warn("[CreatureSpawner] Unknown spawn type:", spawnType)
		return
	end

	debugPrint("Processing spawner: " .. spawnType .. " at " .. tostring(spawnerPart.Position))
	local creaturesToSpawn = performCreatureRoll(spawnerConfig)
	local usedPositions = {}

	for _, creatureType in pairs(creaturesToSpawn) do
		local spawnPosition = getRandomSpawnPosition(spawnerPart, usedPositions)
		local aiController = CreatureSpawner.spawnCreature(creatureType, spawnPosition)

		-- Register with AI Manager
		if aiController then
			AIManager.getInstance():registerCreature(aiController)
		end
	end

	processedSpawnersCount = processedSpawnersCount + 1
end

function CreatureSpawner.populateWorld()

	debugPrint("Starting world population with creatures...")
	spawnedCreaturesCount = 0
	processedSpawnersCount = 0
	discoverAvailableCreatures()

	local spawnerParts = CollectionService:GetTagged(CreatureSpawnConfig.Settings.SpawnTag)
	debugPrint("Found " .. #spawnerParts .. " creature spawner parts")

	if #spawnerParts == 0 then
		debugPrint("No creature spawner parts found. Make sure parts are tagged with: " .. CreatureSpawnConfig.Settings.SpawnTag)
		return
	end

	for _, spawnerPart in pairs(spawnerParts) do
		processSpawner(spawnerPart)
	end

	print("[CreatureSpawner] World population complete!")
	print("  - Processed spawners:", processedSpawnersCount)
	print("  - Total creatures spawned:", spawnedCreaturesCount)
	print("  - Available creature types:", #availableCreatures.PassiveCreatures + #availableCreatures.HostileCreatures)
end



function CreatureSpawner.cleanup()
	if creatureFolder then
		creatureFolder:Destroy()
	end

	spawnedCreaturesCount = 0
	processedSpawnersCount = 0

	creatureFolder = Instance.new("Folder")
	creatureFolder.Name = "SpawnedCreatures"
	creatureFolder.Parent = workspace

	passiveCreatureFolder = Instance.new("Folder")
	passiveCreatureFolder.Name = "PassiveCreatures"
	passiveCreatureFolder.Parent = creatureFolder

	hostileCreatureFolder = Instance.new("Folder")
	hostileCreatureFolder.Name = "HostileCreatures"
	hostileCreatureFolder.Parent = creatureFolder

	debugPrint("Cleaned up all spawned creatures for new session")
end

return CreatureSpawner


