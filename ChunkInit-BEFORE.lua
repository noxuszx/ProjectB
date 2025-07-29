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

print("Initializing core systems...")
DayNightCycle.init()
LightingManager.init()

print("Initializing drag-drop system tags...")
CollectionServiceTags.initializeDefaultTags()
CollectionServiceTags.tagItemsFolder()

print("Initializing player stats system...")
local PlayerStatsManager = require(script.Parent.player.PlayerStatsManager)
PlayerStatsManager.init()
task.wait(0.5)

print("Initializing water refill system...")
local WaterRefillManager = require(script.Parent.food.WaterRefillManager)
WaterRefillManager.init()
task.wait(0.5)

print("Placing procedural creature spawners...")
local SpawnerPlacement = require(script.Parent.ai.spawnerPlacement)
SpawnerPlacement.run()
task.wait(1)

print("Initializing item spawning...")
ItemSpawner.Initialize()
task.wait(1)

print("Initializing AI system...")
local AIManager = require(script.Parent.ai.AIManager)
local FoodDropSystem = require(script.Parent.loot.FoodDropSystem)
local CreatureSpawner = require(script.Parent.ai.creatureSpawner)

AIManager.getInstance():init()
task.wait(0.5)
FoodDropSystem.init()
task.wait(0.5)
CreatureSpawner.init()

print("Initializing weapon systems...")

print("All systems initialized. Player stats, day/night cycle, world populated with items, procedural spawners, creatures, and weapons.")