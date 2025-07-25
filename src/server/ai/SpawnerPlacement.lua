-- src/server/ai/SpawnerPlacement.lua
-- Procedural spawner placement system
-- Automatically places creature spawners based on terrain analysis and biome detection

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local NoiseGenerator = require(ReplicatedStorage.Shared.utilities.NoiseGenerator)
local ChunkConfig = require(ReplicatedStorage.Shared.config.ChunkConfig)
local CreatureSpawnConfig = require(ReplicatedStorage.Shared.config.CreatureSpawnConfig)
local SpawnerPlacementConfig = require(ReplicatedStorage.Shared.config.SpawnerPlacementConfig)

local SpawnerPlacement = {}

-- Create organized folder for procedural spawners
local proceduralSpawnersFolder = Instance.new("Folder")
proceduralSpawnersFolder.Name = "ProceduralSpawners"
proceduralSpawnersFolder.Parent = workspace

-- Noise configuration for biome detection
local tempConfig = SpawnerPlacementConfig.NoiseSettings.Temperature
local humidConfig = SpawnerPlacementConfig.NoiseSettings.Humidity
local hostileConfig = SpawnerPlacementConfig.NoiseSettings.Hostility

local spawnersPlaced = 0
local chunksProcessed = 0

-- Initialize random seed for consistent random spawning
math.randomseed(SpawnerPlacementConfig.RandomSpawning.RandomSeed)

local function debugPrint(message)
	if SpawnerPlacementConfig.Settings.DebugMode then
		print("[SpawnerPlacement]", message)
	end
end

