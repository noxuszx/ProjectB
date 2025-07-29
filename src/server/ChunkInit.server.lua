--[[
	ChunkInit.server.lua
	Initialize chunk-based terrain generation
]]--

print("Chunk-based terrain system starting...")

local ChunkManager = require(script.Parent.terrain.ChunkManager)
local CustomModelSpawner = require(script.Parent.spawning.CustomModelSpawner) -- Enabled after manual setup
local DayNightCycle = require(script.Parent.environment.dayNightCycle)
local VillageSpawner = require(script.Parent.spawning.VillageSpawner)
local ItemSpawner = require(script.Parent.spawning.ItemSpawner)
local LightingManager = require(script.Parent.environment.lighting)
local ChunkConfig = require(game.ReplicatedStorage.Shared.config.ChunkConfig)
local CollectionServiceTags = require(game.ReplicatedStorage.Shared.utilities.CollectionServiceTags)

task.wait(2)

ChunkManager.init()

print("Chunk terrain system initialized")
task.wait(1)

VillageSpawner.spawnVillages()
print("Village spawning complete. Initializing item spawning...")
task.wait(1)

CustomModelSpawner.init(
    ChunkConfig.RENDER_DISTANCE,
    ChunkConfig.CHUNK_SIZE,
    ChunkConfig.SUBDIVISIONS
)

print("Terrain system initialized Model spawning enabled.")

DayNightCycle.init()
LightingManager.init()
ItemSpawner.Initialize()

print("Placing procedural creature spawners...")
local SpawnerPlacement = require(script.Parent.ai.spawnerPlacement)
SpawnerPlacement.run()

print("Initializing drag-drop system tags...")
CollectionServiceTags.initializeDefaultTags()
CollectionServiceTags.tagItemsFolder()

print("Initializing player stats system...")
local PlayerStatsManager = require(script.Parent.player.PlayerStatsManager)
PlayerStatsManager.init()

print("Initializing AI system...")
local AIManager = require(script.Parent.ai.AIManager)
local CreatureSpawner = require(script.Parent.ai.creatureSpawner)
local FoodDropSystem = require(script.Parent.loot.FoodDropSystem)

AIManager.getInstance():init()
FoodDropSystem.init()
CreatureSpawner.init()

print("Initializing weapon systems...")

print("All systems initialized. Player stats, day/night cycle, world populated with items, procedural spawners, creatures, and weapons.")

