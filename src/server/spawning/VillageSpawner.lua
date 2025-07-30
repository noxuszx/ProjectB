--[[
	VillageSpawner.lua
	Handles spawning of village structures
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local villageConfig = require(ReplicatedStorage.Shared.config.Village)
local terrain = require(ReplicatedStorage.Shared.utilities.terrain)
local ChunkConfig = require(ReplicatedStorage.Shared.config.ChunkConfig)

local VillageSpawner = {}
local random = Random.new()

-- Create organized folder for spawned villagesS
local villageFolder = Instance.new("Folder")
villageFolder.Name = "SpawnedVillages"
villageFolder.Parent = Workspace

-- Load village models from ReplicatedStorage
local function loadVillageModels()
	local models = {}
	local villageFolder = ReplicatedStorage

	for part in villageConfig.VILLAGE_MODEL_FOLDER:gmatch("[^%.]+") do
		villageFolder = villageFolder:FindFirstChild(part)
		if not villageFolder then
			warn("Village model folder not found:", villageConfig.VILLAGE_MODEL_FOLDER)
			return models
		end
	end

	for _, modelName in ipairs(villageConfig.AVAILABLE_STRUCTURES) do
		local model = villageFolder:FindFirstChild(modelName)
		if model then
			models[modelName] = model
		else
			warn("Model not found:", modelName)
		end
	end
	return models
end


local function spawnVillage(models, chunkPosition)
	local structurePositions = {}
	local selectedStructures = {}
	local validPositionFound = false

	local numStructures = random:NextInteger(villageConfig.STRUCTURES_PER_VILLAGE[1], villageConfig.STRUCTURES_PER_VILLAGE[2])
	for i = 1, numStructures do
		local randomStructure = villageConfig.AVAILABLE_STRUCTURES[random:NextInteger(1, #villageConfig.AVAILABLE_STRUCTURES)]
		table.insert(selectedStructures, randomStructure)
	end

	for _, modelName in ipairs(selectedStructures) do
		local attempts = 0
		local positionFound = false
		
		repeat
			local offsetX = random:NextNumber(-villageConfig.VILLAGE_RADIUS, villageConfig.VILLAGE_RADIUS)
			local offsetZ = random:NextNumber(-villageConfig.VILLAGE_RADIUS, villageConfig.VILLAGE_RADIUS)
			local position = chunkPosition + Vector3.new(offsetX, 0, offsetZ)
			local isValid = true

			if #structurePositions > 0 then
				for _, otherPos in ipairs(structurePositions) do
					local distance = (position - otherPos).Magnitude
					if distance < villageConfig.STRUCTURE_SPACING then
						isValid = false
						break
					end
				end
			end
			if isValid then
				structurePositions[#structurePositions + 1] = position
				positionFound = true
				validPositionFound = true
			end

			attempts = attempts + 1

		until positionFound or attempts >= 10  -- Fixed max attempts
		if not positionFound then
			warn("Could not find valid position for", modelName, "using spaced fallback position")
			local fallbackPosition = chunkPosition + Vector3.new(#structurePositions * villageConfig.STRUCTURE_SPACING, 0, 0)
			structurePositions[#structurePositions + 1] = fallbackPosition
		end
	end

	if validPositionFound then
		for i, modelName in ipairs(selectedStructures) do
			local model = models[modelName]
			if model and structurePositions[i] then
				local clonedModel = model:Clone()
				
				local pos = structurePositions[i]
				local terrainHeight = terrain.getTerrainHeight(pos.X, pos.Z)
				local finalPosition = Vector3.new(pos.X, terrainHeight, pos.Z)
				local cframe = CFrame.new(finalPosition)
				local rotationSettings = villageConfig.ROTATION_SETTINGS[villageConfig.ROTATION_MODE]

				if villageConfig.ROTATION_MODE == "CARDINAL" then
					local angle = rotationSettings.angles[random:NextInteger(1, #rotationSettings.angles)]
					cframe = cframe * CFrame.Angles(0, math.rad(angle), 0)

				elseif villageConfig.ROTATION_MODE == "CENTER_FACING" then
					local directionToCenter = (chunkPosition - finalPosition).Unit
					local angle = math.atan2(directionToCenter.X, directionToCenter.Z) + math.rad(rotationSettings.angle_offset)
					cframe = cframe * CFrame.Angles(0, angle, 0)

				elseif villageConfig.ROTATION_MODE == "CARDINAL_VARIED" then
					local baseAngle = rotationSettings.base_angles[random:NextInteger(1, #rotationSettings.base_angles)]
					local variance = random:NextNumber(-rotationSettings.variance, rotationSettings.variance)
					local finalAngle = baseAngle + variance
					cframe = cframe * CFrame.Angles(0, math.rad(finalAngle), 0)

				elseif villageConfig.ROTATION_MODE == "RANDOM" then
					local randomYRotation = random:NextNumber(0, 2 * math.pi)
					cframe = cframe * CFrame.Angles(0, randomYRotation, 0)
				end
				
				clonedModel:SetPrimaryPartCFrame(cframe)
				clonedModel.Parent = villageFolder
				
				task.wait(villageConfig.SPAWN_DELAY)
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
		warn("No village models found in", villageConfig.VILLAGE_MODEL_FOLDER)
		return
	end
	
	local numVillages = random:NextInteger(villageConfig.VILLAGES_TO_SPAWN[1], villageConfig.VILLAGES_TO_SPAWN[2])
	local spawnedVillages = 0
	local attempts = 0
	local maxAttempts = numVillages * 5

	while spawnedVillages < numVillages and attempts < maxAttempts do

		local chunkX, chunkZ
		if villageConfig.CENTER_BIAS and random:NextNumber() < villageConfig.CENTER_BIAS then
			local halfDistance = math.floor(ChunkConfig.RENDER_DISTANCE * 0.5)
			chunkX = random:NextInteger(-halfDistance, halfDistance)
			chunkZ = random:NextInteger(-halfDistance, halfDistance)
		else
			local maxDistance = ChunkConfig.RENDER_DISTANCE - villageConfig.EDGE_BUFFER
			chunkX = random:NextInteger(-maxDistance, maxDistance)
			chunkZ = random:NextInteger(-maxDistance, maxDistance)
		end
		
		local chunkPosition = Vector3.new(chunkX * ChunkConfig.CHUNK_SIZE, 0, chunkZ * ChunkConfig.CHUNK_SIZE)
		local success = spawnVillage(models, chunkPosition)
		if success then
			spawnedVillages = spawnedVillages + 1
		end
		
		attempts = attempts + 1
	end

	print(spawnedVillages .. " out of " .. numVillages .. " villages spawned successfully!")
end

return VillageSpawner
