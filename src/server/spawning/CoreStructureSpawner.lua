--[[
	CoreStructureSpawner.lua
	Spawns massive landmark structures (Pyramid, Towers) before all other systems
	Uses circle-based collision detection and frame batching
]]
--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace 		= game:GetService("Workspace")

local CoreStructureConfig 	= require(ReplicatedStorage.Shared.config.CoreStructureConfig)
local ChunkConfig 			= require(ReplicatedStorage.Shared.config.ChunkConfig)
local terrain 				= require(ReplicatedStorage.Shared.utilities.Terrain)
local FrameBatched 			= require(ReplicatedStorage.Shared.utilities.FrameBatched)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local random = Random.new()

local CoreStructureSpawner = {}
local occupiedCircles 	   = {}

-- Debug configuration
local DEBUG_ENABLED = false

local coreStructureFolder = Instance.new("Folder")
coreStructureFolder.Name = "CoreStructures"
coreStructureFolder.Parent = Workspace


---------------------------------------------------------------------------------------

local function loadStructureModels()
	local models = {}
	local coreFolder = ReplicatedStorage

	for part in CoreStructureConfig.MODEL_FOLDER:gmatch("[^%.]+") do
		coreFolder = coreFolder:FindFirstChild(part)
		if not coreFolder then
			warn("[CoreStructureSpawner] Core model folder not found:", CoreStructureConfig.MODEL_FOLDER)
			return models
		end
	end

	for structureName, _ in pairs(CoreStructureConfig.STRUCTURES) do
		local model = coreFolder:FindFirstChild(structureName)
		if model then
			models[structureName] = model
		else
			warn("[CoreStructureSpawner] Structure model not found:", structureName)
		end
	end

	return models
end


local function circlesOverlap(circle1, circle2)
	local distance = (circle1.centre - circle2.centre).Magnitude
	return distance < (circle1.radius + circle2.radius + CoreStructureConfig.MIN_DISTANCE_BETWEEN)
end


local function isInProtectedZone(worldPosition, structureRadius)
	local distanceFromOrigin = worldPosition.Magnitude
	return distanceFromOrigin < (CoreStructureConfig.PLAYER_SPAWN_PROTECT_RADIUS + structureRadius)
end

------------------------------------------------------------------------------------
---------------STRUCTURE PLACING ---------------------------------------------------
------------------------------------------------------------------------------------

