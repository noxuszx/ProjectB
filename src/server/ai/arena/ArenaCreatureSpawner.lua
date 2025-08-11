-- src/server/ai/arena/ArenaCreatureSpawner.lua
-- Handles spawning of arena-specific creatures with enhanced AI
-- Works with ArenaAIManager for coordinated arena events

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local ArenaCreature = require(script.Parent.ArenaCreature)
local ArenaAIManager = require(script.Parent.ArenaAIManager)

local ArenaCreatureSpawner = {}

-- Initialize collision groups
local function setupCollisionGroups()
	local success, error = pcall(function()
		-- Register the collision group
		PhysicsService:RegisterCollisionGroup("Creature")
		-- Creatures can collide with default objects (walls, floors, etc)
		PhysicsService:CollisionGroupSetCollidable("Creature", "Default", true)
		-- IMPORTANT: Creatures should NOT collide with each other to prevent blocking
		PhysicsService:CollisionGroupSetCollidable("Creature", "Creature", false)
		print("[ArenaCreatureSpawner] Collision groups set up - creatures won't block each other")
	end)
	if not success then
		warn("[ArenaCreatureSpawner] Failed to set up collision groups:", error)
	end
end

-- Set up collision groups on first load
setupCollisionGroups()

-- ============================================
-- CONFIGURATION
-- ============================================
local ARENA_CREATURE_CONFIGS = {
	ArenaEgyptianSkeleton = {
		Health = 150,
		Damage = 5,
		MoveSpeed = 16,
		ModelFolder = "HostileCreatures",
		ModelName = "EgyptianSkeleton", -- Map to existing model
	},
	ArenaEgyptianSkeleton2 = {
		Health = 200,
		Damage = 6,
		MoveSpeed = 16,
		ModelFolder = "HostileCreatures",
		ModelName = "EgyptianSkeleton2", -- Map to existing model
	},
	ArenaScorpion = {
		Health = 250,
		Damage = 6,
		MoveSpeed = 18,
		ModelFolder = "HostileCreatures",
		ModelName = "Scorpion", -- Map to existing model
	},
}

-- ============================================
-- MODEL MANAGEMENT
-- ============================================

local function getCreatureModel(creatureType)
	print("[ArenaCreatureSpawner] DEBUG: Attempting to get model for:", creatureType)
	
	local config = ARENA_CREATURE_CONFIGS[creatureType]
	if not config then
		warn("[ArenaCreatureSpawner] Unknown creature type:", creatureType)
		local availableTypes = {}
		for key in pairs(ARENA_CREATURE_CONFIGS or {}) do
			table.insert(availableTypes, key)
		end
		print("[ArenaCreatureSpawner] DEBUG: Available creature types:", table.concat(availableTypes, ", "))
		return nil
	end
	print("[ArenaCreatureSpawner] DEBUG: Found config for", creatureType, "- ModelName:", config.ModelName)
	
	-- Get the model from ReplicatedStorage
	local npcsFolder = ReplicatedStorage:FindFirstChild("NPCs")
	if not npcsFolder then
		warn("[ArenaCreatureSpawner] NPCs folder not found in ReplicatedStorage")
		local folderNames = {}
		for _, child in ipairs(ReplicatedStorage:GetChildren()) do
			table.insert(folderNames, child.Name)
		end
		print("[ArenaCreatureSpawner] DEBUG: Available folders in ReplicatedStorage:", table.concat(folderNames, ", "))
		return nil
	end
	print("[ArenaCreatureSpawner] DEBUG: Found NPCs folder")
	
	local modelFolder = npcsFolder:FindFirstChild(config.ModelFolder)
	if not modelFolder then
		warn("[ArenaCreatureSpawner] Model folder not found:", config.ModelFolder)
		local npcFolderNames = {}
		for _, child in ipairs(npcsFolder:GetChildren()) do
			table.insert(npcFolderNames, child.Name)
		end
		print("[ArenaCreatureSpawner] DEBUG: Available folders in NPCs:", table.concat(npcFolderNames, ", "))
		return nil
	end
	print("[ArenaCreatureSpawner] DEBUG: Found model folder:", config.ModelFolder)
	
	local model = modelFolder:FindFirstChild(config.ModelName)
	if not model then
		warn("[ArenaCreatureSpawner] Model not found:", config.ModelName)
		local modelNames = {}
		for _, child in ipairs(modelFolder:GetChildren()) do
			table.insert(modelNames, child.Name)
		end
		print("[ArenaCreatureSpawner] DEBUG: Available models in", config.ModelFolder .. ":", table.concat(modelNames, ", "))
		return nil
	end
	print("[ArenaCreatureSpawner] DEBUG: Found model:", config.ModelName, "- Cloning...")
	
	local clonedModel = model:Clone()
	print("[ArenaCreatureSpawner] DEBUG: Successfully cloned model")
	return clonedModel
end

