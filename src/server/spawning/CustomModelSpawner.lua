--[[
	CustomModelSpawner.lua
	Spawns custom models from ReplicatedStorage folders
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ModelSpawnerConfig = require(ReplicatedStorage.Shared.config.ModelSpawnerConfig)
local terrain = require(ReplicatedStorage.Shared.utilities.terrain)

local CustomModelSpawner = {}
local spawnedObjects = {}
local availableModels = {
	Vegetation = {},
	Rocks = {},
	Structures = {}
}

local objectFolders = {}
for category in pairs(availableModels) do
	local folder = Instance.new("Folder")
	folder.Name = "Spawned" .. category
	folder.Parent = Workspace
	objectFolders[category] = folder
end

local random = Random.new()

local function scanAvailableModels()
	print("Scanning for available models...")
	
	for category, folderPath in pairs(ModelSpawnerConfig.MODEL_FOLDERS) do
		local folder = ReplicatedStorage
		
		for part in folderPath:gmatch("[^%.]+") do
			folder = folder:FindFirstChild(part)
			if not folder then
				warn("Model folder not found:", folderPath)
				break
			end
		end
		
		if folder then
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

local function selecRnum(category)
	local models = availableModels[category]
	if #models == 0 then
		return nil
	end
	
	return models[random:NextInteger(1, #models)]
end

-- Check if an area is clear of existing objects using bounding box detection
local function isAreaClear(position, templateModel)
	-- Get the bounding box of the template model
	local success, cframe, size = pcall(function()
		return templateModel:GetBoundingBox()
	end)
	
	if not success or not size then
		-- If we can't get bounding box, allow spawning (fallback behavior)
		return true
	end
	
	-- Create a slightly larger check area to prevent tight overlapping
	local checkSize = size * 1.2
	local checkCFrame = CFrame.new(position)
	
	-- Use workspace:GetPartsInBox to detect any existing parts in the area
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {
		Workspace.Terrain,
		objectFolders.Vegetation,
		objectFolders.Rocks,
		objectFolders.Structures
	}
	
	local overlappingParts = Workspace:GetPartBoundsInBox(checkCFrame, checkSize, overlapParams)
	
	if #overlappingParts > 0 then
		for _, part in pairs(overlappingParts) do
			local parent = part.Parent
			if parent and (
				string.find(parent.Name or "", "Village") or
				string.find(parent.Name or "", "Spawner") or
				parent.Name == "SpawnedCreatures" or
				parent.Name == "DroppedFood"
			) then
				return false
			end
		end
	end
	
	return true
end

local function spawnModel(originalModel, x, z, category)
	if not originalModel then return nil end
	
	local terrainHeight = terrain.getTerrainHeight(x, z)
	
	-- Pre-check: Test if area is clear before cloning model
	local testPosition = Vector3.new(x, terrainHeight, z)
	if not isAreaClear(testPosition, originalModel) then
		return nil -- Area is occupied, skip spawning
	end
	
	local model = originalModel:Clone()
	model.Parent = objectFolders[category]
	
	local scaleRange
	if category == "Vegetation" then
		scaleRange = ModelSpawnerConfig.VEGETATION_SCALE_RANGE
	elseif category == "Rocks" then
		scaleRange = ModelSpawnerConfig.ROCK_SCALE_RANGE
	else
		scaleRange = ModelSpawnerConfig.STRUCTURE_SCALE_RANGE
	end
	
	local scale = random:NextNumber(scaleRange[1], scaleRange[2])
	local initialPosition = Vector3.new(x, terrainHeight, z)
	model:SetPrimaryPartCFrame(CFrame.new(initialPosition))
	
	if scale ~= 1 then
		local scaleFactor = scale
		model:ScaleTo(scaleFactor)
	end
	
	local cf, size = model:GetBoundingBox()
	local modelBottom = cf.Position.Y - (size.Y / 2)
	local embedOffset = 0
	if category == "Vegetation" then
		embedOffset = size.Y * 0.1
	elseif category == "Rocks" then
		embedOffset = size.Y * 0.15
	else
		embedOffset = size.Y * 0.05
	end
	
	local targetGroundLevel = terrainHeight - embedOffset
	local yOffset = targetGroundLevel - modelBottom
	
	local currentCFrame = model:GetPrimaryPartCFrame()
	model:SetPrimaryPartCFrame(currentCFrame + Vector3.new(0, yOffset, 0))
	
	if ModelSpawnerConfig.RANDOM_ROTATION then
		local randomYRotation = random:NextNumber(0, 360)
		model:SetPrimaryPartCFrame(model:GetPrimaryPartCFrame() * CFrame.Angles(0, math.rad(randomYRotation), 0))
	end
	
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

function CustomModelSpawner.spawnInChunk(cx, cz, chunkSize, subdivisions)
	local baseX, baseZ = cx * chunkSize, cz * chunkSize
	local counters = {Vegetation = 0, Rocks = 0, Structures = 0}
	
	for x = 0, chunkSize - 1, chunkSize / subdivisions do
		for z = 0, chunkSize - 1, chunkSize / subdivisions do
			local worldX, worldZ = baseX + x, baseZ + z
			local distfromspawn = math.sqrt(worldX^2 + worldZ^2)
			
			if distfromspawn >= ModelSpawnerConfig.MIN_SPAWN_DISTANCE and
				distfromspawn <= ModelSpawnerConfig.MAX_SPAWN_DISTANCE then
				
				for category, chance in pairs({
					Vegetation = ModelSpawnerConfig.VEGETATION_CHANCE,
					Rocks = ModelSpawnerConfig.ROCK_CHANCE,
					Structures = ModelSpawnerConfig.STRUCTURE_CHANCE
				}) do
					if counters[category] < ModelSpawnerConfig.MAX_OBJECTS_PER_CHUNK[category] then
						if random:NextNumber() < chance then
							local minDistance
							if category == "Vegetation" then
								minDistance = ModelSpawnerConfig.MIN_VEGETATION_DISTANCE
							elseif category == "Rocks" then
								minDistance = ModelSpawnerConfig.MIN_ROCK_DISTANCE
							else
								minDistance = ModelSpawnerConfig.MIN_STRUCTURE_DISTANCE
							end
							
							if isPositionValid(worldX, worldZ, category, minDistance) then
								local subSize = chunkSize / subdivisions
								local offsetX = random:NextNumber(-subSize/3, subSize/3)
								local offsetZ = random:NextNumber(-subSize/3, subSize/3)
								
								local modelToSpawn = selecRnum(category)
								if modelToSpawn then
									spawnModel(modelToSpawn, worldX + offsetX, worldZ + offsetZ, category)
									counters[category] = counters[category] + 1
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

function CustomModelSpawner.init(renderDistance, chunkSize, subdivisions)
	print("Initializing custom model spawner...")
	
	scanAvailableModels()
	local totalModels = 0
	for category, models in pairs(availableModels) do
		totalModels = totalModels + #models
	end
	
	if totalModels == 0 then
		print("No models found in ReplicatedStorage.Models folders. Skipping object spawning.")
		return
	end
	
	CustomModelSpawner.clearObjects()
	
	for cx = -renderDistance, renderDistance do
		for cz = -renderDistance, renderDistance do
			CustomModelSpawner.spawnInChunk(cx, cz, chunkSize, subdivisions)
		end
	end
	
	print("Custom model spawning complete!")
end

return CustomModelSpawner