local function tryPlaceStructure(structureName, structureProps, models)
	local template = models[structureName]
	if not template then
		warn("[CoreStructureSpawner] Template model not found for:", structureName)
		return false
	end

	for attempt = 1, CoreStructureConfig.MAX_PLACEMENT_ATTEMPTS do
		local chunkX = random:NextInteger(-ChunkConfig.RENDER_DISTANCE, ChunkConfig.RENDER_DISTANCE)
		local chunkZ = random:NextInteger(-ChunkConfig.RENDER_DISTANCE, ChunkConfig.RENDER_DISTANCE)
		local baseX = chunkX * ChunkConfig.CHUNK_SIZE
		local baseZ = chunkZ * ChunkConfig.CHUNK_SIZE

		local edgeMargin = structureProps.radius + ChunkConfig.CHUNK_SIZE * CoreStructureConfig.CHUNK_MARGIN_FACTOR
		if edgeMargin * 2 >= ChunkConfig.CHUNK_SIZE then
			edgeMargin = ChunkConfig.CHUNK_SIZE / 2 - 2 -- ensure some space
		end

		local localX = random:NextNumber(edgeMargin, ChunkConfig.CHUNK_SIZE - edgeMargin)
		local localZ = random:NextNumber(edgeMargin, ChunkConfig.CHUNK_SIZE - edgeMargin)
		local worldPosition = Vector3.new(baseX + localX, 0, baseZ + localZ)

		if isInProtectedZone(worldPosition, structureProps.radius) then
			continue
		end

		local proposedCircle = {
			centre = worldPosition,
			radius = structureProps.radius,
		}

		local hasOverlap = false
		for _, existingCircle in ipairs(occupiedCircles) do
			if circlesOverlap(proposedCircle, existingCircle) then
				hasOverlap = true
				break
			end
		end

		if hasOverlap then
			continue
		end

		local terrainHeight = terrain.getTerrainHeight(worldPosition.X, worldPosition.Z)

		local tempClone = template:Clone()
		local cf, size = tempClone:GetBoundingBox()
		tempClone:Destroy()

		local halfHeight = size.Y / 2
		local embedDepth = halfHeight * structureProps.embedPercentage
		local finalY = terrainHeight + embedDepth
		local pyramidPosition = Vector3.new(worldPosition.X, finalY, worldPosition.Z)
		local targetPosition = Vector3.new(0, finalY, 0)
		local finalCFrame = CFrame.lookAt(pyramidPosition, targetPosition)

		local clone = template:Clone()
		if not clone.PrimaryPart then
			local firstPart = clone:FindFirstChildWhichIsA("BasePart")
			if firstPart then
				clone.PrimaryPart = firstPart
			else
				warn("[CoreStructureSpawner] No BasePart found in structure:", structureName)
				warn("[CoreStructureSpawner] Children found:", clone:GetChildren())
				for _, child in ipairs(clone:GetChildren()) do
					warn("  -", child.Name, "(" .. child.ClassName .. ")")
				end
				clone:Destroy()
				continue
			end
		end

		clone:SetPrimaryPartCFrame(finalCFrame)
		clone.Parent = coreStructureFolder

		CollectionServiceTags.tagDescendants(clone, CollectionServiceTags.PROTECTED_CORE)
		table.insert(occupiedCircles, proposedCircle)

		if DEBUG_ENABLED then
			print(
				"[CoreStructureSpawner]",
				structureName,
				"placed after",
				attempt,
				"attempts at",
				worldPosition,
				"- Tagged as protected"
			)
		end
		return true
	end

	warn(
		"[CoreStructureSpawner] Failed to place",
		structureName,
		"after",
		CoreStructureConfig.MAX_PLACEMENT_ATTEMPTS,
		"attempts"
	)
	return false
end
----------------------------------------------------------------------------
-------- MAIN SPAWNING -----------------------------------------------------
----------------------------------------------------------------------------


function CoreStructureSpawner.spawnLandmarks()
	if DEBUG_ENABLED then print("[CoreStructureSpawner] Spawning core structures...") end

	occupiedCircles = {}
	for _, child in ipairs(coreStructureFolder:GetChildren()) do
		child:Destroy()
	end

	local models = loadStructureModels()

	if next(models) == nil then
		warn("[CoreStructureSpawner] No structure models found in", CoreStructureConfig.MODEL_FOLDER)
		return
	end

	local placementJobs = {}

	if CoreStructureConfig.STRUCTURES.Pyramid and models.Pyramid then
		table.insert(placementJobs, {
			name = "Pyramid",
			props = CoreStructureConfig.STRUCTURES.Pyramid,
		})
	end

	for structureName, structureProps in pairs(CoreStructureConfig.STRUCTURES) do
		if structureName ~= "Pyramid" and models[structureName] then
			table.insert(placementJobs, {
				name = structureName,
				props = structureProps,
			})
		end
	end

	local successfulPlacements = 0
	FrameBatched.run(placementJobs, CoreStructureConfig.BATCH_SIZE, function(job)
		local success = tryPlaceStructure(job.name, job.props, models)
		if success then
			successfulPlacements = successfulPlacements + 1
		end
	end)

	if DEBUG_ENABLED then
		print("[CoreStructureSpawner] Core structure spawning complete!")
		print("  - Structures placed:", successfulPlacements, "out of", #placementJobs)
		print("  - Occupied circles:", #occupiedCircles)
	end
end


function CoreStructureSpawner.getOccupiedCircles()
	return occupiedCircles
end

function CoreStructureSpawner.cleanup()
	occupiedCircles = {}
	if coreStructureFolder then
		for _, child in ipairs(coreStructureFolder:GetChildren()) do
			child:Destroy()
		end
	end
end

return CoreStructureSpawner
