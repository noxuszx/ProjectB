--[[
    WeaponConfig.lua
    Configuration for all weapons in the game
]]--


local WeaponConfig = {}

WeaponConfig.RangedWeapons = {
	Crossbow = {
		Damage = 55,
		Range = 200,
		Cooldown = 0.5,
		ProjectileSpeed = 120,
		HeadshotsEnabled = true,
		HeadshotMultiplier = 2,
		BulletConfig = {
			Color = Color3.new(0.8, 0.8, 0.2),
			Size = Vector3.new(0.2, 0.2, 1),
			Lifetime = 2.0,
			Material = Enum.Material.Neon,
		},
		MuzzleEffect = {
			Sound = nil,
			Flash = true,
			FlashColor = Color3.new(1, 0.8, 0),
		},
		DebugEnabled = false,
	},

	Bow = {
		Damage = 20,
		Range = 200,
		Cooldown = 0.5,
		ProjectileSpeed = 120,

		HeadshotsEnabled = true,
		HeadshotMultiplier = 2,
		BulletConfig = {
			Color = Color3.new(0.8, 0.8, 0.2),
			Size = Vector3.new(0.2, 0.2, 1),
			Lifetime = 2.0,
			Material = Enum.Material.Neon,
		},
		MuzzleEffect = {
			Sound = nil,
			Flash = true,
			FlashColor = Color3.new(1, 0.8, 0),
		},
		DebugEnabled = false,
	},

	Rifle = {
		Damage = 35,
		Range = 250,
		Cooldown = 0.5,
		ProjectileSpeed = 300,
		BulletConfig = {
			Color = Color3.new(1, 0.9, 0.7),
			Size = Vector3.new(0.15, 0.15, 0.8),
			Lifetime = 1.5,
			Material = Enum.Material.Neon, -- Glowing effect
		},
		MuzzleEffect = {
			Sound = nil,
			Flash = true,
			FlashColor = Color3.new(1, 1, 0.8),
		},
		DebugEnabled = false,
	},

	SkeletonArrow = {
		Damage = 7,
		Range = 120,
		Cooldown = 1,
		ProjectileSpeed = 80,
		BulletConfig = {
			Color = Color3.new(0.6, 0.4, 0.2),
			Size = Vector3.new(0.1, 0.1, 1.2),
			Lifetime = 3.0,
			Material = Enum.Material.Wood,
		},
		MuzzleEffect = {
			Sound = nil,
			Flash = false,
			FlashColor = Color3.new(0, 0, 0),
		},
		DebugEnabled = false,
	},
}

-- Melee Weapon Configurations
WeaponConfig.MeleeWeapons = {
	Spear = {
		Damage = 25,
		Range = 15,
		Cooldown = 0.4,
		SwingDuration = 0.5,
		Animation = "Slash",
		HitDetection = "Magnitude",
		MaxTargets = 1,
		RequireLineOfSight = true,
		DirectionalAngle = 180,
		HitEffect = {
			Sound = nil,
			Particle = nil,
		},
		DebugEnabled = true,
	},

	Kopesh = {
		Damage = 40,
		Range = 12,
		Cooldown = 0.4,
		SwingDuration = 0.5,
		Animation = "Slash",
		HitEffect = {
			Sound = nil,
			Particle = nil,
		},
		DebugEnabled = false,
	},

	Katana = {
		Damage = 60,
		Range = 12,
		Cooldown = 0.4,
		SwingDuration = 0.5,
		Animation = "Slash",
		HitEffect = {
			Sound = nil,
			Particle = nil,
		},
		DebugEnabled = false,
	},

	Knife = {
		Damage = 15,
		Range = 10,
		Cooldown = 0.4,
		SwingDuration = 0.5,
		Animation = "Slash",
		HitEffect = {
			Sound = nil,
			Particle = nil,
		},
		DebugEnabled = false,
	},

	Machete = {
		Damage = 40,
		Range = 10,
		Cooldown = 0.6,
		SwingDuration = 0.4,
		Animation = "Slash",
		HitEffect = {
			Sound = nil,
			Particle = nil,
		},
		DebugEnabled = false,
	},
}

-- Global weapon settings
WeaponConfig.GlobalSettings = {
	MaxRange = 300,
	MinCooldown = 0.3,
	DefaultDamage = 20,
	RaycastParams = {
		FilterType = Enum.RaycastFilterType.Blacklist,
		FilterDescendantsInstances = {},
	},
	Debug = {
		ShowRaycast = false,
		PrintHitInfo = false,
		ShowCooldownUI = false,
		ShowMeleeRange = false,
	},
}

-- Helper function for getting the weapon config
function WeaponConfig.getWeaponConfig(weaponName)
	local config = WeaponConfig.RangedWeapons[weaponName]
	if config then
		config.WeaponType = "Ranged"
		return config
	end

	config = WeaponConfig.MeleeWeapons[weaponName]
	if config then
		config.WeaponType = "Melee"
		return config
	end

	-- Fallback for unknown weapons
	warn("[WeaponConfig] No configuration found for weapon:", weaponName)
	return {
		WeaponType = "Melee",
		Damage = WeaponConfig.GlobalSettings.DefaultDamage,
		Range = 10,
		Cooldown = 1.0,
		SwingDuration = 0.3,
		Animation = "Slash",
		HitEffect = {},
		DebugEnabled = false,
	}
end

function WeaponConfig.getRangedWeaponConfig(weaponName)
	local config = WeaponConfig.RangedWeapons[weaponName]
	if not config then
		warn("[WeaponConfig] No ranged weapon configuration found for:", weaponName)
		return nil
	end
	config.WeaponType = "Ranged"
	return config
end

-- Helper function to validate weapon config
function WeaponConfig.validateConfig(weaponName, config)
	local errors = {}

	if not config.Damage or config.Damage <= 0 then
		table.insert(errors, "Invalid damage value")
	end

	if not config.Range or config.Range <= 0 or config.Range > WeaponConfig.GlobalSettings.MaxRange then
		table.insert(errors, "Invalid range value")
	end

	if not config.Cooldown or config.Cooldown < WeaponConfig.GlobalSettings.MinCooldown then
		table.insert(errors, "Invalid cooldown value")
	end

	if #errors > 0 then
		warn("[WeaponConfig] Validation failed for", weaponName .. ":", table.concat(errors, ", "))
		return false
	end

	return true
end

return WeaponConfig
