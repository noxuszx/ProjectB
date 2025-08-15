--[[
	ChunkInit.server.lua
	Mobile-optimized terrain generation with proper sequencing
]]
--

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SystemLoadMonitor 	= _G.SystemLoadMonitor or require(script.Parent.SystemLoadMonitor)
local ChunkManager 			= require(script.Parent.terrain.ChunkManager)
local ChunkConfig 			= require(game.ReplicatedStorage.Shared.config.ChunkConfig)
local CollectionServiceTags = require(game.ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local DayNightCycle 		= require(script.Parent.environment.DayNightCycle)
local LightingManager 		= require(script.Parent.environment.Lighting)
local PlayerStatsManager 	= require(script.Parent.player.PlayerStatsManager)
local WaterRefillManager 	= require(script.Parent.food.WaterRefillManager)
local CustomModelSpawner 	= require(script.Parent.spawning.CustomModelSpawner)
local VillageSpawner 		= require(script.Parent.spawning.VillageSpawner)
local CoreStructureSpawner  = require(script.Parent.spawning.CoreStructureSpawner)
local ItemSpawner 			= require(script.Parent.spawning.ItemSpawner)
local EventItemSpawner 		= require(script.Parent.events.EventItemSpawner)
local TreasureSpawner 		= require(script.Parent.spawning.TreasureSpawner)
local SpawnerPlacement 		= require(script.Parent.ai.SpawnerPlacement)
local AIManager 			= require(script.Parent.ai.AIManager)
local CreatureSpawner 		= require(script.Parent.ai.CreatureSpawner)
local CreaturePoolManager 	= require(script.Parent.ai.CreaturePoolManager)
local NightHuntManager 		= require(script.Parent.ai.NightHuntManager)
local FoodDropSystem 		= require(script.Parent.loot.FoodDropSystem)

-- Configuration
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function mobileOptimizedInit()
	ChunkManager.init()

	DayNightCycle.init()
	LightingManager.init()
	SystemLoadMonitor.reportSystemLoaded("Environment")

	CollectionServiceTags.initializeDefaultTags()
	CollectionServiceTags.tagItemsFolder()
	SystemLoadMonitor.reportSystemLoaded("CollectionService")

	PlayerStatsManager.init()
	WaterRefillManager.init()
	SystemLoadMonitor.reportSystemLoaded("PlayerStats")
	SystemLoadMonitor.reportSystemLoaded("FoodSystem")

	CoreStructureSpawner.spawnLandmarks()

	task.wait(0.5)

	local initPedestalEvent = game.ReplicatedStorage.Remotes.Events.InitPedestal
	if initPedestalEvent then
		initPedestalEvent:Fire()
	end

	TreasureSpawner.Initialize()
	SystemLoadMonitor.reportSystemLoaded("TerrainSystem")

	VillageSpawner.spawnVillages()
	SpawnerPlacement.run()
	CustomModelSpawner.init(ChunkConfig.RENDER_DISTANCE, ChunkConfig.CHUNK_SIZE, ChunkConfig.SUBDIVISIONS)
	ItemSpawner.Initialize()
	EventItemSpawner.initialize()
	CreaturePoolManager.init()
	AIManager.getInstance():init()
	NightHuntManager.init()
	FoodDropSystem.init()
	CreatureSpawner.populateWorld()
	CreaturePoolManager.startRespawnLoop()
	SystemLoadMonitor.reportSystemLoaded("AIManager")

	task.wait(0.1)
end

local function desktopOptimizedInit()
	local terrainReady = false
	local environmentReady = false
	local tagsReady = false

	task.spawn(function()
		ChunkManager.init()
		CoreStructureSpawner.spawnLandmarks()

		task.wait(0.5)

		local initPedestalEvent = game.ReplicatedStorage.Remotes.Events.InitPedestal
		if initPedestalEvent then
			initPedestalEvent:Fire()
		end

		TreasureSpawner.Initialize()
		VillageSpawner.spawnVillages()
		SpawnerPlacement.run()
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
		PlayerStatsManager.init()
		WaterRefillManager.init()
		SystemLoadMonitor.reportSystemLoaded("PlayerStats")
		SystemLoadMonitor.reportSystemLoaded("FoodSystem")
	end)

	repeat
		task.wait(0.1)
	until terrainReady and environmentReady and tagsReady

	SystemLoadMonitor.reportSystemLoaded("TerrainSystem")
	SystemLoadMonitor.reportSystemLoaded("Environment")
	SystemLoadMonitor.reportSystemLoaded("CollectionService")

	ItemSpawner.Initialize()
	EventItemSpawner.initialize()
	CreaturePoolManager.init()
	AIManager.getInstance():init()
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
