-- src/shared/config/EconomyConfig.lua
-- Configuration for the Economy System

local EconomyConfig = {
	-- NOT BEING USED
	STARTING_MONEY = 0,

	-- Sellable item values
	SellableItems = {
		SELLABLE_SCRAP = 5,
		SELLABLE_LOW = 15,
		SELLABLE_MID = 25,
		SELLABLE_HIGH = 50,
	},

	-- Humanoid enemy sell values
	CreatureSellValues = {
		EgyptianSkeleton = 5,
		EgyptianSkeleton2 = 5,
		SkeletonArcher = 10,
		Mummy = 10,
		TowerSkeleton = 10,
		TowerMummy = 10,
		-- Intentionally exclude any Villager* types
	},

	-- CATEGORIES: "Weapons", "Health", "Food", "Ammo"
	BuyableItems = {
		{
			ItemName = "Spear",
			Cost = 75,
			SpawnWeight = 0.3,
			Category = "Weapons",
			Type = "Tool",
			GiveToolName = "Spear",
		},
		{
			ItemName = "Crossbow",
			Cost = 100,
			SpawnWeight = 0.4,
			Category = "Weapons",
			Type = "Tool",
			GiveToolName = "Crossbow",
		},
		{
			ItemName = "Bow",
			Cost = 20,
			SpawnWeight = 0.4,
			Category = "Weapons",
			Type = "Tool",
			GiveToolName = "Bow",
		},
		{
			ItemName = "Katana",
			Cost = 200,
			SpawnWeight = 0.1,
			Category = "Weapons",
			Type = "Tool",
			GiveToolName = "Katana",
		},
		{
			ItemName = "Machete",
			Cost = 70,
			SpawnWeight = 0.4,
			Category = "Weapons",
			Type = "Tool",
			GiveToolName = "Machete",
		},
		{
			ItemName = "Medkit",
			Cost = 30,
			SpawnWeight = 0.4,
			Category = "Health",
			Type = "Tool",
			GiveToolName = "Medkit",
		},
		{
			ItemName = "Bandage",
			Cost = 10,
			SpawnWeight = 0.7,
			Category = "Health",
			Type = "Tool",
			GiveToolName = "Bandage",
		},

		-- AMMO [!]
		{
			ItemName = "Bolts",
			Cost = 10,
			SpawnWeight = 0.6,
			Category = "Ammo",
			Type = "Ammo",
			AmmoType = "CrossbowBolt",
			AmmoAmount = 5,
		},

		-- FOOD [!]
		{
			ItemName = "CamelMeat",
			Cost = 20,
			SpawnWeight = 0.5,
			Category = "Food",
			Type = "Food",
		},
		{
			ItemName = "CoyoteMeat",
			Cost = 15,
			SpawnWeight = 0.5,
			Category = "Food",
			Type = "Food",
		},
		{
			ItemName = "RabbitMeat",
			Cost = 5,
			SpawnWeight = 0.5,
			Category = "Food",
			Type = "Food",
		},
		{
			ItemName = "ScorpionMeat",
			Cost = 20,
			SpawnWeight = 0.5,
			Category = "Food",
			Type = "Food",
		},
	},

	-- Zone settings
	Zones = {
		SellZone = {
			TouchCooldown = 1.0,
			EffectDuration = 0.5,
			SoundEnabled = true,
		},

		BuyZone = {
			SpawnHeight = 2, -- Studs above the buy zone part
			ProximityRange = 10, -- Range for proximity prompt activation
			InteractionCooldown = 0.5, -- Prevent rapid clicking
			RandomSpawnChance = true, -- Whether to use weighted random selection
		},
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

		Highlighting = {
			CanAfford = Color3.fromRGB(0, 255, 0), -- Green
			CannotAfford = Color3.fromRGB(255, 0, 0), -- Red
			Brightness = 0.3,
			Transparency = 0.5,
		},
	},

	Performance = {
		BatchUpdatesEnabled = true,
		UpdateBatchSize = 5,
		TouchDebounceTime = 0.3,
		HighlightUpdateRate = 0.5,
	},

	Debug = {
		Enabled = true,
		LogSells = true,
		LogBuys = true,
		LogMoneyChanges = true,
	},
}

return EconomyConfig
