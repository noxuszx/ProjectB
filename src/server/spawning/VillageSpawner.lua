--[[
	VillageSpawner.lua
	Handles spawning of village structures
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VillageConfig = require(ReplicatedStorage.Shared.config.VillageConfig)
local NoiseGenerator = require(ReplicatedStorage.Shared.utilities.NoiseGenerator)
local ChunkConfig = require(ReplicatedStorage.Shared.config.ChunkConfig)

local VillageSpawner = {}
local random = Random.new()

-- Create organized folder for spawned villages
local villageFolder = Instance.new("Folder")
villageFolder.Name = "SpawnedVillages"
villageFolder.Parent = Workspace

-- Load village models from ReplicatedStorage
local function loadVillageModels()
	local models = {}
	local villageFolder = ReplicatedStorage

	for part in VillageConfig.VILLAGE_MODEL_FOLDER:gmatch("[^%.]+") do
		villageFolder = villageFolder:FindFirstChild(part)
		if not villageFolder then
			warn("Village model folder not found:", VillageConfig.VILLAGE_MODEL_FOLDER)
			return models
		end
	end

	for _, modelName in ipairs(VillageConfig.AVAILABLE_STRUCTURES) do
		local model = villageFolder:FindFirstChild(modelName)
		if model then
			models[modelName] = model
		else
			warn("Model not found:", modelName)
		end
	end
	return models
end

-- Check for obstacles in an area
local function hasLargeObstacle(position)
	local ray = Ray.new(position, Vector3.new(0, -VillageConfig.OBSTACLE_CHECK_RADIUS, 0))
	local part = Workspace:FindPartOnRay(ray)
	return part and part.Name == "Rock"
end

-- Get terrain height at position (using existing system)
local function getTerrainHeightAt(x, z)
	local distanceFromSpawn = math.sqrt(x^2 + z^2)
	
	if distanceFromSpawn <= ChunkConfig.SPAWN_FLAT_RADIUS then
		return ChunkConfig.SPAWN_HEIGHT
	elseif distanceFromSpawn <= (ChunkConfig.SPAWN_FLAT_RADIUS + ChunkConfig.SPAWN_TRANSITION_WIDTH) then
		local transitionFactor = (distanceFromSpawn - ChunkConfig.SPAWN_FLAT_RADIUS) / ChunkConfig.SPAWN_TRANSITION_WIDTH
		return (1 - transitionFactor) * ChunkConfig.SPAWN_HEIGHT + transitionFactor * NoiseGenerator.getTerrainHeight(x, z, ChunkConfig)
	else
		return NoiseGenerator.getTerrainHeight(x, z, ChunkConfig)
	end
end

-- Spawn a single village
local function spawnVillage(models, chunkPosition)
	local structurePositions = {}
	local selectedStructures = {}
	local validPositionFound = false

	-- Randomly select structures for this village
	local numStructures = random:NextInteger(VillageConfig.STRUCTURES_PER_VILLAGE[1], VillageConfig.STRUCTURES_PER_VILLAGE[2])
	for i = 1, numStructures do
		local randomStructure = VillageConfig.AVAILABLE_STRUCTURES[random:NextInteger(1, #VillageConfig.AVAILABLE_STRUCTURES)]
		table.insert(selectedStructures, randomStructure)
	end

	-- Determine positions for each structure
	for _, modelName in ipairs(selectedStructures) do
		local attempts = 0
		local positionFound = false
		
		repeat
			local offsetX = random:NextNumber(-VillageConfig.VILLAGE_RADIUS, VillageConfig.VILLAGE_RADIUS)
			local offsetZ = random:NextNumber(-VillageConfig.VILLAGE_RADIUS, VillageConfig.VILLAGE_RADIUS)
			local position = chunkPosition + Vector3.new(offsetX, 0, offsetZ)

			-- Check for spacing and obstacles
			local isValid = true

			-- Check distance from other structures (only if we have structures placed)
			if #structurePositions > 0 then
				for _, otherPos in ipairs(structurePositions) do
					local distance = (position - otherPos).Magnitude
					if distance < VillageConfig.MIN_STRUCTURE_DISTANCE then
						isValid = false
						break
					end
				end
			end

			-- Check for obstacles
			if isValid and not hasLargeObstacle(position) then
				structurePositions[#structurePositions + 1] = position
				positionFound = true
				validPositionFound = true
			end

			attempts = attempts + 1

		until positionFound or attempts >= VillageConfig.MAX_PLACEMENT_ATTEMPTS
		
		-- If we couldn't find a position, use a fallback near chunk center
		if not positionFound then
			warn("Could not find valid position for", modelName, "using fallback position")
			local fallbackPosition = chunkPosition + Vector3.new(#structurePositions * 5, 0, 0)
			structurePositions[#structurePositions + 1] = fallbackPosition
		end
	end

	-- Only spawn structures if we found at least some valid positions
	if validPositionFound then
		-- Instantiate structures
		for i, modelName in ipairs(selectedStructures) do
			local model = models[modelName]
			if model and structurePositions[i] then
				local clonedModel = model:Clone()
				
				-- Get proper terrain height for positioning
				local pos = structurePositions[i]
				local terrainHeight = getTerrainHeightAt(pos.X, pos.Z)
				local finalPosition = Vector3.new(pos.X, terrainHeight, pos.Z)
				
				-- Create CFrame with position
				local cframe = CFrame.new(finalPosition)
				
				-- Add random rotation if enabled
				if VillageConfig.RANDOM_ROTATION then
					local randomYRotation = random:NextNumber(0, 2 * math.pi)
					cframe = cframe * CFrame.Angles(0, randomYRotation, 0)
				end
				
				clonedModel:SetPrimaryPartCFrame(cframe)
				clonedModel.Parent = villageFolder
				
				wait(VillageConfig.SPAWN_DELAY)
			else
				warn("Skipping", modelName, "- model or position not found")
			end
		end
		return true
	else
		warn("No valid positions found for village at", chunkPosition)
		return false
	end
end

-- Spawn all villages
function VillageSpawner.spawnVillages()
	print("Spawning villages...")
	local models = loadVillageModels()
	
	-- Check if we have any models to spawn
	if next(models) == nil then
		warn("No village models found in", VillageConfig.VILLAGE_MODEL_FOLDER)
		return
	end
	
	local numVillages = random:NextInteger(VillageConfig.MIN_VILLAGES, VillageConfig.MAX_VILLAGES)
	local spawnedVillages = 0
	local attempts = 0
	local maxAttempts = numVillages * 5

	while spawnedVillages < numVillages and attempts < maxAttempts do
		local chunkX = random:NextInteger(-ChunkConfig.RENDER_DISTANCE, ChunkConfig.RENDER_DISTANCE)
		local chunkZ = random:NextInteger(-ChunkConfig.RENDER_DISTANCE, ChunkConfig.RENDER_DISTANCE)
		local chunkPosition = Vector3.new(chunkX * ChunkConfig.CHUNK_SIZE, 0, chunkZ * ChunkConfig.CHUNK_SIZE)

		if not hasLargeObstacle(chunkPosition) then
			local success = spawnVillage(models, chunkPosition)
			if success then
				spawnedVillages = spawnedVillages + 1
			end
		end
		
		attempts = attempts + 1
	end

	print(spawnedVillages .. " out of " .. numVillages .. " villages spawned successfully!")
end

return VillageSpawner
