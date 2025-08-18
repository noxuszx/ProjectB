-- Spawns AI creatures from ReplicatedStorage models
-- Integrates with existing spawning patterns and chunk system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local AIConfig 			  	= require(ReplicatedStorage.Shared.config.ai.AIConfig)
local CreatureSpawnConfig 	= require(ReplicatedStorage.Shared.config.ai.CreatureSpawning)
local DayNightCycle 	  	= require(script.Parent.Parent.environment.DayNightCycle)
local PassiveCreature 	  	= require(script.Parent.creatures.Passive)
local HostileCreature 	  	= require(script.Parent.creatures.Hostile)
local RangedHostile 	  	= require(script.Parent.creatures.RangedHostile)
local AIManager 		  	= require(script.Parent.AIManager)
local CreaturePoolManager 	= require(script.Parent.CreaturePoolManager)
local FrameBatched 		  	= require(ReplicatedStorage.Shared.utilities.FrameBatched)
local FrameBudgetConfig   	= require(ReplicatedStorage.Shared.config.FrameBudgetConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local SFXManager 			= require(script.Parent.audio.SFXManager)


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


local function isValidCreatureModel(model)
	return model.PrimaryPart and model:FindFirstChild("Humanoid")
end


local function discoverAvailableCreatures()
	local creaturesFolder = ReplicatedStorage:FindFirstChild(AIConfig.Settings.CreaturesFolder)
	if not creaturesFolder then
		warn("[CreatureSpawner] Creatures folder not found in ReplicatedStorage:", AIConfig.Settings.CreaturesFolder)
		return
	end

	for _, folderName in pairs({"PassiveCreatures", "HostileCreatures"}) do
		local folder = creaturesFolder:FindFirstChild(folderName)
		if folder then
			for _, model in pairs(folder:GetChildren()) do
				if model:IsA("Model") and isValidCreatureModel(model) then
					table.insert(availableCreatures[folderName], model)
				end
			end
		end
	end
end


function CreatureSpawner.init()
	local success, err = pcall(function()
		PhysicsService:RegisterCollisionGroup("Creature")
		game.Workspace.Terrain.CollisionGroup = "Default"
		PhysicsService:CollisionGroupSetCollidable("Creature", "Default", true)
	end)

	if not success then
		warn("[CreatureSpawner] Failed to set up collision groups:", err)
	end
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


function CreatureSpawner.spawnCreature(creatureType, position, options)
	options = options or {}
	local activationMode = options.activationMode or "Procedural"
	
	-- Get creature config directly (no inheritance needed)
	local config = AIConfig.CreatureTypes[creatureType]
	if not config then
		warn("[CreatureSpawner] Unknown creature type:", creatureType)
		return nil
	end
	
	local template = CreatureSpawner.getCreatureTemplate(creatureType)
	if not template then return nil end

	local creatureModel = template:Clone()
	creatureModel.Name = creatureType .. "_" .. os.clock()
	
	creatureModel:SetPrimaryPartCFrame(CFrame.new(position))

	-- Choose target folder based on activation mode and creature type
	local targetFolder
	if activationMode == "Zone" then
		-- Tower creatures go in a special folder for organization
		local towerCreatureFolder = creatureFolder:FindFirstChild("TowerCreatures")
		if not towerCreatureFolder then
			towerCreatureFolder = Instance.new("Folder")
			towerCreatureFolder.Name = "TowerCreatures"
			towerCreatureFolder.Parent = creatureFolder
		end
		targetFolder = towerCreatureFolder
	else
		-- Procedural spawning uses existing folders
		targetFolder = (config.Type == "Passive") and passiveCreatureFolder or hostileCreatureFolder
	end
	
	creatureModel.Parent = targetFolder

	if creatureModel.PrimaryPart then
		creatureModel.PrimaryPart.CollisionGroup = "Creature"
		creatureModel.PrimaryPart:SetNetworkOwner(nil)
	end

	-- Create appropriate AI controller based on creature type
	local aiController
	if config.Type == "Passive" then
		aiController = PassiveCreature.new(creatureModel, creatureType, position)
	elseif config.Type == "RangedHostile" then
		aiController = RangedHostile.new(creatureModel, creatureType, position)
	else -- Default to regular hostile
		aiController = HostileCreature.new(creatureModel, creatureType, position)
	end
	
	-- Mark as indoor creature for LOD bias if from tower spawning
	if activationMode == "Zone" then
		aiController.isIndoorCreature = true
	end

	-- Auto-bind creature SFX for specific types at creation time (covers both procedural and zone spawns)
	pcall(function()
		if creatureType == "Mummy" or creatureType == "TowerMummy" or creatureType == "Scorpion" then
			SFXManager.setupForModel(creatureModel)
		end
	end)

	spawnedCreaturesCount = spawnedCreaturesCount + 1
	
	-- Register with pool manager for tracking
	CreaturePoolManager.registerCreatureSpawn(creatureType)
	
	return aiController
end

local function getRandomSpawnPosition(spawnerPart, usedPositions, creatureModel)
	local spawnerPosition = spawnerPart.Position
	local scatterRadius = CreatureSpawnConfig.Settings.ScatterRadius
	local maxAttempts = CreatureSpawnConfig.Settings.MaxScatterAttempts
	
	-- Calculate dynamic height offset based on creature model size
	local heightOffset = 0.5
	if creatureModel then
		local success, cframe, size = pcall(function()
			return creatureModel:GetBoundingBox()
		end)
		if success and size then
			heightOffset = size.Y / 2 + 0.1 -- Half height + small safety margin
		end
	end

	for _ = 1, maxAttempts do
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
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {spawnerPart}
		local rayOrigin = testPosition + Vector3.new(0, 10, 0)
		local rayDirection = Vector3.new(0, -20, 0)
		local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if raycastResult then
			local groundPosition = raycastResult.Position + Vector3.new(0, heightOffset, 0)

			local tooClose = false
			for _, usedPos in pairs(usedPositions) do
				if (groundPosition - usedPos).Magnitude < 5 then
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
	-- Respect overall spawn chance first
	local rng = Random.new()
	if rng:NextNumber(0, 1) > spawnConfig.SpawnChance then
		return {}
	end
	
	-- Build a weighted list from PossibleCreatures (values are treated as weights)
	local weighted = {}
	local totalWeight = 0
	for creatureType, weight in pairs(spawnConfig.PossibleCreatures) do
		local w = tonumber(weight) or 0
		if w > 0 then
			table.insert(weighted, { type = creatureType, weight = w })
			totalWeight += w
		end
	end
	if totalWeight <= 0 or #weighted == 0 then
		return {}
	end
	
	local creaturesToSpawn = {}
	local numRolls = math.random(spawnConfig.MinSpawns, spawnConfig.MaxSpawns)
	for _ = 1, numRolls do
		-- Weighted pick
		local pick = rng:NextNumber(0, totalWeight)
		local acc = 0
		local chosen = nil
		for i = 1, #weighted do
			acc += weighted[i].weight
			if pick <= acc then
				chosen = weighted[i].type
				break
			end
		end
		if chosen then
			table.insert(creaturesToSpawn, chosen)
			-- Optional: encourage variety by slightly reducing chosen weight for subsequent rolls
			-- for i = 1, #weighted do
			-- 	if weighted[i].type == chosen then
			-- 		local newW = math.max(0.1, weighted[i].weight * 0.8)
			-- 		totalWeight += (newW - weighted[i].weight)
			-- 		weighted[i].weight = newW
			-- 		break
			-- 	end
			-- end
		end
	end
	return creaturesToSpawn
end


local function processSpawner(spawnerPart)
	-- Make the spawner invisible and non-interactive
	local function hidePart(p)
		if p:IsA("BasePart") then
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
	end
	if spawnerPart:IsA("BasePart") then
		hidePart(spawnerPart)
	elseif spawnerPart:IsA("Model") then
		for _, d in ipairs(spawnerPart:GetDescendants()) do
			hidePart(d)
		end
	end

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


	local creaturesToSpawn = performCreatureRoll(spawnerConfig)
	local usedPositions = {}

	for _, creatureType in pairs(creaturesToSpawn) do
		-- Check procedural spawning limit (reserves slots for towers/events)
		local aiManager = AIManager.getInstance()
		if aiManager:getCreatureCount() >= AIConfig.Settings.MaxProceduralCreatures then
			print("[CreatureSpawner] Reached MaxProceduralCreatures limit:", AIConfig.Settings.MaxProceduralCreatures, "- reserving slots for towers/events")
			break -- Stop spawning more creatures
		end
		
		local template = CreatureSpawner.getCreatureTemplate(creatureType)
		local spawnPosition = getRandomSpawnPosition(spawnerPart, usedPositions, template)
		local aiController = CreatureSpawner.spawnCreature(creatureType, spawnPosition)

		if aiController then
			aiManager:registerCreature(aiController)
-- Auto-bind creature SFX for specific types
			if creatureType == "Mummy" or creatureType == "TowerMummy" or creatureType == "Scorpion" then
				pcall(function()
					local model = aiController and aiController.model or creatureModel
					if model then SFXManager.setupForModel(model) end
				end)
			end
		end
	end

	processedSpawnersCount = processedSpawnersCount + 1
end

function CreatureSpawner.populateWorld()
	spawnedCreaturesCount = 0
	processedSpawnersCount = 0
	discoverAvailableCreatures()

	local spawnerParts = CollectionServiceTags.getLiveTagged(CreatureSpawnConfig.Settings.SpawnTag)

	if #spawnerParts == 0 then
		warn("[CreatureSpawner] No creature spawner parts found. Make sure parts are tagged with: " .. CreatureSpawnConfig.Settings.SpawnTag)
		return
	end

	-- Process spawners with frame batching
	local batchSize = FrameBudgetConfig.getBatchSize("CREATURES")
	FrameBatched.run(spawnerParts, batchSize, function(spawnerPart)
		processSpawner(spawnerPart)
	end)

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


end

return CreatureSpawner






