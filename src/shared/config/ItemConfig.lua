-- src/shared/config/ItemConfig.lua
-- Configuration file for the Item Spawning System
-- This file defines all loot tables, spawn settings, and spawner types for the session-based scavenging game

local ItemConfig = {
	Settings = {
		ItemsFolder = "Items",
		ScatterRadius = 5,
		MaxScatterAttempts = 10,
		SpawnHeight = 0,
		DebugMode = false,
	},

	SpawnTypes = {
		["build"] = {
			MaxRolls = 1,
			MinRolls = 0,
			PossibleLoot = {
				["MetalRoof"] = 0.4,
				["Wooden Pallet"] = 0.6,
			}
		},

		["scrap"] = {
			MaxRolls = 2,
			MinRolls = 0,
			PossibleLoot = {
				["ClayVase1"] = 0.6,
				["ClayVase2"] = 0.4,
				["Bucket"] = 0.4,
				["Barrel"] = 0.4,
				["Kettle"] = 0.4,
			}
		},
		["low"] = {
			MaxRolls = 3,
			MinRolls = 0,
			PossibleLoot = {
				["Silver Bar"] = 0.3,
				["Silver Cup"] = 0.4,
				["Silver Plate"] = 0.4,

			}
		},

		["mid"] = {
			MaxRolls = 1,
			MinRolls = 0,
			PossibleLoot = {
				["Gold Bar"] = 0.3,
				["Gold Vase1"] = 0.7,
				["Gold Vase2"] = 0.6,
				["Gold Vase3"] = 0.5

			}
		},

		["high"] = {
			MaxRolls = 2,
			MinRolls = 0,
			PossibleLoot = {
				["Gold Statue"] = 0.8,
				["Gold Crown"] = 0.5,

			}
		}
	}
}

return ItemConfig
