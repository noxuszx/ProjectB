--[[
	CustomModelSpawner.lua
	Spawns custom models from ReplicatedStorage folders
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ModelSpawnerConfig = require(ReplicatedStorage.Shared.config.ModelSpawnerConfig)
local terrain = require(ReplicatedStorage.Shared.utilities.Terrain)

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
				if model:IsA("Model") or model:IsA("MeshPart") then
					table.insert(availableModels[category], model)
					print("Found", category, model:IsA("Model") and "model:" or "meshpart:", model.Name)
				end
			end
		end
	end

	for category, models in pairs(availableModels) do
		print(category .. " models found:", #models)
	end
end



local function isPositionValid(x, z, category, minDistance, chunkSize)
	chunkSize = chunkSize or 32
	local chunkKey = math.floor(x/chunkSize) .. "," .. math.floor(z/chunkSize)
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


local function selectRandom(category)
	local models = availableModels[category]
	if #models == 0 then
		return nil
	end
	
	return models[random:NextInteger(1, #models)]
end

-- Check if an area is clear of existing objects using bounding box detection
local function isAreaClear(position, templateModel, excludeModel)
	-- Get the bounding box of the template model
	local success, cframe, size = pcall(function()
		if templateModel:IsA("Model") then
			return templateModel:GetBoundingBox()
		elseif templateModel:IsA("MeshPart") then
			return templateModel.CFrame, templateModel.Size
		end
	end)
	
	if not success or not size then
		return true
	end

	local checkSize = size * 1.2
	local checkCFrame = CFrame.new(position)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local excludeList = {
		Workspace.Terrain,
		objectFolders.Vegetation,
		objectFolders.Rocks,
		objectFolders.Structures
	}

	if excludeModel then
		table.insert(excludeList, excludeModel)
	end

	overlapParams.FilterDescendantsInstances = excludeList

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

local function spawnModel(originalModel, x, z, category, chunkSize)
	
	if not originalModel then return nil end
	local terrainHeight = terrain.getTerrainHeight(x, z)
	
	local testPosition = Vector3.new(x, terrainHeight, z)
	if not isAreaClear(testPosition, originalModel, originalModel) then
		return nil
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
	
	if model:IsA("Model") then
		if not model.PrimaryPart then
			local firstPart = model:FindFirstChildOfClass("BasePart")
			if firstPart then
				model.PrimaryPart = firstPart
			else
				warn("Model", model.Name, "has no BaseParts, skipping spawn")
				model:Destroy()
				return nil
			end
		end
		model:SetPrimaryPartCFrame(CFrame.new(initialPosition))
	elseif model:IsA("MeshPart") then
		model.CFrame = CFrame.new(initialPosition)
	end
	
	if scale ~= 1 then
		local scaleFactor = scale
		if model:IsA("Model") then
			model:ScaleTo(scaleFactor)
		elseif model:IsA("MeshPart") then
			model.Size = model.Size * scaleFactor
		end
	end
	
	local cf, size
	if model:IsA("Model") then
		cf, size = model:GetBoundingBox()
	elseif model:IsA("MeshPart") then
		cf = model.CFrame
		size = model.Size
	end
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
	
	-- Handle positioning adjustments differently for Models vs MeshParts
	local currentCFrame
	if model:IsA("Model") then
		if model.PrimaryPart then
			currentCFrame = model:GetPrimaryPartCFrame()
			model:SetPrimaryPartCFrame(currentCFrame + Vector3.new(0, yOffset, 0))
		end
	elseif model:IsA("MeshPart") then
		currentCFrame = model.CFrame
		model.CFrame = currentCFrame + Vector3.new(0, yOffset, 0)
	end
	
	if ModelSpawnerConfig.RANDOM_ROTATION then
		local randomYRotation = random:NextNumber(0, 360)
		if model:IsA("Model") then
			if model.PrimaryPart then
				model:SetPrimaryPartCFrame(model:GetPrimaryPartCFrame() * CFrame.Angles(0, math.rad(randomYRotation), 0))
			end
		elseif model:IsA("MeshPart") then
			model.CFrame = model.CFrame * CFrame.Angles(0, math.rad(randomYRotation), 0)
		end
	end
	
	chunkSize = chunkSize or 32  -- Default fallback
	local chunkKey = math.floor(x/chunkSize) .. "," .. math.floor(z/chunkSize)
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
							
							if isPositionValid(worldX, worldZ, category, minDistance, chunkSize) then
								local subSize = chunkSize / subdivisions
								local offsetX = random:NextNumber(-subSize/3, subSize/3)
								local offsetZ = random:NextNumber(-subSize/3, subSize/3)
								
								local modelToSpawn = selectRandom(category)
								if modelToSpawn then
									spawnModel(modelToSpawn, worldX + offsetX, worldZ + offsetZ, category, chunkSize)
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
