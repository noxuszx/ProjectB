-- src/shared/config/ItemConfig.lua
-- Configuration file for the Item Spawning System
-- This file defines all loot tables, spawn settings, and spawner types for the session-based scavenging game

local ItemConfig = {
	Settings = {
		ItemsFolder = "Items",
		ScatterRadius = 5,
		MaxScatterAttempts = 10,
		SpawnHeight = 3,
		DebugMode = false,
	},

	SpawnTypes = {
["VillageCommon"] = {
			MaxRolls = 2,
			MinRolls = 0,
			PossibleLoot = {
				["MetalRoof"] = 0.4,
				["WoodPlank1"] = 0.6,
				["WoodPlank2"] = 0.5,
				["Knife"] = 0.15
			}
		},

		["DungeonChest"] = {
			MaxRolls = 1,
			MinRolls = 0,
			PossibleLoot = {
				["MetalRoof"] = 0.6,
				["WoodPlank1"] = 0.4,
				["WoodPlank2"] = 0.4,
				["Machete"] = 0.25,
				["Spear"] = 0.20
			}
		},

		["BuildingResource"] = {
			MaxRolls = 3,
			MinRolls = 1,
			PossibleLoot = {
				["WoodPlank1"] = 0.7,
				["WoodPlank2"] = 0.7,
				["MetalRoof"] = 0.3
			}
		},

		["ConstructionSite"] = {
			MaxRolls = 2,
			MinRolls = 0,
			PossibleLoot = {
				["MetalRoof"] = 0.8,
				["WoodPlank1"] = 0.5,
				["WoodPlank2"] = 0.5,
				["Knife"] = 0.10
			}
		}
	}
}

return ItemConfig
