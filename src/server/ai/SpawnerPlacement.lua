-- src/server/ai/SpawnerPlacement.lua
-- Procedural spawner placement system
-- Automatically places creature spawners based on terrain analysis and biome detection

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local NoiseGenerator = require(ReplicatedStorage.Shared.utilities.NoiseGenerator)
local ChunkConfig = require(ReplicatedStorage.Shared.config.ChunkConfig)
local CreatureSpawnConfig = require(ReplicatedStorage.Shared.config.ai.CreatureSpawning)
local SpawnerPlacementConfig = require(ReplicatedStorage.Shared.config.ai.SpawnerPlacing)

local SpawnerPlacement = {}

local proceduralSpawnersFolder = Instance.new("Folder")
proceduralSpawnersFolder.Name = "ProceduralSpawners"
proceduralSpawnersFolder.Parent = workspace

local tempConfig = SpawnerPlacementConfig.NoiseSettings.Temperature
local humidConfig = SpawnerPlacementConfig.NoiseSettings.Humidity
local hostileConfig = SpawnerPlacementConfig.NoiseSettings.Hostility

local spawnersPlaced = 0
local chunksProcessed = 0

math.randomseed(SpawnerPlacementConfig.RandomSpawning.RandomSeed)



local function getSpawnType(chunkX, chunkZ)
	if SpawnerPlacementConfig.Settings.UseNoiseBasedSpawning then
		
		local worldX = chunkX * ChunkConfig.CHUNK_SIZE
		local worldZ = chunkZ * ChunkConfig.CHUNK_SIZE
		
		local temperature = NoiseGenerator.fractalNoise(
			worldX, worldZ,
			tempConfig.Octaves,
			0.5,
			tempConfig.Scale
		)

		local humidity = NoiseGenerator.fractalNoise(
			worldX + 1000, worldZ + 1000,
			humidConfig.Octaves,
			0.5,
			humidConfig.Scale
		)

		local hostility = NoiseGenerator.fractalNoise(
			worldX + 2000, worldZ + 2000,
			hostileConfig.Octaves,
			0.5,
			hostileConfig.Scale
		)

		temperature = (temperature + 1) / 2
		humidity = (humidity + 1) / 2
		hostility = (hostility + 1) / 2

		for _, rule in ipairs(SpawnerPlacementConfig.SpawnAreaRules) do
			if rule.condition(temperature, humidity, hostility) then
				return rule.spawnType
			end
		end

		return "Safe"
	else
		
		local randomValue = math.random()
		local cumulativeProbability = 0

		for spawnType, probability in pairs(SpawnerPlacementConfig.RandomSpawning.SpawnTypeProbabilities) do
			cumulativeProbability = cumulativeProbability + probability
			if randomValue <= cumulativeProbability then
				return spawnType
			end
		end
		return "Safe"
	end
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
	local minDistance = SpawnerPlacementConfig.TerrainValidation.ClearanceRadius

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

local function findValidSpawnerPosition(chunkX, chunkZ)
	local chunkSize = ChunkConfig.CHUNK_SIZE
	local worldX = chunkX * chunkSize
	local worldZ = chunkZ * chunkSize

	local maxAttempts = SpawnerPlacementConfig.Settings.MaxPlacementAttempts

	for attempt = 1, maxAttempts do
		local offsetX = math.random(-chunkSize/2, chunkSize/2)
		local offsetZ = math.random(-chunkSize/2, chunkSize/2)

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

			if spacingValid and villageValid then
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

	spawnersPlaced = spawnersPlaced + 1
	return spawnerPart
end

function SpawnerPlacement.placeSpawnersForChunk(chunkX, chunkZ)
	chunksProcessed = chunksProcessed + 1
	
	local spawnChance = SpawnerPlacementConfig.Settings.SpawnerChunkChance
	if math.random() > spawnChance then
		return
	end
	
	local spawnType = getSpawnType(chunkX, chunkZ)
	local spawnerPosition = findValidSpawnerPosition(chunkX, chunkZ)

	if spawnerPosition then
		createSpawnerPart(spawnerPosition, spawnType)
	end
end

function SpawnerPlacement.run()
	spawnersPlaced = 0
	chunksProcessed = 0
	
	local renderDistance = ChunkConfig.RENDER_DISTANCE or 10
	for chunkX = -renderDistance, renderDistance do
		for chunkZ = -renderDistance, renderDistance do
			SpawnerPlacement.placeSpawnersForChunk(chunkX, chunkZ)
		end
	end
	
	print("[SpawnerPlacement] Procedural spawner placement complete!")
	print("  - Chunks processed:", chunksProcessed)
	print("  - Spawners placed:", spawnersPlaced)
	print("  - Placement rate:", string.format("%.1f%%", (spawnersPlaced / chunksProcessed) * 100))
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
