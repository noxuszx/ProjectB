-- src/shared/config/EconomyConfig.lua
-- Configuration for the Economy System
-- Defines sellable item values, buyable items, and economy settings

local EconomyConfig = {
	-- Starting money for new players
	STARTING_MONEY = 0,
	
	-- Sellable item values (matched to CollectionService tags)
	SellableItems = {
		SELLABLE_LOW = 15,    -- Low-value items (scrap metal, wood scraps, cloth)
		SELLABLE_MID = 25,    -- Mid-value items (refined materials, tools, electronics)
		SELLABLE_HIGH = 50,   -- High-value items (rare materials, gems, advanced components)
	},
	
	-- Buyable items that can spawn at buy zones
	BuyableItems = {
		-- Tools and weapons (if available)
		{
			ItemName = "Spear",
			Cost = 75,
			SpawnWeight = 0.1,
			Category = "Tools"
		},
		{
			ItemName = "Crossbow",
			Cost = 100,
			SpawnWeight = 0.05,
			Category = "Weapons"
		},
		
		-- Consumables/Food
		{
			ItemName = "Medkit",
			Cost = 10,
			SpawnWeight = 0.4,
			Category = "Food"
		},
	},
	
	-- Zone settings
	Zones = {
		-- Sell zone configuration
		SellZone = {
			TouchCooldown = 1.0, -- Seconds between sells to prevent spam
			EffectDuration = 0.5, -- Visual effect duration
			SoundEnabled = true,
		},
		
		-- Buy zone configuration
		BuyZone = {
			SpawnHeight = 2, -- Studs above the buy zone part
			ProximityRange = 10, -- Range for proximity prompt activation
			InteractionCooldown = 0.5, -- Prevent rapid clicking
			RandomSpawnChance = true, -- Whether to use weighted random selection
		}
	},
	
	-- UI Settings
	UI = {
		MoneyDisplay = {
			BackgroundColor = Color3.fromRGB(0, 150, 0), -- Green background
			TextColor = Color3.fromRGB(255, 255, 255), -- White text
			DollarSignColor = Color3.fromRGB(255, 215, 0), -- Gold dollar sign
			Position = UDim2.new(1, -170, 0, 120), -- Top-right, above inventory counter
			Size = UDim2.new(0, 150, 0, 30),
			UpdateAnimationTime = 0.3, -- Smooth money updates
		},
		
		-- Highlighting colors for buy zones
		Highlighting = {
			CanAfford = Color3.fromRGB(0, 255, 0), -- Green
			CannotAfford = Color3.fromRGB(255, 0, 0), -- Red
			Brightness = 0.3,
			Transparency = 0.5,
		}
	},
	
	-- Performance settings
	Performance = {
		BatchUpdatesEnabled = true, -- Batch money updates to reduce network calls
		UpdateBatchSize = 5, -- Max operations per batch
		TouchDebounceTime = 0.1,
		HighlightUpdateRate = 0.5,
	},
	
	-- Debug settings
	Debug = {
		Enabled = true, -- Enable debug to check pooling
		LogSells = true,
		LogBuys = true,
		LogMoneyChanges = true,
	}
}

return EconomyConfig