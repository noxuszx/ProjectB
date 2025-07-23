-- src/shared/config/ItemConfig.lua
-- Configuration file for the Item Spawning System
-- This file defines all loot tables, spawn settings, and spawner types for the session-based scavenging game

local ItemConfig = {
	-- Global settings for the spawning system
	Settings = {
		ItemsFolder = "Items", -- Folder name in ReplicatedStorage where item models are stored
		ScatterRadius = 5, -- Random spawn radius around spawner position (in studs)
		MaxScatterAttempts = 10, -- Max attempts to find valid spawn position
		SpawnHeight = 3, -- Height above spawner position to spawn items (to avoid clipping)
		DebugMode = false, -- Enable debug prints and visualizations
	},

	-- Defines the rules for each type of spawner, linked by the "SpawnType" attribute
	-- Each spawner type can have different loot tables and spawn behavior
	SpawnTypes = {
		-- Common village loot - basic resources and consumables
["VillageCommon"] = {
			MaxRolls = 2,
			MinRolls = 0,
			PossibleLoot = {
				["MetalRoof"] = 0.4, 
				["WoodPlank1"] = 0.6,
				["WoodPlank2"] = 0.5
			}
		},

		-- Dungeon chest loot - valuable but rare items
		["DungeonChest"] = {
			MaxRolls = 1,
			MinRolls = 0,
			PossibleLoot = {
				["MetalRoof"] = 0.6, -- Metal resources
				["WoodPlank1"] = 0.4,
				["WoodPlank2"] = 0.4
			}
		},

		-- Building resource spawner
		["BuildingResource"] = {
			MaxRolls = 3,
			MinRolls = 1,
			PossibleLoot = {
				["WoodPlank1"] = 0.7,
				["WoodPlank2"] = 0.7,
				["MetalRoof"] = 0.3
			}
		},

		-- Construction site - building materials
		["ConstructionSite"] = {
			MaxRolls = 2,
			MinRolls = 0,
			PossibleLoot = {
				["MetalRoof"] = 0.8, -- Common construction material
				["WoodPlank1"] = 0.5,
				["WoodPlank2"] = 0.5
			}
		}
	}
}

return ItemConfig
