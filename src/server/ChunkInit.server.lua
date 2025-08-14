--[[
	ChunkInit.server.lua
	Mobile-optimized terrain generation with proper sequencing
]]--


local SystemLoadMonitor     = _G.SystemLoadMonitor or require(script.Parent.SystemLoadMonitor)
local ChunkManager          = require(script.Parent.terrain.ChunkManager)
local CustomModelSpawner    = require(script.Parent.spawning.CustomModelSpawner) 
local DayNightCycle         = require(script.Parent.environment.DayNightCycle)
local VillageSpawner        = require(script.Parent.spawning.VillageSpawner)
local CoreStructureSpawner  = require(script.Parent.spawning.CoreStructureSpawner)
local ItemSpawner           = require(script.Parent.spawning.ItemSpawner)
local EventItemSpawner      = require(script.Parent.events.EventItemSpawner)
local TreasureSpawner       = require(script.Parent.spawning.TreasureSpawner)
local LightingManager       = require(script.Parent.environment.Lighting)
local ChunkConfig           = require(game.ReplicatedStorage.Shared.config.ChunkConfig)
local CollectionServiceTags = require(game.ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local RunService = game:GetService("RunService")
local isMobile = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled

local function mobileOptimizedInit()
	ChunkManager.init()
	
	DayNightCycle.init()
	LightingManager.init()
	SystemLoadMonitor.reportSystemLoaded("Environment")
	
	CollectionServiceTags.initializeDefaultTags()
	CollectionServiceTags.tagItemsFolder()
	SystemLoadMonitor.reportSystemLoaded("CollectionService")
	

	local PlayerStatsManager = require(script.Parent.player.PlayerStatsManager)
	PlayerStatsManager.init()
	local WaterRefillManager = require(script.Parent.food.WaterRefillManager)
	WaterRefillManager.init()
	SystemLoadMonitor.reportSystemLoaded("PlayerStats")
	SystemLoadMonitor.reportSystemLoaded("FoodSystem")
	
	CoreStructureSpawner.spawnLandmarks()
	
	-- Add delay to ensure pyramids are fully positioned before pedestal init
	task.wait(0.5)
	
	-- Initialize pedestal system after pyramids are spawned and positioned
	local initPedestalEvent = Instance.new("BindableEvent")
	initPedestalEvent.Name = "InitPedestal"
	initPedestalEvent.Parent = game.ReplicatedStorage
	initPedestalEvent:Fire()
	
	TreasureSpawner.Initialize()
	SystemLoadMonitor.reportSystemLoaded("TerrainSystem")
	
	VillageSpawner.spawnVillages()
	
	local SpawnerPlacement = require(script.Parent.ai.SpawnerPlacement)
	SpawnerPlacement.run()
	
	CustomModelSpawner.init(ChunkConfig.RENDER_DISTANCE, ChunkConfig.CHUNK_SIZE, ChunkConfig.SUBDIVISIONS)

	ItemSpawner.Initialize()
	
	EventItemSpawner.initialize()

	-- Initialize AI systems
	local AIManager = require(script.Parent.ai.AIManager)
	local FoodDropSystem = require(script.Parent.loot.FoodDropSystem)
	local CreatureSpawner = require(script.Parent.ai.CreatureSpawner)
	local CreaturePoolManager = require(script.Parent.ai.CreaturePoolManager)
	
	CreaturePoolManager.init()
	AIManager.getInstance():init()
	
	-- Initialize Night Hunt system
	local NightHuntManager = require(script.Parent.ai.NightHuntManager)
	NightHuntManager.init()
	
	FoodDropSystem.init()
	
	CreatureSpawner.populateWorld()
	CreaturePoolManager.startRespawnLoop()
	SystemLoadMonitor.reportSystemLoaded("AIManager")
	
	-- Brief pause before enabling AI to ensure all systems are ready
	task.wait(0.1)
end

local function desktopOptimizedInit()
	local terrainReady = false
	local environmentReady = false
	local tagsReady = false
	
	task.spawn(function()
		print("Initializing terrain system...")
		ChunkManager.init()
		-- Place core structures first to establish landmarks
		CoreStructureSpawner.spawnLandmarks()
		
		-- Add delay to ensure pyramids are fully positioned before pedestal init
		task.wait(0.5)
		
		-- Initialize pedestal system after pyramids are spawned and positioned
		local initPedestalEvent = Instance.new("BindableEvent")
		initPedestalEvent.Name = "InitPedestal"
		initPedestalEvent.Parent = game.ReplicatedStorage
		print("[ChunkInit] Firing pedestal initialization signal...")
		initPedestalEvent:Fire()
		
		-- Initialize treasure spawning system after pyramid is built
		print("Initializing treasure spawning system...")
		TreasureSpawner.Initialize()
		
		-- Place villages after core structures to avoid overlaps
		VillageSpawner.spawnVillages()
		-- After villages, place creature spawners
		local SpawnerPlacement = require(script.Parent.ai.SpawnerPlacement)
		SpawnerPlacement.run()
		-- Finally scatter environmental props
		CustomModelSpawner.init(ChunkConfig.RENDER_DISTANCE, ChunkConfig.CHUNK_SIZE, ChunkConfig.SUBDIVISIONS)
		terrainReady = true
	end)
	
	task.spawn(function()
		DayNightCycle.init()
		LightingManager.init()
		environmentReady = true
	end)
	
	task.spawn(function()
		CollectionServiceTags.initializeDefaultTags()
		CollectionServiceTags.tagItemsFolder()
		tagsReady = true
	end)
	
	task.spawn(function()
		local PlayerStatsManager = require(script.Parent.player.PlayerStatsManager)
		PlayerStatsManager.init()
		local WaterRefillManager = require(script.Parent.food.WaterRefillManager)
		WaterRefillManager.init()
		SystemLoadMonitor.reportSystemLoaded("PlayerStats")
		SystemLoadMonitor.reportSystemLoaded("FoodSystem")
	end)
	
	-- Wait for all parallel systems to complete
	repeat
		task.wait(0.1)
	until terrainReady and environmentReady and tagsReady
	
	SystemLoadMonitor.reportSystemLoaded("TerrainSystem")
	SystemLoadMonitor.reportSystemLoaded("Environment")
	SystemLoadMonitor.reportSystemLoaded("CollectionService")
	
	ItemSpawner.Initialize()
	EventItemSpawner.initialize()
	local AIManager = require(script.Parent.ai.AIManager)
	local FoodDropSystem = require(script.Parent.loot.FoodDropSystem)
	local CreatureSpawner = require(script.Parent.ai.CreatureSpawner)
	local CreaturePoolManager = require(script.Parent.ai.CreaturePoolManager)
	
	CreaturePoolManager.init()
	AIManager.getInstance():init()
	
	-- Initialize Night Hunt system
	local NightHuntManager = require(script.Parent.ai.NightHuntManager)
	NightHuntManager.init()
	
	FoodDropSystem.init()
	
	CreatureSpawner.populateWorld()
	CreaturePoolManager.startRespawnLoop()
	SystemLoadMonitor.reportSystemLoaded("AIManager")
end

if isMobile then
	mobileOptimizedInit()
else
	desktopOptimizedInit()
end

task.wait(0.5)