-- Determine spawn type based on config setting (noise-based or random)
local function getSpawnType(chunkX, chunkZ)
	if SpawnerPlacementConfig.Settings.UseNoiseBasedSpawning then
		
		local worldX = chunkX * ChunkConfig.CHUNK_SIZE
		local worldZ = chunkZ * ChunkConfig.CHUNK_SIZE
		
		local temperature = NoiseGenerator.fractalNoise(
			worldX, worldZ,
			tempConfig.Octaves,
			0.5, -- persistence
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

		-- Fallback for random
		return "Safe"
	end
end

-- Simple ground detection for flat desert terrain
local function hasGround(position)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {proceduralSpawnersFolder}

	-- Cast ray downward to find ground
	local rayOrigin = position + Vector3.new(0, 10, 0)
	local rayDirection = Vector3.new(0, -SpawnerPlacementConfig.TerrainValidation.RaycastDistance, 0)

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	return raycastResult ~= nil -- Just check if we hit ground
end

-- Simple spawner spacing check
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

	return true -- Good spacing
end

-- Simple village avoidance check
local function isAwayFromVillages(position)
	local minDistance = SpawnerPlacementConfig.AvoidanceRules.VillageDistance

	-- Check distance from player spawn (0,0,0)
	local spawnDistance = (position - Vector3.new(0, 0, 0)).Magnitude
	if spawnDistance < SpawnerPlacementConfig.AvoidanceRules.PlayerSpawnDistance then
		return false -- Too close to player spawn
	end

	-- Check distance from villages (if any exist)
	local villageFolder = workspace:FindFirstChild("SpawnedVillages")
	if villageFolder then
		for _, village in pairs(villageFolder:GetChildren()) do
			if village:IsA("Model") and village.PrimaryPart then
				local villageDistance = (position - village.PrimaryPart.Position).Magnitude
				if villageDistance < minDistance then
					return false -- Too close to village
				end
			end
		end
	end

	return true
end

-- Find a valid position within a chunk for spawner placement
local function findValidSpawnerPosition(chunkX, chunkZ)
	local chunkSize = ChunkConfig.CHUNK_SIZE
	local worldX = chunkX * chunkSize
	local worldZ = chunkZ * chunkSize

	-- Use configurable max attempts
	local maxAttempts = SpawnerPlacementConfig.Settings.MaxPlacementAttempts

	for attempt = 1, maxAttempts do
		-- Random position within chunk bounds
		local offsetX = math.random(-chunkSize/2, chunkSize/2)
		local offsetZ = math.random(-chunkSize/2, chunkSize/2)

		local testX = worldX + offsetX
		local testZ = worldZ + offsetZ
		local testY = 20 -- Start at reasonable height for flat desert (terrain is 0-5 studs)

		local testPosition = Vector3.new(testX, testY, testZ)

		-- Raycast to find ground
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = {proceduralSpawnersFolder}

		local raycastDistance = 30 -- Enough to reach ground from Y=20
		local raycastResult = workspace:Raycast(testPosition, Vector3.new(0, -raycastDistance, 0), raycastParams)

		if raycastResult then
			local spawnerHeight = SpawnerPlacementConfig.Settings.SpawnerHeight
			local groundPosition = raycastResult.Position + Vector3.new(0, spawnerHeight, 0)

			-- Simple validation checks for flat desert world
			local spacingValid = isGoodSpacing(groundPosition)
			local villageValid = isAwayFromVillages(groundPosition)

			if spacingValid and villageValid then
				return groundPosition
			else
				-- Debug why this position failed
				if SpawnerPlacementConfig.Settings.DebugMode then
					local reasons = {}
					if not spacingValid then table.insert(reasons, "spacing") end
					if not villageValid then table.insert(reasons, "village_distance") end
					debugPrint("Position rejected at " .. tostring(groundPosition) .. ": " .. table.concat(reasons, ", "))
				end
			end
		else
			-- Debug raycast failure
			if SpawnerPlacementConfig.Settings.DebugMode then
				debugPrint("Raycast failed at " .. tostring(testPosition) .. " - no ground found")
			end
		end
	end

	return nil -- No valid position found
end

-- Create a spawner part at the specified position
local function createSpawnerPart(position, spawnType)
	-- Verify spawn type exists in config
	if not CreatureSpawnConfig.SpawnTypes[spawnType] then
		warn("[SpawnerPlacement] Unknown spawn type:", spawnType)
		return nil
	end

	-- Create spawner part (visible or invisible based on debug setting)
	local spawnerPart = Instance.new("Part")
	spawnerPart.Name = "ProceduralSpawner_" .. spawnType .. "_" .. tick()
	spawnerPart.Size = Vector3.new(5, 5, 5)
	spawnerPart.Position = position
	spawnerPart.Transparency = SpawnerPlacementConfig.Debug.ShowSpawnerParts and 0.5 or 1
	spawnerPart.Anchored = true
	spawnerPart.CanCollide = false
	spawnerPart.Parent = proceduralSpawnersFolder

	-- Set debug color if visible
	if SpawnerPlacementConfig.Debug.ShowSpawnerParts then
		local areaColor = SpawnerPlacementConfig.Debug.AreaColors[spawnType]
		if areaColor then
			spawnerPart.Color = areaColor
		end
	end

	-- Add CollectionService tag (must match CreatureSpawner expectations)
	CollectionService:AddTag(spawnerPart, CreatureSpawnConfig.Settings.SpawnTag)

	-- Set spawn type attribute (must match CreatureSpawner expectations)
	spawnerPart:SetAttribute(CreatureSpawnConfig.Settings.SpawnTypeAttribute, spawnType)

	spawnersPlaced = spawnersPlaced + 1
	debugPrint("Created " .. spawnType .. " spawner at " .. tostring(position))

	return spawnerPart
end

-- Process a single chunk for spawner placement
function SpawnerPlacement.placeSpawnersForChunk(chunkX, chunkZ)
	chunksProcessed = chunksProcessed + 1
	
	-- Basic spawn chance - not every chunk gets a spawner
	local spawnChance = SpawnerPlacementConfig.Settings.SpawnerChunkChance
	if math.random() > spawnChance then
		return -- Skip this chunk
	end
	
	-- Determine spawn type for this chunk (noise-based or random)
	local spawnType = getSpawnType(chunkX, chunkZ)
	
	-- Find valid position within chunk
	local spawnerPosition = findValidSpawnerPosition(chunkX, chunkZ)

	if spawnerPosition then
		-- Create the spawner
		createSpawnerPart(spawnerPosition, spawnType)
		debugPrint("Placed " .. spawnType .. " spawner in chunk (" .. chunkX .. ", " .. chunkZ .. ")")
	else
		debugPrint("No valid position found in chunk (" .. chunkX .. ", " .. chunkZ .. ") - all " .. SpawnerPlacementConfig.Settings.MaxPlacementAttempts .. " attempts failed")
	end
end

-- Main function to run spawner placement for all chunks
function SpawnerPlacement.run()
	local spawningMethod = SpawnerPlacementConfig.Settings.UseNoiseBasedSpawning and "noise-based" or "random"
	debugPrint("Starting procedural spawner placement using " .. spawningMethod .. " method...")

	spawnersPlaced = 0
	chunksProcessed = 0
	
	-- Get render distance from ChunkConfig or use default
	local renderDistance = ChunkConfig.RENDER_DISTANCE or 10
	
	-- Process all chunks within render distance
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

-- Get debug information
function SpawnerPlacement.getDebugInfo()
	return {
		spawnersPlaced = spawnersPlaced,
		chunksProcessed = chunksProcessed,
		placementRate = spawnersPlaced / math.max(chunksProcessed, 1)
	}
end

-- Clean up all procedural spawners (for session management)
function SpawnerPlacement.cleanup()
	if proceduralSpawnersFolder then
		proceduralSpawnersFolder:Destroy()
	end

	-- Reset counters
	spawnersPlaced = 0
	chunksProcessed = 0

	-- Recreate folder for next session
	proceduralSpawnersFolder = Instance.new("Folder")
	proceduralSpawnersFolder.Name = "ProceduralSpawners"
	proceduralSpawnersFolder.Parent = workspace

	debugPrint("Cleaned up all procedural spawners for new session")
end

return SpawnerPlacement
