# 🎮 Mob Spawner System - Setup Guide

This guide will help you set up the mob spawner system in your Roblox game.

## 📋 Quick Start (5 Minutes)

### Step 1: Copy Files to Your Game
Copy these folders from this project to your Roblox Studio:

```
📁 ServerScriptService/
   └── MobSpawnerSystem/           (Copy entire folder)
       ├── SpawnerController.server.lua
       ├── MobSpawner.lua
       ├── SpawnerConfig.lua
       ├── ChaserNPC.lua
       ├── NPCManager.lua
       └── NPCExample.server.lua

📁 ReplicatedStorage/
   └── MobTemplates/               (Copy entire folder)
       └── (Your mob models here)
```

### Step 2: Create Mob Templates
1. In Roblox Studio, create or import **any** character models/rigs
2. Place them in `ReplicatedStorage/MobTemplates/`
3. Name them **anything you want**: `BasicChaser`, `MyCustomZombie`, `BossEnemy`, etc.
4. Ensure each has: `Humanoid`, `HumanoidRootPart` (other parts optional)
5. **That's it!** The system accepts any valid character model

### Step 3: Create a Spawner
1. Insert a Part into Workspace
2. Name it `"MobSpawner"`
3. **That's it!** The system auto-detects and activates it

---

## ⚙️ Configuration Options

Configure spawners by setting **Attributes** on the MobSpawner part:

### Basic Settings
| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `SpawnRate` | Number | 3.0 | Seconds between spawns |
| `MaxMobs` | Number | 5 | Max mobs per spawner |
| `SpawnRadius` | Number | 10 | Distance from spawner to place mobs |
| `MobType` | String | "BasicChaser" | Which mob template to use (any name) |

### Player Proximity
| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `PlayerRange` | Number | 50 | Only spawn when players within range |
| `DespawnRange` | Number | 100 | Remove mobs when players beyond range |
| `PauseWhenEmpty` | Boolean | true | Pause when no players nearby |

### Advanced Settings
| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `AutoCleanup` | Boolean | true | Remove mobs when spawner deleted |
| `MobLifetime` | Number | 300 | Seconds before mobs despawn (0=never) |
| `RandomPosition` | Boolean | true | Random positions in spawn radius |
| `AvoidCollisions` | Boolean | true | Try to avoid spawning in walls |
| `BatchSpawn` | Boolean | false | Spawn multiple mobs at once |
| `BatchSize` | Number | 2 | Mobs per batch when BatchSpawn=true |

---

## 🎯 Examples

### Example 1: Basic Spawner
```lua
-- Just place a part named "MobSpawner"
-- Uses all default settings
```

### Example 2: Fast Spawner
Set these attributes on your MobSpawner part:
- `SpawnRate` = 1.5 (spawn every 1.5 seconds)
- `MaxMobs` = 10
- `MobType` = "MyZombieRig"

### Example 3: Boss Area Spawner
Set these attributes:
- `SpawnRate` = 10.0 (spawn every 10 seconds)
- `MaxMobs` = 2
- `MobType` = "BossMinion" 
- `PlayerRange` = 30 (only spawn when players close)
- `SpawnRadius` = 5 (tight spawn area)

### Example 4: High-Traffic Area
Set these attributes:
- `BatchSpawn` = true
- `BatchSize` = 3
- `SpawnRate` = 2.0
- `MaxMobs` = 15

---

## 🛠️ Using Any Custom Rigs

### 🎯 **Total Flexibility**
The system accepts **ANY** character model with a `Humanoid`:
- Your custom rigs from Blender/Maya
- Downloaded models from the Toolbox
- R15/R6 characters
- Fantasy creatures, robots, animals, etc.
- **Any name you want**: `ZombieRig`, `MyEnemy`, `BossMonster`, etc.

### Built-in Mob Types (Optional)
If you want to use the built-in AI configurations:
| Type | Speed | Damage | Range | Description |
|------|-------|--------|-------|--------------|
| `BasicChaser` | 16 | 10 | 100 | Balanced mob |
| `FastChaser` | 24 | 15 | 120 | Fast and dangerous |
| `SlowChaser` | 10 | 5 | 80 | Slow but persistent |
| `TankChaser` | 8 | 25 | 60 | Slow but high damage |

### Adding Your Custom Rigs
1. **Drag and drop** any character model into `ReplicatedStorage/MobTemplates/`
2. **Name it anything**: `MyZombie`, `AlienInvader`, `GuardBot`, etc.
3. **Optional**: Add a `ServerScript` inside for custom behavior
4. **That's it!** Use the name in `MobType` attribute

---

## 📊 Performance Tips

### For Many Spawners (10+)
- Set `PauseWhenEmpty` = true
- Use larger `SpawnRate` values (3+ seconds)
- Keep `MaxMobs` reasonable (5-10 per spawner)

### For High Player Count
- Increase `PlayerRange` to avoid spawner conflicts
- Use `BatchSpawn` for busy areas
- Consider `MobLifetime` to prevent accumulation

### For Large Maps
- Use `DespawnRange` to cleanup distant mobs
- Place spawners strategically near player paths
- Monitor performance with the built-in reporting

---

## 🔧 Troubleshooting

### "MobTemplates folder not found"
- Ensure `ReplicatedStorage/MobTemplates/` folder exists
- Check that it contains at least one mob model

### "Mob type 'X' not found"
- Verify the mob model exists in `MobTemplates/`
- Check the exact spelling and capitalization
- System will auto-fallback to any available template if yours isn't found

### Spawner not working
- Check that the part is named exactly `"MobSpawner"`
- Verify the part is directly in Workspace
- Ensure players are within `PlayerRange`

### 🆕 Fixed Issues (Jan 7, 2025)

### ~~Mobs spawning all at once~~ - ✅ FIXED
**Previous issue**: All mobs would spawn simultaneously instead of respecting SpawnRate
**Fix**: Spawn timing completely rewritten to properly enforce intervals
**Now**: Mobs spawn exactly every SpawnRate seconds (e.g., every 3 seconds)

### ~~Too many mobs spawning~~ - ✅ FIXED  
**Previous issue**: Spawners would create 7+ mobs when MaxMobs was set to 3
**Fix**: Added race condition protection and immediate count validation
**Now**: Spawners strictly respect MaxMobs limits

### ~~Empty MobType causing issues~~ - ✅ FIXED
**Previous issue**: Empty or whitespace-only MobType attributes caused errors
**Fix**: Enhanced parsing with proper fallback to "BasicChaser"
**Now**: System handles empty configurations gracefully

### Performance issues
- Reduce number of active spawners
- Increase `SpawnRate` values
- Lower `MaxMobs` per spawner
- Enable `PauseWhenEmpty`

---

## 📈 Monitoring

The system provides automatic performance monitoring:

```lua
-- Access spawner info via global API
local api = _G.MobSpawnerAPI
print("Active spawners:", api.getSpawnerCount())

-- Get detailed status
local controller = api.getController()
for part, spawner in pairs(controller.spawners) do
    local status = spawner:getStatus()
    print(spawner, "has", status.mobCount, "mobs")
end
```

Console output shows performance stats every 10 seconds:
```
MobSpawner Performance: 3 Spawners, 12 Total Mobs, 12 Managed NPCs
```

---

## 🎉 You're Ready!

Your mob spawner system is now set up! 

- Place `MobSpawner` parts anywhere in your game
- Configure them with attributes for different behaviors  
- Watch as mobs automatically spawn and chase players
- Scale up to dozens of spawners with maintained performance

**Need help?** Check the example scripts and configurations included in the system!
