-- src/server/ai/SpawnerPlacement.lua
-- Procedural spawner placement system
-- Automatically places creature spawners based on terrain analysis and biome detection

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ChunkConfig = require(ReplicatedStorage.Shared.config.ChunkConfig)
local CreatureSpawnConfig = require(ReplicatedStorage.Shared.config.ai.CreatureSpawning)
local SpawnerPlacementConfig = require(ReplicatedStorage.Shared.config.ai.SpawnerPlacing)
local FrameBatched = require(ReplicatedStorage.Shared.utilities.FrameBatched)
local FrameBudgetConfig = require(ReplicatedStorage.Shared.config.FrameBudgetConfig)
local CoreStructureSpawner = require(script.Parent.Parent.spawning.CoreStructureSpawner)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local SpawnerPlacement = {}

local proceduralSpawnersFolder = Instance.new("Folder")
proceduralSpawnersFolder.Name = "ProceduralSpawners"
proceduralSpawnersFolder.Parent = workspace


local spawnersPlaced = 0
local chunksProcessed = 0

math.randomseed(SpawnerPlacementConfig.RandomSpawning.RandomSeed)



local function getSpawnType(chunkX, chunkZ)
	-- Simple random spawn type selection using designer-controlled probabilities
	local randomValue = math.random()
	local cumulativeProbability = 0

	for spawnType, probability in pairs(SpawnerPlacementConfig.RandomSpawning.SpawnTypeProbabilities) do
		cumulativeProbability = cumulativeProbability + probability
		if randomValue <= cumulativeProbability then
			return spawnType
		end
	end
	return "Safe" -- Fallback to safe spawning
end


local function hasGround(position)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {proceduralSpawnersFolder}

	local rayOrigin = position + Vector3.new(0, 10, 0)
	local rayDirection = Vector3.new(0, -SpawnerPlacementConfig.TerrainValidation.RaycastDistance, 0)
	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	return raycastResult ~= nil
end


local function isGoodSpacing(position)
	-- Variable clearance radius for organic clustering (0.7-1.3x base radius)
	local baseRadius = SpawnerPlacementConfig.TerrainValidation.ClearanceRadius
	local minDistance = baseRadius * math.random(70, 130) / 100

	for _, part in pairs(proceduralSpawnersFolder:GetChildren()) do
		if part:IsA("BasePart") then
			local distance = (part.Position - position).Magnitude
			if distance < minDistance then
				return false
			end
		end
	end

	return true
end

local function isAwayFromVillages(position)
	local minDistance = SpawnerPlacementConfig.AvoidanceRules.VillageDistance

	local spawnDistance = (position - Vector3.new(0, 0, 0)).Magnitude
	if spawnDistance < SpawnerPlacementConfig.AvoidanceRules.PlayerSpawnDistance then
		return false
	end

	local villageFolder = workspace:FindFirstChild("SpawnedVillages")
	if villageFolder then
		for _, village in pairs(villageFolder:GetChildren()) do
			if village:IsA("Model") and village.PrimaryPart then
				local villageDistance = (position - village.PrimaryPart.Position).Magnitude
				if villageDistance < minDistance then
					return false
				end
			end
		end
	end

	return true
end

local function isAwayFromCoreStructures(position)
	local coreCircles = CoreStructureSpawner.getOccupiedCircles()
	local minDistance = SpawnerPlacementConfig.AvoidanceRules.VillageDistance -- Use same distance as villages
	
	for _, circle in ipairs(coreCircles) do
		local distance = (position - circle.centre).Magnitude
		if distance < (circle.radius + minDistance) then
			return false
		end
	end
	
	return true
end

local function findValidSpawnerPosition(chunkX, chunkZ)
	local chunkSize = ChunkConfig.CHUNK_SIZE
	local worldX = chunkX * chunkSize
	local worldZ = chunkZ * chunkSize

	local maxAttempts = SpawnerPlacementConfig.Settings.MaxPlacementAttempts

	for attempt = 1, maxAttempts do
		-- Jittered placement with diagonal spread for organic distribution
		local baseX = math.random(-chunkSize/2, chunkSize/2)
		local baseZ = math.random(-chunkSize/2, chunkSize/2)
		local jitter = (math.random() - 0.5) * chunkSize * 0.4  -- ±40% extra
		-- Clamp offsets to keep spawners within chunk bounds
		local offsetX = math.clamp(baseX + jitter, -chunkSize/2, chunkSize/2)
		local offsetZ = math.clamp(baseZ - jitter, -chunkSize/2, chunkSize/2)  -- Different sign gives diagonal spread

		local testX = worldX + offsetX
		local testZ = worldZ + offsetZ
		local testY = 20 -- Start at reasonable height for flat desert (terrain is 0-5 studs)

		local testPosition = Vector3.new(testX, testY, testZ)

		-- Raycast to find ground
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {proceduralSpawnersFolder}

		local raycastDistance = 30 -- Enough to reach ground from Y=20
		local raycastResult = workspace:Raycast(testPosition, Vector3.new(0, -raycastDistance, 0), raycastParams)

		if raycastResult then
			local spawnerHeight = SpawnerPlacementConfig.Settings.SpawnerHeight
			local groundPosition = raycastResult.Position + Vector3.new(0, spawnerHeight, 0)

			local spacingValid = isGoodSpacing(groundPosition)
			local villageValid = isAwayFromVillages(groundPosition)
			local coreStructureValid = isAwayFromCoreStructures(groundPosition)

			if spacingValid and villageValid and coreStructureValid then
				return groundPosition
			end
		end
	end

	return nil
