--[[
	CustomModelSpawner.lua
	Spawns custom models from ReplicatedStorage folders
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ModelSpawnerConfig = require(ReplicatedStorage.Shared.config.ModelSpawnerConfig)
local NoiseGenerator = require(ReplicatedStorage.Shared.utilities.NoiseGenerator)
local ChunkConfig = require(ReplicatedStorage.Shared.config.ChunkConfig)

local CustomModelSpawner = {}
local spawnedObjects = {}
local availableModels = {
	Vegetation = {},
	Rocks = {},
	Structures = {}
}

-- Create folders to organize spawned objects
local objectFolders = {}
for category in pairs(availableModels) do
	local folder = Instance.new("Folder")
	folder.Name = "Spawned" .. category
	folder.Parent = Workspace
	objectFolders[category] = folder
end

-- Random number generator
local random = Random.new()

-- Scan ReplicatedStorage for available models
local function scanAvailableModels()
	print("Scanning for available models...")
	
	for category, folderPath in pairs(ModelSpawnerConfig.MODEL_FOLDERS) do
		local folder = ReplicatedStorage
		
		-- Navigate to the folder (e.g., "Models.Vegetation")
		for part in folderPath:gmatch("[^%.]+") do
			folder = folder:FindFirstChild(part)
			if not folder then
				warn("Model folder not found:", folderPath)
				break
			end
		end
		
		if folder then
			-- Scan for models in the folder
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") then
					table.insert(availableModels[category], model)
					print("Found", category, "model:", model.Name)
				end
			end
		end
	end
	
	-- Print summary
	for category, models in pairs(availableModels) do
		print(category .. " models found:", #models)
	end
end

-- Get terrain height at a position
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

-- Check if position is too close to existing objects of the same category
local function isPositionValid(x, z, category, minDistance)
	local chunkKey = math.floor(x/32) .. "," .. math.floor(z/32)
	if not spawnedObjects[chunkKey] then
		return true
	end
	
	if not spawnedObjects[chunkKey][category] then
		return true
	end
	
	for _, existingPos in ipairs(spawnedObjects[chunkKey][category]) do
		local distance = math.sqrt((x - existingPos.x)^2 + (z - existingPos.z)^2)
		if distance < minDistance then
			return false
		end
	end
	
	return true
end

-- Select a random model from a category
local function selectRandomModel(category)
	local models = availableModels[category]
	if #models == 0 then
		return nil
	end
	
	return models[random:NextInteger(1, #models)]
end

-- Clone and place a model at a position
local function spawnModel(originalModel, x, z, category)
	if not originalModel then return nil end
	
	local terrainHeight = getTerrainHeightAt(x, z)
	
	-- Clone the model
	local model = originalModel:Clone()
	model.Parent = objectFolders[category]
	
	-- Get scale range for this category
	local scaleRange
	if category == "Vegetation" then
		scaleRange = ModelSpawnerConfig.VEGETATION_SCALE_RANGE
	elseif category == "Rocks" then
		scaleRange = ModelSpawnerConfig.ROCK_SCALE_RANGE
	else -- Structures
		scaleRange = ModelSpawnerConfig.STRUCTURE_SCALE_RANGE
	end
	
	-- Random scale
	local scale = random:NextNumber(scaleRange[1], scaleRange[2])
	
	-- Position the model first at terrain height
	local initialPosition = Vector3.new(x, terrainHeight, z)
	model:SetPrimaryPartCFrame(CFrame.new(initialPosition))
	
	-- Scale the model
	if scale ~= 1 then
		local scaleFactor = scale
		model:ScaleTo(scaleFactor)
	end
	
	-- After scaling, get the actual bounding box and adjust position
	local cf, size = model:GetBoundingBox()
	local modelBottom = cf.Position.Y - (size.Y / 2)
	
	-- Add a small embedding offset to make models appear more naturally planted
	local embedOffset = 0
	if category == "Vegetation" then
		embedOffset = size.Y * 0.1 -- Embed vegetation 10% of their height
	elseif category == "Rocks" then
		embedOffset = size.Y * 0.15 -- Embed rocks 15% of their height
	else -- Structures
		embedOffset = size.Y * 0.05 -- Embed structures 5% of their height
	end
	
	-- Calculate final position with embedding
	local targetGroundLevel = terrainHeight - embedOffset
	local yOffset = targetGroundLevel - modelBottom
	
	-- Adjust the model position so it sits naturally on/in the ground
	local currentCFrame = model:GetPrimaryPartCFrame()
	model:SetPrimaryPartCFrame(currentCFrame + Vector3.new(0, yOffset, 0))
	
	-- Random rotation if enabled
	if ModelSpawnerConfig.RANDOM_ROTATION then
		local randomYRotation = random:NextNumber(0, 360)
		model:SetPrimaryPartCFrame(model:GetPrimaryPartCFrame() * CFrame.Angles(0, math.rad(randomYRotation), 0))
	end
	
	-- Store position for distance checking
	local chunkKey = math.floor(x/32) .. "," .. math.floor(z/32)
	if not spawnedObjects[chunkKey] then
		spawnedObjects[chunkKey] = {}
	end
	if not spawnedObjects[chunkKey][category] then
		spawnedObjects[chunkKey][category] = {}
	end
	
	table.insert(spawnedObjects[chunkKey][category], {x = x, z = z, model = model})
	
	return model
end

-- Spawn objects in a chunk
function CustomModelSpawner.spawnInChunk(cx, cz, chunkSize, subdivisions)
	local baseX, baseZ = cx * chunkSize, cz * chunkSize
	local counters = {Vegetation = 0, Rocks = 0, Structures = 0}
	
	for x = 0, chunkSize - 1, chunkSize / subdivisions do
		for z = 0, chunkSize - 1, chunkSize / subdivisions do
			local worldX, worldZ = baseX + x, baseZ + z
			local distanceFromSpawn = math.sqrt(worldX^2 + worldZ^2)
			
			-- Only spawn objects within the allowed distance range
			if distanceFromSpawn >= ModelSpawnerConfig.MIN_SPAWN_DISTANCE and 
			   distanceFromSpawn <= ModelSpawnerConfig.MAX_SPAWN_DISTANCE then
				
				-- Try to spawn each category
				for category, chance in pairs({
					Vegetation = ModelSpawnerConfig.VEGETATION_CHANCE,
					Rocks = ModelSpawnerConfig.ROCK_CHANCE,
					Structures = ModelSpawnerConfig.STRUCTURE_CHANCE
				}) do
					-- Check if we haven't exceeded the limit for this chunk
					if counters[category] < ModelSpawnerConfig.MAX_OBJECTS_PER_CHUNK[category] then
						-- Random chance to spawn
						if random:NextNumber() < chance then
							-- Get minimum distance for this category
							local minDistance
							if category == "Vegetation" then
								minDistance = ModelSpawnerConfig.MIN_VEGETATION_DISTANCE
							elseif category == "Rocks" then
								minDistance = ModelSpawnerConfig.MIN_ROCK_DISTANCE
							else -- Structures
								minDistance = ModelSpawnerConfig.MIN_STRUCTURE_DISTANCE
							end
							
							-- Check if position is valid (not too close to other objects)
							if isPositionValid(worldX, worldZ, category, minDistance) then
								-- Add some random offset within the subdivision
								local subdivisionSize = chunkSize / subdivisions
								local offsetX = random:NextNumber(-subdivisionSize/3, subdivisionSize/3)
								local offsetZ = random:NextNumber(-subdivisionSize/3, subdivisionSize/3)
								
								-- Select and spawn a model
								local modelToSpawn = selectRandomModel(category)
								if modelToSpawn then
									spawnModel(modelToSpawn, worldX + offsetX, worldZ + offsetZ, category)
									counters[category] = counters[category] + 1
									
									-- Small delay to prevent lag
									wait(ModelSpawnerConfig.GENERATION_DELAY)
								end
							end
						end
					end
				end
			end
		end
	end
end

-- Clear all spawned objects
function CustomModelSpawner.clearObjects()
	print("Clearing spawned objects...")
	
	for _, folder in pairs(objectFolders) do
		for _, child in ipairs(folder:GetChildren()) do
			child:Destroy()
		end
	end
	
	spawnedObjects = {}
	print("Objects cleared!")
end

-- Initialize spawning for all chunks
function CustomModelSpawner.init(renderDistance, chunkSize, subdivisions)
	print("Initializing custom model spawner...")
	
	-- Scan for available models first
	scanAvailableModels()
	
	-- Check if we have any models to spawn
	local totalModels = 0
	for category, models in pairs(availableModels) do
		totalModels = totalModels + #models
	end
	
	if totalModels == 0 then
		print("No models found in ReplicatedStorage.Models folders. Skipping object spawning.")
		return
	end
	
	-- Clear existing objects
	CustomModelSpawner.clearObjects()
	
	-- Spawn objects in each chunk
	for cx = -renderDistance, renderDistance do
		for cz = -renderDistance, renderDistance do
			CustomModelSpawner.spawnInChunk(cx, cz, chunkSize, subdivisions)
		end
	end
	
	print("Custom model spawning complete!")
end

return CustomModelSpawner
