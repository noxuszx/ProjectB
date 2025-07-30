--[[
	ChunkInit.server.lua
	Mobile-optimized terrain generation with proper sequencing
]]--

print("Chunk-based terrain system starting...")

local ChunkManager          = require(script.Parent.terrain.ChunkManager)
local CustomModelSpawner    = require(script.Parent.spawning.CustomModelSpawner) 
local DayNightCycle         = require(script.Parent.environment.DayNightCycle)
local VillageSpawner        = require(script.Parent.spawning.VillageSpawner)
local ItemSpawner           = require(script.Parent.spawning.ItemSpawner)
local LightingManager       = require(script.Parent.environment.Lighting)
local ChunkConfig           = require(game.ReplicatedStorage.Shared.config.ChunkConfig)
local CollectionServiceTags = require(game.ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local RunService = game:GetService("RunService")
local isMobile = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled

local function mobileOptimizedInit()
	print("Initializing terrain system...")
	ChunkManager.init()
	task.wait(0.1)
	
	print("Initializing environment...")
	DayNightCycle.init()
	LightingManager.init()
	task.wait(0.1)
	
	print("Setting up model spawning...")
	CustomModelSpawner.init(ChunkConfig.RENDER_DISTANCE, ChunkConfig.CHUNK_SIZE, ChunkConfig.SUBDIVISIONS)
	task.wait(0.1)
	
	print("Initializing tags...")
	CollectionServiceTags.initializeDefaultTags()
	CollectionServiceTags.tagItemsFolder()
	task.wait(0.1)
	
	print("Setting up player systems...")
	local PlayerStatsManager = require(script.Parent.player.PlayerStatsManager)
	PlayerStatsManager.init()
	local WaterRefillManager = require(script.Parent.food.WaterRefillManager)
	WaterRefillManager.init()
	task.wait(0.2)
	
	print("Spawning world content (terrain-dependent)...")
	VillageSpawner.spawnVillages()
	task.wait(0.1)
	
	local SpawnerPlacement = require(script.Parent.ai.SpawnerPlacement)
	SpawnerPlacement.run()
	task.wait(0.1)
	
	ItemSpawner.Initialize()
	task.wait(0.2)
	
	print("Initializing AI systems...")
	local AIManager = require(script.Parent.ai.AIManager)
	local FoodDropSystem = require(script.Parent.loot.FoodDropSystem)
	local CreatureSpawner = require(script.Parent.ai.CreatureSpawner)
	local CreaturePoolManager = require(script.Parent.ai.CreaturePoolManager)
	
	CreaturePoolManager.init()
	AIManager.getInstance():init()
	FoodDropSystem.init()
	task.wait(0.1)
	
	CreatureSpawner.populateWorld()
	CreaturePoolManager.startRespawnLoop()
end

local function desktopOptimizedInit()
	local terrainReady = false
	local environmentReady = false
	local tagsReady = false
	
	task.spawn(function()
		print("Initializing terrain system...")
		ChunkManager.init()
		CustomModelSpawner.init(ChunkConfig.RENDER_DISTANCE, ChunkConfig.CHUNK_SIZE, ChunkConfig.SUBDIVISIONS)
		terrainReady = true
		print("Terrain system ready")
	end)
	
	task.spawn(function()
		print("Initializing environment...")
		DayNightCycle.init()
		LightingManager.init()
		environmentReady = true
		print("Environment ready")
	end)
	
	task.spawn(function()
		print("Initializing tags...")
		CollectionServiceTags.initializeDefaultTags()
		CollectionServiceTags.tagItemsFolder()
		tagsReady = true
		print("Tags ready")
	end)
	
	task.spawn(function()
		print("Initializing player systems...")
		local PlayerStatsManager = require(script.Parent.player.PlayerStatsManager)
		PlayerStatsManager.init()
		local WaterRefillManager = require(script.Parent.food.WaterRefillManager)
		WaterRefillManager.init()
		print("Player systems ready")
	end)
	
	repeat
		task.wait(0.1)
	until terrainReady and environmentReady and tagsReady
	
	task.spawn(function()
		print("Spawning villages...")
		VillageSpawner.spawnVillages()
	end)
	
	task.spawn(function()
		print("Placing spawners...")
		local SpawnerPlacement = require(script.Parent.ai.SpawnerPlacement)
		SpawnerPlacement.run()
	end)
	
	task.spawn(function()
		print("Initializing items...")
		ItemSpawner.Initialize()
	end)
	
	task.wait(1)
	
	local AIManager = require(script.Parent.ai.AIManager)
	local FoodDropSystem = require(script.Parent.loot.FoodDropSystem)
	local CreatureSpawner = require(script.Parent.ai.CreatureSpawner)
	local CreaturePoolManager = require(script.Parent.ai.CreaturePoolManager)
	
	task.spawn(function()
		CreaturePoolManager.init()
		AIManager.getInstance():init()
		FoodDropSystem.init()
	end)
	
	task.spawn(function()
		CreatureSpawner.populateWorld()
		CreaturePoolManager.startRespawnLoop()
	end)
end

if isMobile then
	print("Mobile device detected - using sequential initialization")
	mobileOptimizedInit()
else
	print("Desktop device detected - using parallel initialization")
	desktopOptimizedInit()
end

task.wait(0.5)
print("All systems initialized. Player stats, day/night cycle, world populated with items, procedural spawners, creatures, and weapons.")