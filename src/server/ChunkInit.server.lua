--[[
	ChunkInit.server.lua
	Initialize chunk-based terrain generation
]]--

print("Chunk-based terrain system starting...")

local ChunkManager = require(script.Parent.terrain.ChunkManager)
local CustomModelSpawner = require(script.Parent.spawning.CustomModelSpawner) -- Enabled after manual setup
local DayNightCycle = require(script.Parent.environment.DayNightCycle)
local VillageSpawner = require(script.Parent.spawning.VillageSpawner)
local LightingManager = require(script.Parent.environment.LightingManager)
local ChunkConfig = require(game.ReplicatedStorage.Shared.config.ChunkConfig)
local DragDropServer = require(script.Parent.dragdrop.DragDropServer)

task.wait(2)

ChunkManager.init()

print("Chunk terrain system initialized")

task.wait(1)

DragDropServer.init()

print("Drag and drop server initialized")

CustomModelSpawner.init(
    ChunkConfig.RENDER_DISTANCE,
    ChunkConfig.CHUNK_SIZE,
    ChunkConfig.SUBDIVISIONS
)

print("Terrain system initialized Model spawning enabled.")

DayNightCycle.init()
LightingManager.init()
VillageSpawner.spawnVillages()

print("All systems initialized Day/night cycle active.")

