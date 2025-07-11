--[[
	ChunkInit.server.lua
	Initialize chunk-based terrain generation
]]--

print("Chunk-based terrain system starting...")

-- Require and initialize the chunk manager
local ChunkManager = require(script.Parent.terrain.ChunkManager)
local CustomModelSpawner = require(script.Parent.spawning.CustomModelSpawner) -- Enabled after manual setup
local DayNightCycle = require(script.Parent.environment.DayNightCycle)
local LightingManager = require(script.Parent.environment.LightingManager)
local ChunkConfig = require(game.ReplicatedStorage.Shared.config.ChunkConfig)

-- Wait a moment for the game to fully load
wait(2)

-- Initialize chunk generation
ChunkManager.init()

print("Chunk terrain system initialized!")

-- Wait a moment for chunks to settle
wait(1)

-- Initialize custom model spawning (enable after manual setup)
CustomModelSpawner.init(
	ChunkConfig.RENDER_DISTANCE,
	ChunkConfig.CHUNK_SIZE,
	ChunkConfig.SUBDIVISIONS
)

print("Terrain system initialized! Model spawning enabled.")

-- Wait a moment, then initialize day/night cycle
wait(1)

-- Initialize day/night cycle
DayNightCycle.init()

-- Initialize lighting manager
LightingManager.init()

print("All systems initialized! Day/night cycle active.")

-- Debug functions for testing (can be called from server console)
_G.timeDebug = function()
	local debugInfo = DayNightCycle.getDebugInfo()
	local TimeDebugger = require(game.ReplicatedStorage.Shared.utilities.TimeDebugger)
	print(TimeDebugger.formatTimeData(debugInfo))
end

_G.skipTime = function()
	DayNightCycle.skipToNextPeriod()
	print("Skipped to next time period:", DayNightCycle.getCurrentPeriod())
end

_G.setTime = function(hour)
	DayNightCycle.setTime(hour)
	print("Set time to:", DayNightCycle.getFormattedTime())
end

print("Debug commands available: _G.timeDebug(), _G.skipTime(), _G.setTime(hour)")
