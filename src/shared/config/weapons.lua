--[[
	weapons.lua
	Configuration for weapon system - defines stats and properties for all weapons
	This is the single source of truth for weapon balancing and properties
]]--

local weapons = {
	-- Melee Weapons
	Knife = {
		-- Combat Stats
		Damage = 15,
		Cooldown = 0.5,		-- Time in seconds between attacks
		Range = 4,			-- Attack reach in studs
		
		-- Visual/Audio
		Animation = "rbxassetid://89289879",	-- Placeholder animation ID
		SwingSound = "rbxassetid://131961136",	-- Default swing sound
		HitSound = "rbxassetid://131961136",	-- Sound when hitting target
		
		-- Weapon Properties
		WeaponType = "Melee",
		Weight = "Light",		-- Affects movement speed (future feature)
		Durability = 100,		-- Max durability (future feature)
		
		-- Description for UI/tooltips
		DisplayName = "Combat Knife",
		Description = "A quick, lightweight blade perfect for close combat. Fast attack speed but lower damage."
	},
	
	Machete = {
		-- Combat Stats
		Damage = 25,
		Cooldown = 0.8,		-- Slower than knife
		Range = 6,			-- Longer reach than knife
		
		-- Visual/Audio
		Animation = "rbxassetid://89289879",	-- Placeholder animation ID
		SwingSound = "rbxassetid://131961136",
		HitSound = "rbxassetid://131961136",
		
		-- Weapon Properties
		WeaponType = "Melee",
		Weight = "Medium",
		Durability = 150,
		
		-- Description
		DisplayName = "Machete",
		Description = "A heavy chopping blade with good reach and damage. Balanced weapon for survival."
	},
	
	Spear = {
		-- Combat Stats
		Damage = 20,
		Cooldown = 1.2,		-- Slowest attack speed
		Range = 10,			-- Longest reach
		
		-- Visual/Audio
		Animation = "rbxassetid://89289879",	-- Placeholder animation ID
		SwingSound = "rbxassetid://131961136",
		HitSound = "rbxassetid://131961136",
		
		-- Weapon Properties
		WeaponType = "Melee",
		Weight = "Heavy",
		Durability = 120,
		
		-- Description
		DisplayName = "Survival Spear",
		Description = "A long-reach weapon ideal for keeping enemies at distance. High reach but slow attack speed."
	}
}

-- Weapon system settings
weapons.Settings = {
	-- Global weapon settings
	DefaultCooldown = 1.0,			-- Fallback cooldown if weapon doesn't specify
	DefaultRange = 5,				-- Fallback range if weapon doesn't specify
	DefaultDamage = 10,				-- Fallback damage if weapon doesn't specify
	
	-- Hit detection settings
	HitDetectionMethod = "Raycast",	-- "Raycast" or "Region" (future expansion)
	MaxTargetsPerSwing = 1,			-- How many targets can be hit per attack
	
	-- Visual settings
	ShowDamageNumbers = true,		-- Display floating damage numbers
	ShowHitEffects = true,			-- Show particle effects on hit
	
	-- Audio settings
	GlobalVolume = 0.5,				-- Master volume for weapon sounds
	
	-- Debug settings
	DebugMode = false,				-- Enable debug prints and visualizations
	ShowHitboxes = false			-- Visualize weapon ranges (debug only)
}

-- Helper function to get weapon config safely
function weapons.getWeaponConfig(weaponName)
	local config = weapons[weaponName]
	if not config then
		warn("[WeaponConfig] No configuration found for weapon: " .. tostring(weaponName))
		return nil
	end
	return config
end

-- Helper function to validate weapon config
function weapons.validateWeaponConfig(weaponName)
	local config = weapons.getWeaponConfig(weaponName)
	if not config then
		return false, "Weapon not found"
	end
	
	-- Check required fields
	local requiredFields = {"Damage", "Cooldown", "Range", "WeaponType"}
	for _, field in ipairs(requiredFields) do
		if config[field] == nil then
			return false, "Missing required field: " .. field
		end
	end
	
	return true, "Valid"
end

-- Get all available weapon names
function weapons.getAllWeaponNames()
	local weaponNames = {}
	for weaponName, config in pairs(weapons) do
		-- Skip non-weapon entries (Settings, functions, etc.)
		if type(config) == "table" and config.WeaponType then
			table.insert(weaponNames, weaponName)
		end
	end
	return weaponNames
end

return weapons
