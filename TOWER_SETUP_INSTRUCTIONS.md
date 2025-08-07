# Tower Spawner System Setup Instructions

## Required Setup Steps

### 1. Add ZonePlus Module
Download ZonePlus from: https://www.roblox.com/library/4664437268/ZonePlus-v3-2-0
Place the ModuleScript at: `ReplicatedStorage > Shared > modules > ZonePlus`

### 2. Studio Setup (Already Completed)
Your tower structure should look like:
```
Workspace > Towers > Tower_A (tagged "Tower")
├─ Floor1 (Attribute: FloorIndex = 1)
│  ├─ Trigger (Part) 
│  └─ Spawner (Part, tagged "MobSpawner", Attributes: SpawnInterval=5.0, MaxActive=3)
├─ Floor2 (Attribute: FloorIndex = 2)
│  ├─ Trigger (Part)
│  └─ Spawner (Part, tagged "MobSpawner", Attributes: SpawnInterval=3.0, MaxActive=4)
└─ Floor3 (etc...)
```

### 3. Configuration
The system is configured in `src/shared/config/ai/AIConfig.lua`:
- Tower-specific settings: `AIConfig.TowerSpawning.Towers.Tower_A`
- Tower creature types: `AIConfig.TowerSpawning.TowerCreatureTypes`
- Global settings: `AIConfig.TowerSpawning.Settings`

## How It Works

1. **Floor 1 (Ground Floor)** activates immediately on server start
2. **Higher floors** activate when players enter the **previous floor's trigger zone**
3. **Creatures spawn** based on SpawnInterval and MaxActive attributes
4. **Tower creatures** get indoor LOD bias (1.5x update rates: 30Hz→45Hz, 15Hz→22Hz, 2Hz→3Hz)
5. **Safety mechanisms** prevent stuck spawners and force deactivation after 120s empty

## Testing Steps

1. **Place ZonePlus module** in ReplicatedStorage.Shared.modules
2. **Start the game** - Floor 1 should activate and spawn creatures
3. **Walk into Floor 1 trigger zone** - Floor 2 should activate
4. **Check debug labels** (if enabled) - Should show LOD status above creatures
5. **Verify indoor LOD bias** - Tower creatures should have higher update rates than outdoor creatures

## Features Implemented

✅ **ZonePlus Integration** - Proximity detection for floor activation  
✅ **Event-Based Architecture** - AIManager.RegisterSpawnSource() for loose coupling  
✅ **Zone-Based Spawning** - CreatureSpawner supports both procedural and zone modes  
✅ **Indoor LOD Bias** - 1.5x multiplier for tower creature update rates  
✅ **Tower Creature Types** - Inherit from base types with overrides  
✅ **Safety Mechanisms** - Force deactivation, debouncing, StreamingEnabled support  
✅ **Per-Tower Configuration** - Designer control without code changes  
✅ **Performance Integration** - Tower creatures use existing pooling and optimization  

## Troubleshooting

- **No spawning**: Check that Tower is tagged "Tower" and Spawners tagged "MobSpawner"
- **No floor activation**: Verify FloorIndex attributes are Numbers (not strings)
- **ZonePlus errors**: Ensure ZonePlus module is in correct location
- **Performance issues**: Check tower creature limits in AIConfig.TowerSpawning.Settings

The system is ready to use! Tower creatures will automatically inherit all existing performance optimizations while providing zone-based activation gameplay.