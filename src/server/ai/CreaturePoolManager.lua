-- src/server/ai/CreaturePoolManager.lua
-- Manages creature pooling to prevent frame drops from model destruction
-- Handles respawning and population limits for animal creatures

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local CreaturePoolManager = {}

-- Pool configuration
local PoolConfig = {
	-- Creature types that use pooling (animals only, not humanoids)
	PooledCreatures = {
		"Rabbit",
		"Wolf"
	},
	
	-- Maximum creatures alive per type
	MaxPopulation = {
		Rabbit = 20,
		Wolf = 15
	},
	
	-- Respawn delay after creature dies
	RespawnDelay = {
		Rabbit = 10, -- seconds
		Wolf = 15    -- seconds  
	}
}

-- Pool folders
local poolFolders = {}
local activeCreatureCounts = {}
local respawnQueue = {}

-- Initialize the pooling system
function CreaturePoolManager.init()
	print("[CreaturePoolManager] Initializing creature pooling system...")
	
	-- Create pool folders in ReplicatedStorage
	for _, creatureType in pairs(PoolConfig.PooledCreatures) do
		local folderName = "Dead" .. creatureType .. "s"
		local poolFolder = Instance.new("Folder")
		poolFolder.Name = folderName
		poolFolder.Parent = ReplicatedStorage
		
		poolFolders[creatureType] = poolFolder
		activeCreatureCounts[creatureType] = 0
		respawnQueue[creatureType] = {}
		
		print("[CreaturePoolManager] Created pool folder:", folderName)
	end
	
	print("[CreaturePoolManager] Creature pooling system ready!")
	return true
end

-- Check if a creature type uses pooling
function CreaturePoolManager.isPooledCreature(creatureType)
	for _, pooledType in pairs(PoolConfig.PooledCreatures) do
		if pooledType == creatureType then
			return true
		end
	end
	return false
end

-- Pool a creature instead of destroying it
function CreaturePoolManager.poolCreature(creatureModel, creatureType)
	if not CreaturePoolManager.isPooledCreature(creatureType) then
		warn("[CreaturePoolManager] Attempted to pool non-pooled creature:", creatureType)
		return false
	end
	
	local poolFolder = poolFolders[creatureType]
	if not poolFolder then
		warn("[CreaturePoolManager] Pool folder not found for:", creatureType)
		return false
	end
	
	-- Reset creature state for pooling
	CreaturePoolManager.resetCreatureForPool(creatureModel)
	
	-- Move to pool
	creatureModel.Parent = poolFolder
	creatureModel.Name = creatureType .. "_pooled_" .. os.clock()
	
	-- Decrease active count
	activeCreatureCounts[creatureType] = activeCreatureCounts[creatureType] - 1
	
	print("[CreaturePoolManager] Pooled", creatureType, "- Active count:", activeCreatureCounts[creatureType])
	
	-- Queue respawn if under population limit
	CreaturePoolManager.queueRespawn(creatureType)
	
	return true
end