end

local function createSpawnerPart(position, spawnType)
	if not CreatureSpawnConfig.SpawnTypes[spawnType] then
		warn("[SpawnerPlacement] Unknown spawn type:", spawnType)
		return nil
	end

	local spawnerPart = Instance.new("Part")
	spawnerPart.Name = "ProceduralSpawner_" .. spawnType .. "_" .. os.clock()
	spawnerPart.Size = Vector3.new(5, 5, 5)
	spawnerPart.Position = position
	spawnerPart.Transparency = SpawnerPlacementConfig.Debug.ShowSpawnerParts and 0.5 or 1
	spawnerPart.Anchored = true
	spawnerPart.CanCollide = false
	spawnerPart.Parent = proceduralSpawnersFolder

	if SpawnerPlacementConfig.Debug.ShowSpawnerParts then
		local areaColor = SpawnerPlacementConfig.Debug.AreaColors[spawnType]
		if areaColor then
			spawnerPart.Color = areaColor
		end
	end

	CollectionService:AddTag(spawnerPart, CreatureSpawnConfig.Settings.SpawnTag)
	spawnerPart:SetAttribute(CreatureSpawnConfig.Settings.SpawnTypeAttribute, spawnType)
	
	-- Tag spawner as protected geometry to prevent model spawning overlaps
	CollectionServiceTags.addTag(spawnerPart, CollectionServiceTags.PROTECTED_SPAWNER)

	spawnersPlaced = spawnersPlaced + 1
	return spawnerPart
end

function SpawnerPlacement.placeSpawnersForChunk(chunkX, chunkZ)
	chunksProcessed = chunksProcessed + 1
	
	local spawnChance = SpawnerPlacementConfig.Settings.SpawnerChunkChance
	if math.random() > spawnChance then
		return
	end
	
	-- Place 1-3 spawners per selected chunk for clustering
	local maxSpawners = SpawnerPlacementConfig.Performance.MaxSpawnersPerChunk
	local numSpawners = math.random(1, maxSpawners)
	
	for i = 1, numSpawners do
		local spawnType = getSpawnType(chunkX, chunkZ)
		local spawnerPosition = findValidSpawnerPosition(chunkX, chunkZ)

		if spawnerPosition then
			createSpawnerPart(spawnerPosition, spawnType)
		else
			-- Break early if we can't find valid positions (prevents infinite attempts)
			break
		end
	end
end

function SpawnerPlacement.run()
	spawnersPlaced = 0
	chunksProcessed = 0
	
	local renderDistance = ChunkConfig.RENDER_DISTANCE or 10
	
	-- Create chunk coordinate iterator
	local chunkIterator = FrameBatched.chunkIterator(-renderDistance, renderDistance, -renderDistance, renderDistance)
	
	-- Process chunks with frame batching
	local perFrame = SpawnerPlacementConfig.Performance.PerFrame
	FrameBatched.wrap(chunkIterator, perFrame, function(coord)
		SpawnerPlacement.placeSpawnersForChunk(coord.x, coord.z)
	end)
	
	print("[SpawnerPlacement] Procedural spawner placement complete!")
	print("  - Chunks processed:", chunksProcessed)
	print("  - Spawners placed:", spawnersPlaced)
	print("  - Placement rate:", string.format("%.1f%%", (spawnersPlaced / math.max(chunksProcessed, 1)) * 100))
end

function SpawnerPlacement.getDebugInfo()
	return {
		spawnersPlaced = spawnersPlaced,
		chunksProcessed = chunksProcessed,
		placementRate = spawnersPlaced / math.max(chunksProcessed, 1)
	}
end

function SpawnerPlacement.cleanup()
	if proceduralSpawnersFolder then
		proceduralSpawnersFolder:Destroy()
	end

	spawnersPlaced = 0
	chunksProcessed = 0

	proceduralSpawnersFolder = Instance.new("Folder")
	proceduralSpawnersFolder.Name = "ProceduralSpawners"
	proceduralSpawnersFolder.Parent = workspace


end

return SpawnerPlacement