local function prepareArenaModel(model, creatureType)
	print("[ArenaCreatureSpawner] DEBUG: prepareArenaModel called for", creatureType)
	local config = ARENA_CREATURE_CONFIGS[creatureType]
	if not config then
		print("[ArenaCreatureSpawner] DEBUG: No config found for", creatureType)
		return false
	end
	print("[ArenaCreatureSpawner] DEBUG: Found config, setting model name...")
	
	-- Set the model name to the arena variant
	model.Name = creatureType
	print("[ArenaCreatureSpawner] DEBUG: Model name set to", creatureType)
	
	-- Configure humanoid
	local humanoid = model:FindFirstChild("Humanoid")
	if humanoid then
		print("[ArenaCreatureSpawner] DEBUG: Configuring humanoid - Health:", config.Health, "Speed:", config.MoveSpeed)
		humanoid.MaxHealth = config.Health
		humanoid.Health = config.Health
		humanoid.WalkSpeed = config.MoveSpeed
		
		-- Disable default AI behaviors
		humanoid.AutoRotate = true
		humanoid.AutoJumpEnabled = true
		print("[ArenaCreatureSpawner] DEBUG: Humanoid configured")
	else
		print("[ArenaCreatureSpawner] DEBUG: No Humanoid found in model")
	end
	
	-- Add arena identifier
	print("[ArenaCreatureSpawner] DEBUG: Setting attributes...")
	model:SetAttribute("IsArenaCreature", true)
	model:SetAttribute("CreatureType", creatureType)
	print("[ArenaCreatureSpawner] DEBUG: Attributes set")
	
	-- Skip network owner setup here - will be done after parenting to workspace
	print("[ArenaCreatureSpawner] DEBUG: Skipping network owner setup (will be done after parenting)")
	
	print("[ArenaCreatureSpawner] DEBUG: prepareArenaModel completed successfully")
	return true
end

-- ============================================
-- SPAWNING FUNCTIONS
-- ============================================

function ArenaCreatureSpawner.spawnCreature(creatureType, position, options)
	options = options or {}
	print("[ArenaCreatureSpawner] DEBUG: spawnCreature called with type:", creatureType, "at position:", tostring(position))
	
	-- Validate creature type
	local config = ARENA_CREATURE_CONFIGS[creatureType]
	if not config then
		warn("[ArenaCreatureSpawner] Invalid creature type:", creatureType)
		local availableTypes = {}
		for key in pairs(ARENA_CREATURE_CONFIGS) do
			table.insert(availableTypes, key)
		end
		print("[ArenaCreatureSpawner] DEBUG: Available types:", table.concat(availableTypes, ", "))
		return nil
	end
	print("[ArenaCreatureSpawner] DEBUG: Validated creature type")
	
	-- Get and prepare model
	print("[ArenaCreatureSpawner] DEBUG: Getting creature model...")
	local model = getCreatureModel(creatureType)
	if not model then
		print("[ArenaCreatureSpawner] DEBUG: Failed to get creature model")
		return nil
	end
	print("[ArenaCreatureSpawner] DEBUG: Got model, preparing for arena use...")
	
	-- Prepare the model for arena use
	print("[ArenaCreatureSpawner] DEBUG: About to call prepareArenaModel...")
	local success, result = pcall(function()
		return prepareArenaModel(model, creatureType)
	end)
	
	if not success then
		warn("[ArenaCreatureSpawner] ERROR in prepareArenaModel:", result)
		model:Destroy()
		return nil
	end
	
	if not result then
		print("[ArenaCreatureSpawner] DEBUG: prepareArenaModel returned false")
		model:Destroy()
		return nil
	end
	print("[ArenaCreatureSpawner] DEBUG: Model prepared successfully")
	
	-- Position the model
	if model.PrimaryPart then
		-- Spawn slightly above ground to ensure proper placement
		local adjustedPosition = position + Vector3.new(0, 2, 0)
		model:SetPrimaryPartCFrame(CFrame.new(adjustedPosition))
		print("[ArenaCreatureSpawner] DEBUG: Positioned model at adjusted height:", adjustedPosition)
	end
	
	-- Parent to workspace
	print("[ArenaCreatureSpawner] DEBUG: Parenting model to workspace...")
	local arenaFolder = Workspace:FindFirstChild("ArenaCreatures")
	if not arenaFolder then
		arenaFolder = Instance.new("Folder")
		arenaFolder.Name = "ArenaCreatures"
		arenaFolder.Parent = Workspace
	end
	model.Parent = arenaFolder
	print("[ArenaCreatureSpawner] DEBUG: Model parented to ArenaCreatures folder")
	
	-- Now set network owner (model is in workspace)
	if model.PrimaryPart then
		print("[ArenaCreatureSpawner] DEBUG: Setting network owner for PrimaryPart...")
		model.PrimaryPart:SetNetworkOwner(nil)
		print("[ArenaCreatureSpawner] DEBUG: Network owner set")
	else
		print("[ArenaCreatureSpawner] DEBUG: No PrimaryPart found for network owner setup")
	end
	
	-- Create AI controller
	print("[ArenaCreatureSpawner] DEBUG: Creating AI controller...")
	local success, creature = pcall(function()
		return ArenaCreature.new(model, creatureType, position)
	end)
	
	if not success then
		warn("[ArenaCreatureSpawner] ERROR in ArenaCreature.new:", creature)
		model:Destroy()
		return nil
	end
	
	if not creature then
		warn("[ArenaCreatureSpawner] Failed to create AI controller for", creatureType)
		print("[ArenaCreatureSpawner] DEBUG: AI controller creation returned nil")
		model:Destroy()
		return nil
	end
	print("[ArenaCreatureSpawner] DEBUG: AI controller created successfully")
	
	-- Apply configuration
	creature.damage = config.Damage
	creature.moveSpeed = config.MoveSpeed
	
	-- Register with ArenaAIManager if it's active
	print("[ArenaCreatureSpawner] DEBUG: Registering with ArenaAIManager...")
	local aiManager = ArenaAIManager.getInstance()
	print("[ArenaCreatureSpawner] DEBUG: ArenaAIManager active:", aiManager.isActive)
	if aiManager.isActive then
		local success = aiManager:registerCreature(creature)
		print("[ArenaCreatureSpawner] DEBUG: Registration result:", success)
	else
		warn("[ArenaCreatureSpawner] ArenaAIManager is not active - creature will not be managed")
	end
	
	print(string.format("[ArenaCreatureSpawner] Spawned %s at (%.1f, %.1f, %.1f)", 
		creatureType, position.X, position.Y, position.Z))
	
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
