-- src/server/ai/arena/ArenaCreatureSpawner.lua
-- Handles spawning of arena-specific creatures with enhanced AI
-- Works with ArenaAIManager for coordinated arena events

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local ArenaCreature = require(script.Parent.ArenaCreature)
local ArenaAIManager = require(script.Parent.ArenaAIManager)
local SFXManager = require(script.Parent.Parent.audio.SFXManager)

local ArenaCreatureSpawner = {}

-- Initialize collision groups
local function setupCollisionGroups()
	local success, error = pcall(function()
		PhysicsService:RegisterCollisionGroup("Creature")
		PhysicsService:CollisionGroupSetCollidable("Creature", "Default", true)
		PhysicsService:CollisionGroupSetCollidable("Creature", "Creature", false)
		print("[ArenaCreatureSpawner] Collision groups set up - creatures won't block each other")
	end)
	if not success then
		warn("[ArenaCreatureSpawner] Failed to set up collision groups:", error)
	end
end
setupCollisionGroups()

-- ============================================
-- CONFIGURATION
-- ============================================
local ARENA_CREATURE_CONFIGS = {
	ArenaEgyptianSkeleton = {
		Health = 150,
		Damage = 5,
		MoveSpeed = 15,
		ModelFolder = "HostileCreatures",
		ModelName = "ArenaEgyptianSkeleton",
	},
	ArenaEgyptianSkeleton2 = {
		Health = 200,
		Damage = 6,
		MoveSpeed = 15,
		ModelFolder = "HostileCreatures",
		ModelName = "ArenaEgyptianSkeleton2",
	},
	ArenaScorpion = {
		Health = 250,
		Damage = 6,
		MoveSpeed = 18,
		ModelFolder = "HostileCreatures",
		ModelName = "Scorpion",
	},
}

-- ============================================
-- MODEL MANAGEMENT
-- ============================================

local function getCreatureModel(creatureType)
	
	local config = ARENA_CREATURE_CONFIGS[creatureType]
	if not config then
		warn("[ArenaCreatureSpawner] Unknown creature type:", creatureType)
		local availableTypes = {}
		for key in pairs(ARENA_CREATURE_CONFIGS or {}) do
			table.insert(availableTypes, key)
		end
		return nil
	end
	
	-- Get the model from ReplicatedStorage
	local npcsFolder = ReplicatedStorage:FindFirstChild("NPCs")
	if not npcsFolder then
		warn("[ArenaCreatureSpawner] NPCs folder not found in ReplicatedStorage (expected ReplicatedStorage/NPCs)")
		return nil
	end
	
	local modelFolder = npcsFolder:FindFirstChild(config.ModelFolder)
	if not modelFolder then
		warn("[ArenaCreatureSpawner] Model folder not found:", config.ModelFolder, " under ReplicatedStorage/NPCs")
		local available = {}
		for _, child in ipairs(npcsFolder:GetChildren()) do table.insert(available, child.Name) end
		print("[ArenaCreatureSpawner] Available folders:", table.concat(available, ", "))
		return nil
	end
	
	local model = modelFolder:FindFirstChild(config.ModelName)
	if not model then
		warn("[ArenaCreatureSpawner] Model not found:", config.ModelName, " under ", modelFolder:GetFullName())
		local available = {}
		for _, child in ipairs(modelFolder:GetChildren()) do table.insert(available, child.Name) end
		print("[ArenaCreatureSpawner] Available models:", table.concat(available, ", "))
		return nil
	end
	
	local clonedModel = model:Clone()
	print("[ArenaCreatureSpawner] Cloned model for ", creatureType, ": ", model:GetFullName())
	return clonedModel
end

local function prepareArenaModel(model, creatureType)
	local config = ARENA_CREATURE_CONFIGS[creatureType]
	if not config then
		return false
	end
	
	-- Set the model name to the arena variant
	model.Name = creatureType
	
	-- Configure humanoid
	local humanoid = model:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.MaxHealth = config.Health
		humanoid.Health = config.Health
		humanoid.WalkSpeed = config.MoveSpeed
		
		-- Disable default AI behaviors
		humanoid.AutoRotate = true
		humanoid.AutoJumpEnabled = true
	end
	
	-- Add arena identifier
	model:SetAttribute("IsArenaCreature", true)
	model:SetAttribute("CreatureType", creatureType)
	
	-- Skip network owner setup here - will be done after parenting to workspace
	
	return true
end

-- ============================================
-- SPAWNING FUNCTIONS
-- ============================================

function ArenaCreatureSpawner.spawnCreature(creatureType, position, options)
	options = options or {}
	
	-- Validate creature type
	local config = ARENA_CREATURE_CONFIGS[creatureType]
	if not config then
		warn("[ArenaCreatureSpawner] Invalid creature type:", creatureType)
		local availableTypes = {}
		for key in pairs(ARENA_CREATURE_CONFIGS) do
			table.insert(availableTypes, key)
		end
		return nil
	end
	
	-- Get and prepare model
	local model = getCreatureModel(creatureType)
	if not model then
		return nil
	end
	
	-- Prepare the model for arena use
	local success, result = pcall(function()
		return prepareArenaModel(model, creatureType)
	end)
	print("[ArenaCreatureSpawner] prepareArenaModel success=", success, " result=", result)
	
	if not success then
		warn("[ArenaCreatureSpawner] ERROR in prepareArenaModel:", result)
		model:Destroy()
		return nil
	end
	
	if not result then
		model:Destroy()
		return nil
	end
	
	-- Position the model
	if model.PrimaryPart then
		-- Spawn slightly above ground to ensure proper placement
		local adjustedPosition = position + Vector3.new(0, 2, 0)
		model:SetPrimaryPartCFrame(CFrame.new(adjustedPosition))
	end
	
	-- Parent to workspace
	local arenaFolder = Workspace:FindFirstChild("ArenaCreatures")
	if not arenaFolder then
		arenaFolder = Instance.new("Folder")
		arenaFolder.Name = "ArenaCreatures"
		arenaFolder.Parent = Workspace
	end
