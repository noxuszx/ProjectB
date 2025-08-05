--[[
    WeaponConfig.lua
    Configuration for all weapons in the game
    Supports melee weapons with different stats and behaviors
]]--

local WeaponConfig = {}

-- Ranged Weapon Configurations
WeaponConfig.RangedWeapons = {
    Crossbow = {
        Damage = 50,
        Range = 200,         -- Studs
        Cooldown = 2.5,      -- Seconds between shots
        ProjectileSpeed = 120, -- Studs per second (for bullet travel)
        BulletConfig = {
            Color = Color3.new(0.8, 0.8, 0.2),  -- Yellow-ish bullet
            Size = Vector3.new(0.2, 0.2, 1),     -- Bullet dimensions
            Lifetime = 2.0,    -- How long bullet exists
            Material = Enum.Material.Neon,       -- Glowing effect
        },
        MuzzleEffect = {
            Sound = nil,       -- Optional firing sound ID
            Flash = true,      -- Show muzzle flash
            FlashColor = Color3.new(1, 0.8, 0),
        },
        DebugEnabled = false
    },
    
    Rifle = {
        Damage = 35,
        Range = 250,
        Cooldown = 1.2,
        ProjectileSpeed = 300,
        BulletConfig = {
            Color = Color3.new(1, 0.9, 0.7),
            Size = Vector3.new(0.15, 0.15, 0.8),
            Lifetime = 1.5,
            Material = Enum.Material.Neon,       -- Glowing effect
        },
        MuzzleEffect = {
            Sound = nil,
            Flash = true,
            FlashColor = Color3.new(1, 1, 0.8),
        },
        DebugEnabled = false
    },
    
    SkeletonArrow = {
        Damage = 6,          -- Low damage for NPCs (matches AIConfig setting)
        Range = 120,         -- Maximum shooting distance
        Cooldown = 2.0,      -- Time between NPC shots (not used with burst system)
        ProjectileSpeed = 80, -- Slower than player weapons
        BulletConfig = {
            Color = Color3.new(0.6, 0.4, 0.2),    -- Brown/wooden arrow color
            Size = Vector3.new(0.1, 0.1, 1.2),     -- Long thin arrow
            Lifetime = 3.0,    -- Longer lifetime for slower projectile
            Material = Enum.Material.Wood,         -- Wooden material
        },
        MuzzleEffect = {
            Sound = nil,       -- No muzzle flash for arrows
            Flash = false,     
            FlashColor = Color3.new(0, 0, 0),
        },
        DebugEnabled = false
    }
}

-- Melee Weapon Configurations
WeaponConfig.MeleeWeapons = {
    Spear = {
        Damage = 25,
        Range = 15,          -- Studs
        Cooldown = 1.2,      -- Seconds between attacks
        SwingDuration = 0.3, -- How long the swing animation lasts
        Animation = "Slash",  -- R6 animation name
        HitEffect = {
            Sound = nil,      -- Optional hit sound ID
            Particle = nil,   -- Optional particle effect
        },
        DebugEnabled = false   -- Enable debug prints for this weapon
    },
    
    Katana = {
        Damage = 30,
        Range = 12,
        Cooldown = 0.8,
        SwingDuration = 0.25,
        Animation = "Slash",
        HitEffect = {
            Sound = nil,
            Particle = nil,
        },
        DebugEnabled = false
    },
    
    Knife = {
        Damage = 15,
        Range = 8,
        Cooldown = 0.6,      -- Fast attacks, low damage
        SwingDuration = 0.2,
        Animation = "Slash",
        HitEffect = {
            Sound = nil,
            Particle = nil,
        },
        DebugEnabled = false
    },
    
    Machete = {
        Damage = 40,
        Range = 10,
        Cooldown = 1.8,      -- Slow but powerful
        SwingDuration = 0.4,
        Animation = "Slash",
        HitEffect = {
            Sound = nil,
            Particle = nil,
        },
        DebugEnabled = false
    }
}

-- Global weapon settings
WeaponConfig.GlobalSettings = {
    MaxRange = 300,          -- Maximum possible weapon range (increased for ranged NPC weapons)
    MinCooldown = 0.3,       -- Minimum cooldown to prevent spam
    DefaultDamage = 20,      -- Fallback damage if weapon not configured
    RaycastParams = {
        FilterType = Enum.RaycastFilterType.Blacklist,
        FilterDescendantsInstances = {}, -- Will be populated with player characters
    },
    Debug = {
        ShowRaycast = false,     -- Visualize raycast in 3D world
        PrintHitInfo = true,     -- Print hit information to console
        ShowCooldownUI = false,  -- Show cooldown indicator (future feature)
    }
}

-- Helper function to get weapon config
function WeaponConfig.getWeaponConfig(weaponName)
    -- Try ranged weapons first
    local config = WeaponConfig.RangedWeapons[weaponName]
    if config then
        config.WeaponType = "Ranged"
        return config
    end
    
    -- Then try melee weapons
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
        DebugEnabled = false
    }
end

-- Helper function to get ranged weapon config specifically
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