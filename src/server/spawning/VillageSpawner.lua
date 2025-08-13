--[[
	VillageSpawner.lua
	Handles spawning of village structures with mandatory core layout
	REFACTORED: Now ensures every village has Campfire + Shop1/Shop2/Well
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace 		= game:GetService("Workspace")

local villageConfig 		= require(ReplicatedStorage.Shared.config.Village)
local terrain 				= require(ReplicatedStorage.Shared.utilities.Terrain)
local ChunkConfig 			= require(ReplicatedStorage.Shared.config.ChunkConfig)
local FrameBatched 			= require(ReplicatedStorage.Shared.utilities.FrameBatched)
local FrameBudgetConfig 	= require(ReplicatedStorage.Shared.config.FrameBudgetConfig)
local CoreStructureSpawner  = require(script.Parent.CoreStructureSpawner)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local random = Random.new()

local VillageSpawner = {}
local mandatorySet 	 = {}
local spawnedVillageCenters = {}

local PLAYER_SPAWN_PROTECT_RADIUS = 50
local MAX_ATTEMPTS = 40

local villageFolder = Instance.new("Folder")
villageFolder.Name = "SpawnedVillages"
villageFolder.Parent = Workspace

for _, name in ipairs(villageConfig.MANDATORY_STRUCTURES) do
    mandatorySet[name] = true
end

-----------------------------------------------------------------------------------------------------
---------------------- LOAD MODELS ------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------

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

local function rectsOverlap(a, b)
	return (a.xMin < b.xMax) and (a.xMax > b.xMin) and (a.zMin < b.zMax) and (a.zMax > b.zMin)
end

local function calculateRect(modelTemplate, cframe, buffer)
	local tempClone = modelTemplate:Clone()
	-- Use PivotTo to position the clone for bounding box calculation without requiring a PrimaryPart
	tempClone:PivotTo(cframe)
	local cf, size = tempClone:GetBoundingBox()
	tempClone:Destroy()

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

-------------------------------------------------------------------------------------------------
--------------- HELPERS -------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------


local function applyRotation(baseCFrame, chunkPosition, modelName)
	local rotationSettings = villageConfig.ROTATION_SETTINGS[villageConfig.ROTATION_MODE]
	local cframe = baseCFrame
	
	if modelName == "Campfire" then
		return cframe
	end
	
	if villageConfig.ROTATION_MODE 	   == "CARDINAL" then

		-- Snap rotation to the nearest cardinal angle that faces the village center
		local basePos = baseCFrame.Position
		local centerPos = Vector3.new(chunkPosition.X, basePos.Y, chunkPosition.Z)
		local dir = (centerPos - basePos)
		local desiredDeg
		if dir.Magnitude ~= 0 then
			desiredDeg = math.deg(math.atan2(dir.X, dir.Z))
		else
			desiredDeg = 0
		end
		local offset = rotationSettings.angle_offset or 0
		desiredDeg = desiredDeg + offset
		
		local nearest = rotationSettings.angles[1]
		local function angDiff(a, b)
			local d = (a - b) % 360
			if d > 180 then d = d - 360 end
			return math.abs(d)
		end
		for i = 2, #rotationSettings.angles do
			local cand = rotationSettings.angles[i]
			if angDiff(cand, desiredDeg) < angDiff(nearest, desiredDeg) then
				nearest = cand
			end
		end
		cframe = cframe * CFrame.Angles(0, math.rad(nearest), 0)

	elseif villageConfig.ROTATION_MODE == "CENTER_FACING" then

		-- Use CFrame.lookAt to face the village center, with optional yaw offset
		local basePos = baseCFrame.Position
		local centerPos = Vector3.new(chunkPosition.X, basePos.Y, chunkPosition.Z)
		local facing = CFrame.lookAt(basePos, centerPos)
		local offset = rotationSettings.angle_offset or 0
		cframe = facing * CFrame.Angles(0, math.rad(offset), 0)

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


local function overlapsWithCoreStructures(position, radius)
	local coreCircles = CoreStructureSpawner.getOccupiedCircles()
	for _, circle in ipairs(coreCircles) do
		local distance = (position - circle.centre).Magnitude
		if distance < (radius + circle.radius) then
			return true
		end
	end
	return false
end


local function isValidPosition(position, halfX, halfZ)
	local maxRadius = math.max(halfX, halfZ)
	
	if position.Magnitude < (PLAYER_SPAWN_PROTECT_RADIUS + maxRadius) then
		return false
	end
	
	if overlapsWithCoreStructures(position, maxRadius) then
		return false
	end
	
	return true
end


local function placeCampfire(models, villageCenter, occupiedRects)
	local modelTemplate = models["Campfire"]
	if not modelTemplate then
		warn("[VillageSpawner] Campfire model not found")
		return nil
	end
	
	local terrainHeight = terrain.getTerrainHeight(villageCenter.X, villageCenter.Z)
	local baseCFrame = CFrame.new(villageCenter.X, terrainHeight, villageCenter.Z)
	
	local cframe = applyRotation(baseCFrame, villageCenter, "Campfire")
	local rect, cf, size = calculateRect(modelTemplate, cframe, villageConfig.CAMPFIRE_BUFFER)
	
	local halfX = size.X / 2 + villageConfig.CAMPFIRE_BUFFER
	local halfZ = size.Z / 2 + villageConfig.CAMPFIRE_BUFFER
	if not isValidPosition(cf.Position, halfX, halfZ) then
		return nil
	end
	
	table.insert(occupiedRects, rect)
	
	return {
		modelName = "Campfire",
		cframe = cframe,
		rect = rect,
		size = size
	}
end


local function placeMandatory(models, name, chunkPosition, occupiedRects)
	local modelTemplate = models[name]
	if not modelTemplate then
		warn("[VillageSpawner] Mandatory model not found:", name)
		return nil
	end
	
	for attempt = 1, MAX_ATTEMPTS do

		local offsetX = random:NextNumber(-villageConfig.VILLAGE_RADIUS, villageConfig.VILLAGE_RADIUS)
		local offsetZ = random:NextNumber(-villageConfig.VILLAGE_RADIUS, villageConfig.VILLAGE_RADIUS)
		local flatPosition = chunkPosition + Vector3.new(offsetX, 0, offsetZ)
		
		local terrainHeight = terrain.getTerrainHeight(flatPosition.X, flatPosition.Z)
		local baseCFrame = CFrame.new(flatPosition.X, terrainHeight, flatPosition.Z)
		
		local cframe = applyRotation(baseCFrame, chunkPosition, name)
		local rect, cf, size = calculateRect(modelTemplate, cframe, villageConfig.STRUCTURE_SPACING)
		
		local halfX = size.X / 2 + villageConfig.STRUCTURE_SPACING
		local halfZ = size.Z / 2 + villageConfig.STRUCTURE_SPACING
		if not isValidPosition(cf.Position, halfX, halfZ) then
			continue
		end
		
		local hasOverlap = false
		for _, oRect in ipairs(occupiedRects) do
			if rectsOverlap(rect, oRect) then
				hasOverlap = true
				break
			end
		end
		
		if not hasOverlap then
			table.insert(occupiedRects, rect)
			return {
				modelName = name,
				cframe = cframe,
				rect = rect,
				size = size
			}
		end
	end
	
	return nil
end

local function placeOptional(models, name, chunkPosition, occupiedRects)
	return placeMandatory(models, name, chunkPosition, occupiedRects)
end

-------------------------------------------------------------------------------------------------
------------------ MAIN SPAWNING ----------------------------------------------------------------
-------------------------------------------------------------------------------------------------

local function spawnVillage(models, chunkPosition)

	local occupiedRects  = {}
	local placementInfos = {}

	local campfireInfo = placeCampfire(models, chunkPosition, occupiedRects)
	if not campfireInfo then
		warn("[VillageSpawner] Mandatory structure failed – skipping village (Campfire placement failed)")
		return false
	end

	table.insert(placementInfos, campfireInfo)
	
	for _, structureName in ipairs(villageConfig.MANDATORY_STRUCTURES) do
    if structureName ~= "Campfire" then
		local placementInfo = placeMandatory(models, structureName, chunkPosition, occupiedRects)
		if not placementInfo then
	warn("[VillageSpawner] mandatory '"..structureName.."' failed – skipping village")
			return false
		end
	table.insert(placementInfos, placementInfo)
    	end
	end

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
		for i = 1, optionalCount do
    		local randomStructure = optionalPool[random:NextInteger(1, #optionalPool)]
				local placementInfo = placeOptional(models, randomStructure, chunkPosition, occupiedRects)
				if placementInfo then
					table.insert(placementInfos, placementInfo)
				end
    		end
	end
	
	-- Step 4: Actually spawn all placed structures (frame-batched)
	local batchSize = FrameBudgetConfig.getBatchSize("VILLAGES")
	FrameBatched.run(placementInfos, batchSize, function(info)
		local model = models[info.modelName]
		local clonedModel = model:Clone()
		
		-- Use PivotTo for placement instead of relying on PrimaryPart
		clonedModel:PivotTo(info.cframe)
		clonedModel.Parent = villageFolder
		
		-- Tag village structure as protected geometry
		CollectionServiceTags.tagDescendants(clonedModel, CollectionServiceTags.PROTECTED_VILLAGE)
	end)
	
	return true
end
-------------------------------------------------------------------------------------------------
---------- FRAME BATCHING -----------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

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
	
	-- Reset spawned village centers tracking
	spawnedVillageCenters = {}
	
	-- Generate list of village positions to spawn
	local numVillages = random:NextInteger(villageConfig.VILLAGES_TO_SPAWN[1], villageConfig.VILLAGES_TO_SPAWN[2])
	local villageJobs = {}
	local attempts = 0
	local maxAttempts = numVillages * 20

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
	
	local function isFarFromExisting(pos)
		-- If min distance is 0 or not set, allow all placements
		if not villageConfig.MIN_VILLAGE_DISTANCE or villageConfig.MIN_VILLAGE_DISTANCE <= 0 then
			return true
		end
		for _, existing in ipairs(spawnedVillageCenters) do
			if (pos - existing).Magnitude < villageConfig.MIN_VILLAGE_DISTANCE then
				return false
			end
		end
		return true
	end
	
	FrameBatched.run(villageJobs, batchSize, function(chunkPosition)
		-- Enforce minimum distance between villages
		if not isFarFromExisting(chunkPosition) then
			return
		end
		local success = spawnVillage(models, chunkPosition)
		if success then
			spawnedVillages = spawnedVillages + 1
			table.insert(spawnedVillageCenters, chunkPosition)
		end
	end)

	print(spawnedVillages .. " out of " .. numVillages .. " villages spawned successfully!")
end

-- Debug helpers
function VillageSpawner.getSpawnedVillagePositions()
	return spawnedVillageCenters
end

function VillageSpawner.debugPrint()
	print("[VillageSpawner] Spawned villages:", #spawnedVillageCenters)
	for i, pos in ipairs(spawnedVillageCenters) do
		print(string.format("  %d) (%.1f, %.1f, %.1f)", i, pos.X, pos.Y, pos.Z))
	end
end

return VillageSpawner