print("[ArenaCreatureSpawner] Parenting model to ", arenaFolder:GetFullName())
model.Parent = arenaFolder

	-- Auto-bind SFX for arena scorpions (and future arena types if desired)
	pcall(function()
		if creatureType == "ArenaScorpion" then
			SFXManager.setupForModel(model)
		end
	end)
	
	-- Now set network owner (model is in workspace)
	if model.PrimaryPart then
		model.PrimaryPart:SetNetworkOwner(nil)
	end
	
	-- Create AI controller
	local success, creature = pcall(function()
		return ArenaCreature.new(model, creatureType, position)
	end)
	print("[ArenaCreatureSpawner] ArenaCreature.new success=", success, creature and ("type="..tostring(creatureType)) or tostring(creature))
	
	if not success then
		warn("[ArenaCreatureSpawner] ERROR in ArenaCreature.new:", creature)
		model:Destroy()
		return nil
	end
	
	if not creature then
		warn("[ArenaCreatureSpawner] Failed to create AI controller for", creatureType)
		model:Destroy()
		return nil
	end
	
	-- Apply configuration
	creature.damage = config.Damage
	creature.moveSpeed = config.MoveSpeed
	
	-- Register with ArenaAIManager if it's active
	local aiManager = ArenaAIManager.getInstance()
	if aiManager.isActive then
		local success = aiManager:registerCreature(creature)
	else
		warn("[ArenaCreatureSpawner] ArenaAIManager is not active - creature will not be managed")
	end
	
	
	return creature
end

function ArenaCreatureSpawner.spawnWave(waveData, spawnPositions)
	local spawnedCreatures = {}
	local spawnIndex = 1
	
	for creatureType, count in pairs(waveData) do
		for i = 1, count do
			-- Get spawn position (cycle through available positions)
			local position = spawnPositions[spawnIndex]
			if not position then
				position = spawnPositions[1] -- Wrap around if needed
				spawnIndex = 1
			end
			
			-- Add some randomization to prevent stacking
			local offset = Vector3.new(
				math.random(-3, 3),
				0,
				math.random(-3, 3)
			)
			local spawnPos = position + offset
			
			-- Spawn the creature
			local creature = ArenaCreatureSpawner.spawnCreature(creatureType, spawnPos)
			if creature then
				table.insert(spawnedCreatures, creature)
			end
			
			spawnIndex = spawnIndex + 1
			
			-- Small delay between spawns for performance
			task.wait(0.1)
		end
	end
	
	print(string.format("[ArenaCreatureSpawner] Spawned wave with %d creatures", #spawnedCreatures))
	return spawnedCreatures
end

-- ============================================
-- ARENA-SPECIFIC SPAWN PATTERNS
-- ============================================

function ArenaCreatureSpawner.spawnPhase1Wave(spawnMarkers)
	local waveData = {
		ArenaEgyptianSkeleton = 6,
		ArenaScorpion = 2,
	}
	
	local positions = {}
	for _, marker in ipairs(spawnMarkers) do
		if marker:IsA("BasePart") then
			table.insert(positions, marker.Position)
		end
	end
	
	return ArenaCreatureSpawner.spawnWave(waveData, positions)
end

function ArenaCreatureSpawner.spawnPhase2Wave(spawnMarkers)
	local waveData = {
		ArenaEgyptianSkeleton2 = 10,
	}
	
	local positions = {}
	for _, marker in ipairs(spawnMarkers) do
		if marker:IsA("BasePart") then
			table.insert(positions, marker.Position)
		end
	end
	
	return ArenaCreatureSpawner.spawnWave(waveData, positions)
end

function ArenaCreatureSpawner.spawnPhase3Wave(spawnMarkers)
	local waveData = {
		ArenaScorpion = 5,
	}
	
	local positions = {}
	for _, marker in ipairs(spawnMarkers) do
		if marker:IsA("BasePart") then
			table.insert(positions, marker.Position)
		end
	end
	
	return ArenaCreatureSpawner.spawnWave(waveData, positions)
end

-- ============================================
-- CLEANUP
-- ============================================

function ArenaCreatureSpawner.cleanupAllCreatures()
	local arenaFolder = Workspace:FindFirstChild("ArenaCreatures")
	if arenaFolder then
		for _, model in ipairs(arenaFolder:GetChildren()) do
			if model:GetAttribute("IsArenaCreature") then
				model:Destroy()
			end
		end
	end
	
	print("[ArenaCreatureSpawner] Cleaned up all arena creatures")
end

return ArenaCreatureSpawner