-- Reset creature state when pooling
function CreaturePoolManager.resetCreatureForPool(creatureModel)
	-- Reset position (move far away)
	if creatureModel.PrimaryPart then
		creatureModel:SetPrimaryPartCFrame(CFrame.new(0, -1000, 0))
	end
	
	-- Reset humanoid if exists
	local humanoid = creatureModel:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
		humanoid.PlatformStand = false
		humanoid.Sit = false
	end
	
	-- Clear any existing welds/constraints
	for _, descendant in pairs(creatureModel:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("Motor6D") then
			if descendant.Name ~= "Root" then -- Preserve essential joints 
				descendant:Destroy()
			end
		end
	end
	
	-- Reset all parts to default state
	for _, part in pairs(creatureModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = true
			part.Anchored = false
			part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end
end

-- Get a creature from pool for respawning
function CreaturePoolManager.getPooledCreature(creatureType)
	local poolFolder = poolFolders[creatureType]
	if not poolFolder then
		return nil
	end
	
	local pooledCreatures = poolFolder:GetChildren()
	if #pooledCreatures == 0 then
		return nil
	end
	
	-- Return first available pooled creature
	local creature = pooledCreatures[1]
	return creature
end

-- Queue a respawn for later
function CreaturePoolManager.queueRespawn(creatureType)
	if activeCreatureCounts[creatureType] >= PoolConfig.MaxPopulation[creatureType] then
		return -- At population limit
	end
	
	local delay = PoolConfig.RespawnDelay[creatureType] or 10
	
	-- Add to respawn queue
	table.insert(respawnQueue[creatureType], {
		spawnTime = os.clock() + delay,
		creatureType = creatureType
	})
	
	print("[CreaturePoolManager] Queued", creatureType, "respawn in", delay, "seconds")
end

-- Process respawn queue (call this periodically)
function CreaturePoolManager.processRespawnQueue()
	local currentTime = os.clock()
	
	for creatureType, queue in pairs(respawnQueue) do
		for i = #queue, 1, -1 do
			local respawnData = queue[i]
			
			if currentTime >= respawnData.spawnTime then
				-- Time to respawn
				CreaturePoolManager.attemptRespawn(creatureType)
				table.remove(queue, i)
			end
		end
	end
end

-- Attempt to respawn a creature
function CreaturePoolManager.attemptRespawn(creatureType)
	-- Check population limit
	if activeCreatureCounts[creatureType] >= PoolConfig.MaxPopulation[creatureType] then
		return false
	end
	
	-- Try to get pooled creature first
	local creature = CreaturePoolManager.getPooledCreature(creatureType)
	
	if creature then
		-- Respawn from pool
		return CreaturePoolManager.respawnFromPool(creature, creatureType)
	else
		-- No pooled creatures available, create new one
		return CreaturePoolManager.spawnNewCreature(creatureType)
	end
end

-- Respawn creature from pool
function CreaturePoolManager.respawnFromPool(creature, creatureType)
	-- TODO: Integrate with existing spawner system to find spawn location
	-- For now, we'll need to call the existing CreatureSpawner logic
	
	print("[CreaturePoolManager] Respawning", creatureType, "from pool")
	
	-- Move back to workspace (will be handled by spawner integration)
	-- This is a placeholder - real implementation needs spawner integration
	
	activeCreatureCounts[creatureType] = activeCreatureCounts[creatureType] + 1
	return true
end

-- Spawn new creature (fallback if pool empty)
function CreaturePoolManager.spawnNewCreature(creatureType)
	-- TODO: Integrate with existing CreatureSpawner to create new creature
	print("[CreaturePoolManager] Pool empty, spawning new", creatureType)
	
	activeCreatureCounts[creatureType] = activeCreatureCounts[creatureType] + 1
	return true
end

-- Register when a creature is spawned (called by spawner)
function CreaturePoolManager.registerCreatureSpawn(creatureType)
	if CreaturePoolManager.isPooledCreature(creatureType) then
		activeCreatureCounts[creatureType] = activeCreatureCounts[creatureType] + 1
	end
end

-- Start respawn processing loop
function CreaturePoolManager.startRespawnLoop()
	spawn(function()
		while true do
			CreaturePoolManager.processRespawnQueue()
			wait(1) -- Check every second
		end
	end)
	print("[CreaturePoolManager] Respawn loop started")
end

-- Get current population statistics
function CreaturePoolManager.getPopulationStats()
	local stats = {}
	for creatureType, count in pairs(activeCreatureCounts) do
		local maxPop = PoolConfig.MaxPopulation[creatureType] or 0
		local pooled = poolFolders[creatureType] and #poolFolders[creatureType]:GetChildren() or 0
		
		stats[creatureType] = {
			active = count,
			max = maxPop,
			pooled = pooled,
			queued = #respawnQueue[creatureType]
		}
	end
	return stats
end

-- Cleanup pools
function CreaturePoolManager.cleanup()
	for _, folder in pairs(poolFolders) do
		if folder then
			folder:ClearAllChildren()
		end
	end
	
	for creatureType, _ in pairs(activeCreatureCounts) do
		activeCreatureCounts[creatureType] = 0
		respawnQueue[creatureType] = {}
	end
	
	print("[CreaturePoolManager] Cleaned up all pools")
end

return CreaturePoolManager