--[[
	SystemLoadMonitor.lua
	Centralized initialization reporting and system status monitoring
	Provides clean, hierarchical console output for all game systems
]]--

local SystemLoadMonitor = {}

-- System configuration with criticality levels
local expectedSystems = {
	-- Major/Critical systems (===)
	{name = "TerrainSystem", critical = true, description = "Chunk-based world generation"},
	{name = "Environment", critical = true, description = "Day/night cycle and lighting"},
	{name = "AIManager", critical = true, description = "200+ creature management system"},
	
	-- Supporting systems (---)
	{name = "CollectionService", critical = false, description = "Object tagging and management"},
	{name = "PlayerStats", critical = false, description = "Health/hunger/thirst mechanics"},
	{name = "FoodSystem", critical = false, description = "Food consumption and water refill"},
	{name = "EconomySystem", critical = false, description = "Cash and trading systems"},
	{name = "ToolSystem", critical = false, description = "Tool granting service"},
	{name = "AmmoService", critical = false, description = "Ammunition management system"},
	{name = "FoodConsumptionServer", critical = false, description = "Server-side food consumption handling"},
	{name = "PedestalController", critical = false, description = "Pedestal detection and interaction system"},
	{name = "SpawnerPlacement", critical = false, description = "Strategic spawner positioning system"},
	{name = "CustomModelSpawner", critical = false, description = "Custom model spawning and management"},
	{name = "CreaturePoolManager", critical = false, description = "Memory pooling system for creature reuse"},
}

-- Tracking state
local loadedSystems = {}
local initStartTime = os.clock()

function SystemLoadMonitor.reportSystemLoaded(systemName, additionalInfo)
	if loadedSystems[systemName] then
		warn("[SystemLoadMonitor] System already reported as loaded:", systemName)
		return
	end
	
	loadedSystems[systemName] = {
		timestamp = os.clock(),
		info = additionalInfo
	}
	
	local systemConfig = nil
	for _, sys in pairs(expectedSystems) do
		if sys.name == systemName then
			systemConfig = sys
			break
		end
	end
	
	if systemConfig then
		print("[" .. systemName .. "] Initialization successful")
		if systemConfig.critical then
			print("<--------------------------------------------->")
		else
			print("-----------------------------------------------")
		end
	else
		-- Unknown system - still report but with warning format
		warn("[SystemLoadMonitor] Unknown system reported:", systemName)
		print("[" .. systemName .. "] Initialization successful")
		print("-----------------------------------------------")
	end
	
	SystemLoadMonitor.checkAllSystemsLoaded()
end

function SystemLoadMonitor.checkAllSystemsLoaded()
	local allLoaded = true
	local criticalLoaded = true
	
	for _, systemConfig in pairs(expectedSystems) do
		if not loadedSystems[systemConfig.name] then
			allLoaded = false
			if systemConfig.critical then
				criticalLoaded = false
			end
		end
	end
	
	-- Report status if all critical systems are loaded
	if criticalLoaded and not SystemLoadMonitor._criticalReported then
		SystemLoadMonitor._criticalReported = true
		local elapsed = os.clock() - initStartTime
		print("🟢 Critical systems online (" .. string.format("%.2f", elapsed) .. "s)")
		print("===============================================")
	end
	
	-- Report final status if all systems are loaded
	if allLoaded and not SystemLoadMonitor._allReported then
		SystemLoadMonitor._allReported = true
		local elapsed = os.clock() - initStartTime
		print("✅ All systems initialized (" .. string.format("%.2f", elapsed) .. "s)")
		print("===============================================")
	end
end

-- Get current system status (for debugging)
function SystemLoadMonitor.getSystemStatus()
	local status = {}
	for _, systemConfig in pairs(expectedSystems) do
		status[systemConfig.name] = {
			loaded = loadedSystems[systemConfig.name] ~= nil,
			critical = systemConfig.critical,
			description = systemConfig.description,
			timestamp = loadedSystems[systemConfig.name] and loadedSystems[systemConfig.name].timestamp
		}
	end
	return status
end

-- Manual system status report (for debugging)
function SystemLoadMonitor.printSystemStatus()
	print("=== SYSTEM STATUS REPORT ===")
	for _, systemConfig in pairs(expectedSystems) do
		local loaded = loadedSystems[systemConfig.name] ~= nil
		local status = loaded and "✅ LOADED" or "❌ PENDING"
		local criticalStr = systemConfig.critical and " [CRITICAL]" or ""
		print(systemConfig.name .. criticalStr .. ": " .. status)
	end
	print("============================")
end

return SystemLoadMonitor