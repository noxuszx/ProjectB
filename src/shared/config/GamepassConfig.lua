-- src/shared/config/GamepassConfig.lua
-- Central config for backpack capacities, tool names, and gamepass IDs (to fill later).

local GamepassConfig = {}

GamepassConfig.CAPACITY = {
    Base = 10,
    Pro = 20,
    Prestige = 30,
}

GamepassConfig.TOOL_NAMES = {
    Base = "Backpack",
    Pro = "BackpackPro", -- matches your actual Tool name in ReplicatedStorage/Tools
    Prestige = "BackpackPrestige",
}

-- Fill these with real numeric IDs later.
GamepassConfig.IDS = {
    PRO = 1406690237,        -- Backpack Pro
    PRESTIGE = 1407472360,   -- Backpack Prestige
}

return GamepassConfig
