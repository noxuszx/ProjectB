--[[
	VillageSpawner.lua
	Handles spawning of village structures with mandatory core layout
	REFACTORED: Now ensures every village has Campfire + Shop1/Shop2/Well
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local villageConfig = require(ReplicatedStorage.Shared.config.Village)
local terrain = require(ReplicatedStorage.Shared.utilities.Terrain)
local ChunkConfig = require(ReplicatedStorage.Shared.config.ChunkConfig)
local FrameBatched = require(ReplicatedStorage.Shared.utilities.FrameBatched)
local FrameBudgetConfig = require(ReplicatedStorage.Shared.config.FrameBudgetConfig)

local VillageSpawner = {}
local random = Random.new()

-- Prepare lookup of mandatory structures
local mandatorySet = {}
for _, name in ipairs(villageConfig.MANDATORY_STRUCTURES) do
    mandatorySet[name] = true
end

-- Configuration constants
local PLAYER_SPAWN_PROTECT_RADIUS = 50 -- studs to keep clear around world origin
local MAX_ATTEMPTS = 10 -- Maximum attempts to place a structure

-- Create organized folder for spawned villages
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

-- Utility: 2-D AABB overlap check on X-Z plane
local function rectsOverlap(a, b)
	return (a.xMin < b.xMax) and (a.xMax > b.xMin) and (a.zMin < b.zMax) and (a.zMax > b.zMin)
end

-- Helper: Calculate AABB rect for a model at given position with buffer
local function calculateRect(modelTemplate, cframe, buffer)
	-- Clone without parenting to measure footprint
	local tempClone = modelTemplate:Clone()
	if not tempClone.PrimaryPart then
		local firstPart = tempClone:FindFirstChildOfClass("BasePart")
		if firstPart then tempClone.PrimaryPart = firstPart end
	end
	if tempClone.PrimaryPart then
		tempClone:SetPrimaryPartCFrame(cframe)
	end
	local cf, size = tempClone:GetBoundingBox()
	tempClone:Destroy()

	-- Build expanded rect in X-Z with buffer
	local halfX = size.X / 2 + buffer
	local halfZ = size.Z / 2 + buffer
	local rect = {
		xMin = cf.Position.X - halfX,
		xMax = cf.Position.X + halfX,
		zMin = cf.Position.Z - halfZ,
		zMax = cf.Position.Z + halfZ,
	}
	
	return rect, cf, size
end

-- Helper: Apply rotation based on village rotation mode
local function applyRotation(baseCFrame, chunkPosition, modelName)
	local rotationSettings = villageConfig.ROTATION_SETTINGS[villageConfig.ROTATION_MODE]
	local cframe = baseCFrame
	
	-- Campfire gets no rotation (identity)
	if modelName == "Campfire" then
		return cframe
	end
	
	-- Apply rotation for other structures
	if villageConfig.ROTATION_MODE == "CARDINAL" then
		local angle = rotationSettings.angles[random:NextInteger(1, #rotationSettings.angles)]
		cframe = cframe * CFrame.Angles(0, math.rad(angle), 0)
	elseif villageConfig.ROTATION_MODE == "CENTER_FACING" then
		local directionToCenter = (chunkPosition - baseCFrame.Position).Unit
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
	
	return cframe
end

-- Helper: Check if position is valid (not in protected spawn zone)
local function isValidPosition(position, halfX, halfZ)
	return position.Magnitude >= (PLAYER_SPAWN_PROTECT_RADIUS + math.max(halfX, halfZ))
end

-- Helper: Place campfire at village center
local function placeCampfire(models, villageCenter, occupiedRects)
	local modelTemplate = models["Campfire"]
	if not modelTemplate then
		warn("[VillageSpawner] Campfire model not found")
		return nil
	end
	
	-- Determine terrain height at center
	local terrainHeight = terrain.getTerrainHeight(villageCenter.X, villageCenter.Z)
	local baseCFrame = CFrame.new(villageCenter.X, terrainHeight, villageCenter.Z)
	
	-- Apply rotation (none for campfire)
	local cframe = applyRotation(baseCFrame, villageCenter, "Campfire")
	
	-- Calculate rect with campfire buffer
	local rect, cf, size = calculateRect(modelTemplate, cframe, villageConfig.CAMPFIRE_BUFFER)
	
	-- Check if position is valid
	local halfX = size.X / 2 + villageConfig.CAMPFIRE_BUFFER
	local halfZ = size.Z / 2 + villageConfig.CAMPFIRE_BUFFER
	if not isValidPosition(cf.Position, halfX, halfZ) then
		return nil
	end
	
	-- Add to occupied rects
	table.insert(occupiedRects, rect)
	
	return {
		modelName = "Campfire",
		cframe = cframe,
		rect = rect,
		size = size
	}
end

-- Helper: Place mandatory structure (Shop1, Shop2, Well)
local function placeMandatory(models, name, chunkPosition, occupiedRects)
	local modelTemplate = models[name]
	if not modelTemplate then
		warn("[VillageSpawner] Mandatory model not found:", name)
		return nil
	end
	
	-- Try up to MAX_ATTEMPTS to find valid position
	for attempt = 1, MAX_ATTEMPTS do
		local offsetX = random:NextNumber(-villageConfig.VILLAGE_RADIUS, villageConfig.VILLAGE_RADIUS)
		local offsetZ = random:NextNumber(-villageConfig.VILLAGE_RADIUS, villageConfig.VILLAGE_RADIUS)
		local flatPosition = chunkPosition + Vector3.new(offsetX, 0, offsetZ)
		
		-- Determine terrain height at candidate
		local terrainHeight = terrain.getTerrainHeight(flatPosition.X, flatPosition.Z)
		local baseCFrame = CFrame.new(flatPosition.X, terrainHeight, flatPosition.Z)
		
		-- Apply rotation
		local cframe = applyRotation(baseCFrame, chunkPosition, name)
		
		-- Calculate rect with structure spacing
		local rect, cf, size = calculateRect(modelTemplate, cframe, villageConfig.STRUCTURE_SPACING)
		
		-- Check if position is valid
		local halfX = size.X / 2 + villageConfig.STRUCTURE_SPACING
		local halfZ = size.Z / 2 + villageConfig.STRUCTURE_SPACING
		if not isValidPosition(cf.Position, halfX, halfZ) then
			continue
		end
		
		-- Check overlap with already placed structures
		local hasOverlap = false
		for _, oRect in ipairs(occupiedRects) do
			if rectsOverlap(rect, oRect) then
				hasOverlap = true
				break
			end
		end
		
		if not hasOverlap then
			-- Success! Add to occupied rects
			table.insert(occupiedRects, rect)
			return {
				modelName = name,
				cframe = cframe,
				rect = rect,
				size = size
			}
		end
	end
	
	-- Failed to place after MAX_ATTEMPTS
	return nil
end

-- Helper: Place optional structure
local function placeOptional(models, name, chunkPosition, occupiedRects)
	-- Use same logic as mandatory but don't warn on failure
	return placeMandatory(models, name, chunkPosition, occupiedRects)
end

-- Main village spawning function
local function spawnVillage(models, chunkPosition)
	local occupiedRects = {} -- keeps placed structure footprints to prevent overlaps
	local placementInfos = {}
	
	-- Step 1: Place Campfire at village center
	local campfireInfo = placeCampfire(models, chunkPosition, occupiedRects)
	if not campfireInfo then
		warn("[VillageSpawner] Mandatory structure failed – skipping village (Campfire placement failed)")
		return false
	end
	table.insert(placementInfos, campfireInfo)
	
	-- Step 2: Place mandatory structures (Shop1, Shop2, Well)
for _, structureName in ipairs(villageConfig.MANDATORY_STRUCTURES) do
    if structureName ~= "Campfire" then -- Campfire already placed
		local placementInfo = placeMandatory(models, structureName, chunkPosition, occupiedRects)
		if not placementInfo then
warn("[VillageSpawner] mandatory '"..structureName.."' failed – skipping village")
			return false
		end
table.insert(placementInfos, placementInfo)
    end
end
	
	-- Step 3: Place optional structures
	local mandatoryCount = #villageConfig.MANDATORY_STRUCTURES
	local numStructures = random:NextInteger(villageConfig.STRUCTURES_PER_VILLAGE[1], villageConfig.STRUCTURES_PER_VILLAGE[2])
	local optionalCount = math.max(0, numStructures - mandatoryCount)
	
-- Optional pool without mandatory names
local optionalPool = {}
for _, name in ipairs(villageConfig.AVAILABLE_STRUCTURES) do
    if not mandatorySet[name] then
        table.insert(optionalPool, name)
    end
end
-- Safeguard: if pool is empty, skip optional placement
if #optionalPool > 0 then
for _, name in ipairs(villageConfig.AVAILABLE_STRUCTURES) do
    if not mandatorySet[name] then
        table.insert(optionalPool, name)
    end
end

for i = 1, optionalCount do
    local randomStructure = optionalPool[random:NextInteger(1, #optionalPool)]
		local placementInfo = placeOptional(models, randomStructure, chunkPosition, occupiedRects)
		if placementInfo then
			table.insert(placementInfos, placementInfo)
		end
-- Continue even if optional structure fails to place
    end
end
	
	-- Step 4: Actually spawn all placed structures (frame-batched)
	local batchSize = FrameBudgetConfig.getBatchSize("VILLAGES")
	FrameBatched.run(placementInfos, batchSize, function(info)
		local model = models[info.modelName]
		local clonedModel = model:Clone()
		
		if not clonedModel.PrimaryPart then
			local firstPart = clonedModel:FindFirstChildOfClass("BasePart")
			if firstPart then clonedModel.PrimaryPart = firstPart end
		end
		
		clonedModel:SetPrimaryPartCFrame(info.cframe)
		clonedModel.Parent = villageFolder
	end)
	
	return true
end

-- Spawn all villages with frame batching
function VillageSpawner.spawnVillages()
	print("Spawning villages...")
	local models = loadVillageModels()
	
	-- Check if we have any models to spawn
	if next(models) == nil then
		warn("No village models found in", villageConfig.VILLAGE_MODEL_FOLDER)
		return
	end
	
	-- Verify mandatory structures exist
	for _, structureName in ipairs(villageConfig.MANDATORY_STRUCTURES) do
		if not models[structureName] then
			warn("[VillageSpawner] Mandatory structure missing:", structureName)
			return
		end
	end
	
	-- Generate list of village positions to spawn
	local numVillages = random:NextInteger(villageConfig.VILLAGES_TO_SPAWN[1], villageConfig.VILLAGES_TO_SPAWN[2])
	local villageJobs = {}
	local attempts = 0
	local maxAttempts = numVillages * 5

	-- Build job list of potential village positions
	while #villageJobs < numVillages and attempts < maxAttempts do
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
		table.insert(villageJobs, chunkPosition)
		attempts = attempts + 1
	end

	-- Process village jobs with frame batching
	local spawnedVillages = 0
	local batchSize = FrameBudgetConfig.getBatchSize("VILLAGES")
	
	FrameBatched.run(villageJobs, batchSize, function(chunkPosition)
		local success = spawnVillage(models, chunkPosition)
		if success then
			spawnedVillages = spawnedVillages + 1
		end
	end)

	print(spawnedVillages .. " out of " .. numVillages .. " villages spawned successfully!")
end

return VillageSpawner