-- SystemLoadMonitorInit.server.lua
-- Loads the SystemLoadMonitor module into _G for global access

local SystemLoadMonitor = require(script.Parent.SystemLoadMonitor)

-- Make it globally accessible
_G.SystemLoadMonitor = SystemLoadMonitor