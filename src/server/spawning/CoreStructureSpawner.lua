--[[
	CoreStructureSpawner.lua
	Spawns massive landmark structures (Pyramid, Towers) before all other systems
	Uses circle-based collision detection and frame batching
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CoreStructureConfig = require(ReplicatedStorage.Shared.config.CoreStructureConfig)
local ChunkConfig = require(ReplicatedStorage.Shared.config.ChunkConfig)
local terrain = require(ReplicatedStorage.Shared.utilities.Terrain)
local FrameBatched = require(ReplicatedStorage.Shared.utilities.FrameBatched)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local CoreStructureSpawner = {}
local random = Random.new()

-- Storage for occupied landmark circles - single source of truth
local occupiedCircles = {}

-- Create organized folder for core structures
local coreStructureFolder = Instance.new("Folder")
coreStructureFolder.Name = "CoreStructures"
coreStructureFolder.Parent = Workspace

-- Load structure models from ReplicatedStorage
local function loadStructureModels()
	local models = {}
	local coreFolder = ReplicatedStorage
	
	-- Navigate to Models.Core folder
	for part in CoreStructureConfig.MODEL_FOLDER:gmatch("[^%.]+") do
		coreFolder = coreFolder:FindFirstChild(part)
		if not coreFolder then
			warn("[CoreStructureSpawner] Core model folder not found:", CoreStructureConfig.MODEL_FOLDER)
			return models
		end
	end
	
	-- Load each structure model
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

-- Check if two circles overlap
local function circlesOverlap(circle1, circle2)
	local distance = (circle1.centre - circle2.centre).Magnitude
	return distance < (circle1.radius + circle2.radius + CoreStructureConfig.MIN_DISTANCE_BETWEEN)
end

-- Check if position is in player spawn protection zone
local function isInProtectedZone(worldPosition, structureRadius)
	local distanceFromOrigin = worldPosition.Magnitude
	return distanceFromOrigin < (CoreStructureConfig.PLAYER_SPAWN_PROTECT_RADIUS + structureRadius)
end

-- Try to place a single structure
local function tryPlaceStructure(structureName, structureProps, models)
	local template = models[structureName]
	if not template then
		warn("[CoreStructureSpawner] Template model not found for:", structureName)
		return false
	end
	
	for attempt = 1, CoreStructureConfig.MAX_PLACEMENT_ATTEMPTS do
-- Generate random chunk coordinates first
        local chunkX = random:NextInteger(-ChunkConfig.RENDER_DISTANCE, ChunkConfig.RENDER_DISTANCE)
        local chunkZ = random:NextInteger(-ChunkConfig.RENDER_DISTANCE, ChunkConfig.RENDER_DISTANCE)
        local baseX  = chunkX * ChunkConfig.CHUNK_SIZE
        local baseZ  = chunkZ * ChunkConfig.CHUNK_SIZE

        -- Compute margin so circle stays fully in chunk plus extra configurable padding
        local edgeMargin = structureProps.radius + ChunkConfig.CHUNK_SIZE * CoreStructureConfig.CHUNK_MARGIN_FACTOR
        if edgeMargin * 2 >= ChunkConfig.CHUNK_SIZE then
            edgeMargin = ChunkConfig.CHUNK_SIZE / 2 - 2  -- ensure some space
        end

        -- Pick random point inside chunk respecting margin
        local localX = random:NextNumber(edgeMargin, ChunkConfig.CHUNK_SIZE - edgeMargin)
        local localZ = random:NextNumber(edgeMargin, ChunkConfig.CHUNK_SIZE - edgeMargin)
        local worldPosition = Vector3.new(baseX + localX, 0, baseZ + localZ)
		
		-- Check player spawn protection
		if isInProtectedZone(worldPosition, structureProps.radius) then
			continue
		end
		
		-- Check overlap with existing structures
		local proposedCircle = {
			centre = worldPosition,
			radius = structureProps.radius
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
		
		-- Get terrain height and calculate final position
		local terrainHeight = terrain.getTerrainHeight(worldPosition.X, worldPosition.Z)
		
		-- Calculate embedding: Get structure height and embed 10%
		local tempClone = template:Clone()
		local cf, size = tempClone:GetBoundingBox()
		tempClone:Destroy()
		
		-- Fix: Model pivot is at center, so embed relative to half-height
		local halfHeight = size.Y / 2
		local embedDepth = halfHeight * structureProps.embedPercentage
		local finalY = terrainHeight + embedDepth  -- Raise instead of lower
		local finalCFrame = CFrame.new(worldPosition.X, finalY, worldPosition.Z)
		
		-- Clone and position the structure
		local clone = template:Clone()
		
		-- Ensure PrimaryPart exists
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
		
		-- Position the structure
		clone:SetPrimaryPartCFrame(finalCFrame)
		clone.Parent = coreStructureFolder
		
		-- Tag structure as protected core geometry
		CollectionServiceTags.tagDescendants(clone, CollectionServiceTags.PROTECTED_CORE)
		
		-- Store the occupied circle
		table.insert(occupiedCircles, proposedCircle)
		
		print("[CoreStructureSpawner]", structureName, "placed after", attempt, "attempts at", worldPosition, "- Tagged as protected")
		return true
	end
	
	warn("[CoreStructureSpawner] Failed to place", structureName, "after", CoreStructureConfig.MAX_PLACEMENT_ATTEMPTS, "attempts")
	return false
end

-- Main spawning function
function CoreStructureSpawner.spawnLandmarks()
	print("[CoreStructureSpawner] Spawning core structures...")
	
	-- Clear any existing structures and circles
	occupiedCircles = {}
	for _, child in ipairs(coreStructureFolder:GetChildren()) do
		child:Destroy()
	end
	
	local models = loadStructureModels()
	
	-- Check if we have models to spawn
	if next(models) == nil then
		warn("[CoreStructureSpawner] No structure models found in", CoreStructureConfig.MODEL_FOLDER)
		return
	end
	
	-- Create placement jobs - Pyramid first, then towers
	local placementJobs = {}
	
	-- Add Pyramid first (largest structure)
	if CoreStructureConfig.STRUCTURES.Pyramid and models.Pyramid then
		table.insert(placementJobs, {
			name = "Pyramid",
			props = CoreStructureConfig.STRUCTURES.Pyramid
		})
	end
	
	-- Add towers in any order
	for structureName, structureProps in pairs(CoreStructureConfig.STRUCTURES) do
		if structureName ~= "Pyramid" and models[structureName] then
			table.insert(placementJobs, {
				name = structureName,
				props = structureProps
			})
		end
	end
	
	-- Process structures with frame batching
	local successfulPlacements = 0
	FrameBatched.run(placementJobs, CoreStructureConfig.BATCH_SIZE, function(job)
		local success = tryPlaceStructure(job.name, job.props, models)
		if success then
			successfulPlacements = successfulPlacements + 1
		end
	end)
	
	print("[CoreStructureSpawner] Core structure spawning complete!")
	print("  - Structures placed:", successfulPlacements, "out of", #placementJobs)
	print("  - Occupied circles:", #occupiedCircles)
end

-- Getter for other systems to query occupied areas
function CoreStructureSpawner.getOccupiedCircles()
	return occupiedCircles  -- Callers should treat as read-only
end

-- Cleanup function for testing
function CoreStructureSpawner.cleanup()
	occupiedCircles = {}
	if coreStructureFolder then
		for _, child in ipairs(coreStructureFolder:GetChildren()) do
			child:Destroy()
		end
	end
end

return CoreStructureSpawner