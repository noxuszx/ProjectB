--[[
	CustomModelSpawner.lua
	Spawns custom models from ReplicatedStorage folders
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ModelSpawnerConfig = require(ReplicatedStorage.Shared.config.ModelSpawnerConfig)
local terrain = require(ReplicatedStorage.Shared.utilities.Terrain)
local FrameBatched = require(ReplicatedStorage.Shared.utilities.FrameBatched)
local FrameBudgetConfig = require(ReplicatedStorage.Shared.config.FrameBudgetConfig)
local TemplateCache = require(ReplicatedStorage.Shared.utilities.TemplateCache)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local CustomModelSpawner = {}
local spawnedObjects = {}
local availableModels = {
	Vegetation = {},
	Rocks = {},
	Structures = {}
}

-- Template cache and weighted selection
local templateCache = nil
local weightedSelection = {}
local protectedOverlapParams = nil

local objectFolders = {}
for category in pairs(availableModels) do
	local folder = Instance.new("Folder")
	folder.Name = "Spawned" .. category
	folder.Parent = Workspace
	objectFolders[category] = folder
end

local random = Random.new()

-- Build cumulative weight distribution for weighted random selection
local function buildWeightedSelection(category, models)
	local weights = ModelSpawnerConfig.MODEL_WEIGHTS[category] or {}
	local cumulative = {}
	local total = 0
	
	for i, model in ipairs(models) do
		local weight = weights[model.Name] or 1.0  -- Default weight of 1.0
		total = total + weight
		cumulative[i] = {model = model, threshold = total}
	end
	
	weightedSelection[category] = {
		cumulative = cumulative,
		total = total
	}
	
	local weightedCount = 0
	for modelName, _ in pairs(weights) do
		weightedCount = weightedCount + 1
	end
	
	print("[CustomModelSpawner]", category, "weighted selection built - Total weight:", total, "Weighted models:", weightedCount)
end

-- Scan ReplicatedStorage folders and build weighted selection + template cache
local function scanAvailableModels()
	print("[CustomModelSpawner] Scanning for available models...")
	
	-- Initialize template cache
	templateCache = TemplateCache.new()
	
	for category, folderPath in pairs(ModelSpawnerConfig.MODEL_FOLDERS) do
		local folder = ReplicatedStorage
		for part in folderPath:gmatch("[^%.]+") do
			folder = folder:FindFirstChild(part)
			if not folder then
				warn("[CustomModelSpawner] Model folder not found:", folderPath)
				break
			end
		end
		
		if folder then
			local categoryModels = {}
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") or model:IsA("MeshPart") then
					-- Cache bounding box for model or meshpart
					templateCache:addTemplate(model)
					table.insert(availableModels[category], model)
					table.insert(categoryModels, model)
					print("[CustomModelSpawner] Found", category, model:IsA("Model") and "model:" or "meshpart:", model.Name)
				end
			end
			
			-- Build weighted selection for this category
			buildWeightedSelection(category, categoryModels)
		end
	end

	for category, models in pairs(availableModels) do
		print("[CustomModelSpawner]", category .. " models found:", #models)
	end
end



-- Check spawn protection zone
local function isInSpawnProtection(x, z)
	local distance = math.sqrt(x^2 + z^2)
	return distance <= ModelSpawnerConfig.SPAWN_PROTECTION_RADIUS
end

local function isPositionValid(x, z, category, minDistance, chunkSize)
	-- Check spawn protection zone first
	if isInSpawnProtection(x, z) then
		return false
	end
	
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

-- Weighted random selection using cumulative distribution
local function selectWeighted(category)
	local selection = weightedSelection[category]
	if not selection or #selection.cumulative == 0 then
		return nil
	end
	
	local randomValue = random:NextNumber() * selection.total
	
	for i, entry in ipairs(selection.cumulative) do
		if randomValue <= entry.threshold then
			return entry.model
		end
	end
	
	-- Fallback to last model (should rarely happen)
	return selection.cumulative[#selection.cumulative].model
end

-- Initialize cached OverlapParams for protected geometry detection
local function initializeOverlapParams()
	-- Get fresh protected objects list (called once during init, after all spawners have run)
	local protectedObjects = CollectionServiceTags.getAllProtectedObjects()
	
	if not protectedOverlapParams then
		protectedOverlapParams = OverlapParams.new()
		protectedOverlapParams.FilterType = Enum.RaycastFilterType.Include
		protectedOverlapParams.MaxParts = 1  -- Early exit on first hit
	end
	
	-- Update the filter with current protected objects
	protectedOverlapParams.FilterDescendantsInstances = protectedObjects
	
	if ModelSpawnerConfig.DEBUG then
		print("[CustomModelSpawner] Initialized overlap params with", #protectedObjects, "protected objects")
	end
end

-- Check if an area is clear using optimized tag-based collision detection
local function isAreaClear(position, modelName, category)
	-- Use cached bounding box if available
	local boundingBox = templateCache and templateCache:getBoundingBox(modelName)
	if not boundingBox then
		-- Fallback to small default size
		boundingBox = {size = Vector3.new(2, 2, 2)}
		warn("[CustomModelSpawner] No cached bounding box for", modelName, "using default")
	end
	
	local checkSize = boundingBox.size * 1.2  -- 20% padding for safety
	local checkCFrame = CFrame.new(position)
	
	-- Use pre-initialized overlap params (no refresh needed during spawning)
	
	-- Check for protected geometry overlap using tags
	local overlappingParts = Workspace:GetPartBoundsInBox(checkCFrame, checkSize, protectedOverlapParams)
	
	if #overlappingParts > 0 then
		-- Found protected geometry in the area
		return false
	end
	
	-- Additional checks for creature folders (not protected but should be avoided)
	local excludeParams = OverlapParams.new()
	excludeParams.FilterType = Enum.RaycastFilterType.Exclude
	excludeParams.FilterDescendantsInstances = {
		Workspace.Terrain,
		objectFolders.Vegetation,
		objectFolders.Rocks,  
		objectFolders.Structures
	}
	
	local generalOverlap = Workspace:GetPartBoundsInBox(checkCFrame, checkSize, excludeParams)
	
	for _, part in pairs(generalOverlap) do
		local parent = part.Parent
		if parent and (
			parent.Name == "SpawnedCreatures" or
			parent.Name == "DroppedFood" or
			parent.Name == "PassiveCreatures" or
			parent.Name == "HostileCreatures"
		) then
			return false
		end
	end
	
	return true
end

local function spawnModel(originalModel, x, z, category, chunkSize)
	
	if not originalModel then return nil end
	local terrainHeight = terrain.getTerrainHeight(x, z)
	
	local testPosition = Vector3.new(x, terrainHeight, z)
	if not isAreaClear(testPosition, originalModel.Name, category) then
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
	
	-- Accumulate spawn candidates by category
	local toSpawn = {
		Vegetation = {},
		Rocks = {},
		Structures = {}
	}
	
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
								
								local modelToSpawn = selectWeighted(category)
								if modelToSpawn then
									-- Add to spawn candidates instead of spawning immediately
									table.insert(toSpawn[category], {
										model = modelToSpawn,
										x = worldX + offsetX,
										z = worldZ + offsetZ,
										category = category,
										chunkSize = chunkSize
									})
									counters[category] = counters[category] + 1
								end
							end
						end
					end
				end
			end
		end
	end
	
	-- Process spawn candidates with frame batching by category
	local batchSizes = FrameBudgetConfig.getModelBatchSizes()
	
	for category, candidates in pairs(toSpawn) do
		if #candidates > 0 then
			FrameBatched.run(candidates, batchSizes[category], function(candidate)
				spawnModel(candidate.model, candidate.x, candidate.z, candidate.category, candidate.chunkSize)
			end)
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
	print("[CustomModelSpawner] Initializing custom model spawner...")
	
	scanAvailableModels()
	
	-- Initialize overlap parameters ONCE after all other spawners have run
	initializeOverlapParams()
	
	local totalModels = 0
	for category, models in pairs(availableModels) do
		totalModels = totalModels + #models
	end
	
	if totalModels == 0 then
		print("[CustomModelSpawner] No models found in ReplicatedStorage.Models folders. Skipping object spawning.")
		return
	end
	
	-- Report template cache statistics
	if templateCache and ModelSpawnerConfig.DEBUG then
		local stats = templateCache:getStats()
		print("[CustomModelSpawner] Template cache stats:", stats.templateCount, "templates,", stats.memoryEstimateKB, "KB estimated")
	end
	
	CustomModelSpawner.clearObjects()
	
	-- Build chunk job list
	local chunkJobs = {}
	for cx = -renderDistance, renderDistance do
		for cz = -renderDistance, renderDistance do
			table.insert(chunkJobs, {cx = cx, cz = cz, chunkSize = chunkSize, subdivisions = subdivisions})
		end
	end
	
	-- Process chunks with frame batching
	local batchSize = FrameBudgetConfig.getBatchSize("CHUNK_PROCESSING")
	FrameBatched.run(chunkJobs, batchSize, function(job)
		CustomModelSpawner.spawnInChunk(job.cx, job.cz, job.chunkSize, job.subdivisions)
	end)
	
	print("[CustomModelSpawner] Custom model spawning complete!")
end

-- Debug functions for testing and monitoring
function CustomModelSpawner.getStats()
	local stats = {
		spawnedObjectCount = 0,
		protectedObjectCount = #(CollectionServiceTags.getAllProtectedObjects()),
		templateCacheStats = templateCache and templateCache:getStats() or nil,
		weightedCategoryCount = 0
	}
	
	-- Count spawned objects
	for chunkKey, chunkData in pairs(spawnedObjects) do
		for category, objects in pairs(chunkData) do
			stats.spawnedObjectCount = stats.spawnedObjectCount + #objects
		end
	end
	
	-- Count weighted categories
	for category, selection in pairs(weightedSelection) do
		if selection.total > 0 then
			stats.weightedCategoryCount = stats.weightedCategoryCount + 1
		end
	end
	
	return stats
end

function CustomModelSpawner.testSpawnProtection(testPositions)
	testPositions = testPositions or {
		{x = 0, z = 0},      -- Dead center (should fail)
		{x = 25, z = 25},    -- Close to spawn (should fail)
		{x = 60, z = 60},    -- Outside protection (should pass)
	}
	
	print("[CustomModelSpawner] Testing spawn protection...")
	for i, pos in ipairs(testPositions) do
		local inProtection = isInSpawnProtection(pos.x, pos.z)
		print(string.format("Position (%d,%d): %s", pos.x, pos.z, 
			inProtection and "PROTECTED ❌" or "ALLOWED ✅"))
	end
end

function CustomModelSpawner.testWeightedSelection(category, samples)
	if not ModelSpawnerConfig.DEBUG then
		return
	end
	
	category = category or "Vegetation"
	samples = samples or 100
	
	local selection = weightedSelection[category]
	if not selection then
		print("[CustomModelSpawner] No weighted selection found for category:", category)
		return
	end
	
	print("[CustomModelSpawner] Testing weighted selection for", category, "with", samples, "samples...")
	
	local counts = {}
	for i = 1, samples do
		local model = selectWeighted(category)
		if model then
			counts[model.Name] = (counts[model.Name] or 0) + 1
		end
	end
	
	print("Results:")
	for modelName, count in pairs(counts) do
		local percentage = math.floor(count / samples * 100 + 0.5)
		print(string.format("  %s: %d/%d (%d%%)", modelName, count, samples, percentage))
	end
end

function CustomModelSpawner.debugProtectedObjects()
	if not ModelSpawnerConfig.DEBUG then
		return {}
	end
	
	local protected = CollectionServiceTags.getAllProtectedObjects()
	print("[CustomModelSpawner] Protected objects found:", #protected)
	
	local counts = {village = 0, core = 0, spawner = 0}
	for _, obj in pairs(protected) do
		if CollectionServiceTags.hasTag(obj, CollectionServiceTags.PROTECTED_VILLAGE) then
			counts.village = counts.village + 1
		end
		if CollectionServiceTags.hasTag(obj, CollectionServiceTags.PROTECTED_CORE) then
			counts.core = counts.core + 1
		end
		if CollectionServiceTags.hasTag(obj, CollectionServiceTags.PROTECTED_SPAWNER) then
			counts.spawner = counts.spawner + 1
		end
	end
	
	print("  Villages:", counts.village, "Core:", counts.core, "Spawners:", counts.spawner)
	return counts
end

return CustomModelSpawner
