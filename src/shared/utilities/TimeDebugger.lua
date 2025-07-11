--[[
	TimeDebugger.lua
	Debug commands and utility functions for testing the day/night cycle
]]--

local TimeDebugger = {}

-- Debug commands that can be run in the console
TimeDebugger.COMMANDS = {
	["time"] = "Get current time information",
	["skip"] = "Skip to next time period",
	["set <hour>"] = "Set time to specific hour (0-24)",
	["speed <multiplier>"] = "Change day/night cycle speed (coming soon)",
	["info"] = "Show debug information"
}

-- Print available commands
function TimeDebugger.printHelp()
	print("=== TIME DEBUG COMMANDS ===")
	for command, description in pairs(TimeDebugger.COMMANDS) do
		print(string.format("  %s - %s", command, description))
	end
	print("Usage: Call these functions from the server console or scripts")
end

-- Format time data for display
function TimeDebugger.formatTimeData(timeData)
	return string.format([[
=== TIME DEBUG INFO ===
Current Time: %s (%.2f hours)
Current Period: %s
Day Progress: %.1f%%
Cycle Start: %.2f seconds ago
Elapsed Time: %.2f seconds
========================]], 
		timeData.formattedTime,
		timeData.currentTime,
		timeData.currentPeriod,
		timeData.timeProgress * 100,
		timeData.elapsedTime,
		timeData.elapsedTime
	)
end

return TimeDebugger
