--[[
	ChunkInit.server.lua
	Initialize chunk-based terrain generation
]]--

print("Chunk-based terrain system starting...")

local ChunkManager = require(script.Parent.terrain.ChunkManager)
local CustomModelSpawner = require(script.Parent.spawning.CustomModelSpawner) -- Enabled after manual setup
local DayNightCycle = require(script.Parent.environment.DayNightCycle)
local LightingManager = require(script.Parent.environment.LightingManager)
local ChunkConfig = require(game.ReplicatedStorage.Shared.config.ChunkConfig)
local DragDropServer = require(script.Parent.dragdrop.DragDropServer)

task.wait(2)

ChunkManager.init()

print("Chunk terrain system initialized!")

task.wait(1)

DragDropServer.init()

print("Drag and drop server initialized!")

-- Initialize custom model spawning
CustomModelSpawner.init(
    ChunkConfig.RENDER_DISTANCE,
    ChunkConfig.CHUNK_SIZE,
    ChunkConfig.SUBDIVISIONS
)

print("Terrain system initialized! Model spawning enabled.")

DayNightCycle.init()
LightingManager.init()

print("All systems initialized! Day/night cycle active.")

_G.timeDebug = function()
	local debugInfo = DayNightCycle.getDebugInfo()
	local TimeDebugger = require(game.ReplicatedStorage.Shared.utilities.TimeDebugger)
	TimeDebugger.printOutput(TimeDebugger.formatTimeData(debugInfo))
end

_G.skipTime = function()
	DayNightCycle.skipToNextPeriod()
	local TimeDebugger = require(game.ReplicatedStorage.Shared.utilities.TimeDebugger)
	TimeDebugger.printOutput("Skipped to next time period: " .. DayNightCycle.getCurrentPeriod())
end

_G.setTime = function(hour)
	DayNightCycle.setTime(hour)
	local TimeDebugger = require(game.ReplicatedStorage.Shared.utilities.TimeDebugger)
	TimeDebugger.printOutput("Set time to: " .. DayNightCycle.getFormattedTime())
end

_G.toggleTimeOutput = function()
	local TimeDebugger = require(game.ReplicatedStorage.Shared.utilities.TimeDebugger)
	TimeDebugger.toggleOutput()
end

print("Debug commands available: _G.timeDebug(), _G.skipTime(), _G.setTime(hour), _G.toggleTimeOutput()")
