# ProjectB - Desert Survival World

A Roblox survival game with procedural terrain, intelligent AI creatures, hunting mechanics, and building systems in a dynamic desert world.

## 🎮 Features

- **Procedural Desert World** - Infinite landscapes with chunk-based generation
- **Smart AI Creatures** - Behavior-driven NPCs with roaming, hunting, and fleeing
- **Day/Night Cycle** - 8-minute cycles affecting spawning and atmosphere  
- **Hunting & Cooking** - Kill animals, cook meat over fires, manage hunger
- **Interactive Building** - Drag, drop, weld, and rotate objects
- **Village Exploration** - Discover settlements with NPCs and resources
- **Combat System** - Weapon-based combat with multiple creature types
- **Creature Pooling** - Seamless respawning system with population control
- **Performance Optimized** - LOD system and pooling handle 100+ creatures smoothly
- **Economy System** - Buy/sell zones with proximity prompts and cash collection
- **Backpack System** - LIFO sack inventory with ProximityPrompt UI integration

## 🎯 Gameplay

### Survival
- Hunt rabbits, wolves, and other creatures for food
- Cook raw meat using campfires, stoves, or grills to increase hunger value
- Press E near food to consume and restore hunger
- Animals automatically respawn from pools after being killed
- Explore villages for resources and building materials

### Combat
- **Passive**: Rabbits flee when attacked, drop meat
- **Hostile**: Wolves, mummies, skeletons chase players
- **Night creatures**: Some enemies only spawn after dark

### Building
- Drag and drop items with mouse
- Press Z to weld touching objects
- Press R to rotate, X to change rotation axis

### Economy & Trading
- **Sell items** by dragging them into sell zones (tagged with `SELL_ZONE`)
- **Collect cash** from spawned cash meshparts using proximity prompts
- **Buy items** using proximity prompts on items in buy zones (tagged with `BUY_ZONE`)
- **Session-based money** - resets each game join for roguelike experience

### Inventory Management
- **Equip Sack tool** to access 10-slot LIFO inventory
- **Press E** to store highlighted items (look at item first)
- **Press F** to retrieve last stored item (drops in front of player)
- **Mobile support** - Touch buttons appear automatically on mobile devices

## 🏗️ Project Structure

```
src/
├── client/                   # Client-side scripts and UI
│   ├── backpack/            # Inventory system
│   │   └── BackpackController.client.lua
│   ├── dragdrop/            # Drag & drop mechanics
│   │   ├── interactableHandler.client.lua
│   │   └── weldSystem.lua
│   ├── economy/             # Economy system UI
│   │   ├── EconomyUI.client.lua
│   │   └── ItemHoverHighlighting.client.lua
│   ├── food/                # Client-side food consumption
│   │   └── FoodConsumption.client.lua
│   ├── ragdoll/             # Ragdoll effects
│   │   └── RagdollClient.client.lua
│   ├── ui/                  # UI components
│   │   ├── BackpackUI.client.lua
│   │   ├── CreatureHealthBars.client.lua
│   │   ├── Crosshair.client.lua
│   │   └── EconomyUI.client.lua
│   ├── FlyScript.client.lua
│   ├── init.client.luau
│   └── StatsDisplay.client.lua
├── server/                  # Server-side game logic
│   ├── ai/                  # AI system and creature behaviors
│   │   ├── behaviors/       # AI behavior implementations
│   │   │   ├── AIBehavior.lua
│   │   │   ├── Chasing.lua
│   │   │   ├── Fleeing.lua
│   │   │   └── Roaming.lua
│   │   ├── creatures/       # Creature type definitions
│   │   │   ├── Base.lua
│   │   │   ├── Hostile.lua
│   │   │   └── Passive.lua
│   │   ├── AICreatureRegistry.lua
│   │   ├── AIDebugger.lua
│   │   ├── AIManager.lua
│   │   ├── creatureSpawner.lua
│   │   ├── CreaturePoolManager.lua
│   │   ├── LODPolicy.lua
│   │   └── spawnerPlacement.lua
│   ├── dragdrop/            # Server-side drag & drop
│   │   ├── collisions.server.lua
│   │   └── interactableHandler.server.lua
│   ├── economy/             # Economy system
│   │   ├── BuyZoneHandler.server.lua
│   │   ├── CashCollectionHandler.server.lua
│   │   ├── CashPoolManager.lua
│   │   └── SellZoneHandler.server.lua
│   ├── environment/         # Environmental systems
│   │   ├── DayNightCycle.lua
│   │   └── Lighting.lua
│   ├── food/                # Server-side food management
│   │   ├── FoodConsumeServ.server.lua
│   │   └── WaterRefillManager.lua
│   ├── loot/                # Loot drop systems
│   │   └── FoodDropSystem.lua
│   ├── player/              # Player management
│   │   ├── BackpackHandler.server.lua
│   │   ├── BackpackService.lua
│   │   ├── PlayerDeathHandler.server.lua
│   │   └── PlayerStatsManager.lua
│   ├── services/            # Core services
│   │   └── EconomyService.lua
│   ├── spawning/            # Spawning systems
│   │   ├── CustomModelSpawner.lua
│   │   ├── ItemSpawner.lua
│   │   └── VillageSpawner.lua
│   ├── terrain/             # World generation
│   │   └── ChunkManager.lua
│   ├── weapons/             # Combat system
│   │   └── weaponServer.server.lua
│   └── ChunkInit.server.lua
└── shared/                  # Shared code and configuration
    ├── config/              # Configuration files
    │   ├── ai/              # AI-specific configs
    │   │   ├── AIConfig.lua
    │   │   ├── CreatureSpawning.lua
    │   │   └── SpawnerPlacing.lua
    │   ├── ChunkConfig.lua
    │   ├── DragDropConfig.lua
    │   ├── EconomyConfig.lua
    │   ├── ItemConfig.lua
    │   ├── ModelSpawnerConfig.lua
    │   ├── PlayerStatsConfig.lua
    │   ├── Time.lua
    │   ├── Village.lua
    │   └── WeaponConfig.lua
    ├── modules/             # Shared modules
    │   └── RagdollModule.lua
    └── utilities/           # Utility functions
        ├── CollectionServiceTags.lua
        ├── NoiseGenerator.lua
        ├── terrain.lua
        └── TimeDebugger.lua
```

## 📋 Key Files Index

### Core Systems
- **`AIManager.lua`** - Main AI system coordinator, handles creature lifecycle and LOD
- **`LODPolicy.lua`** - Level-of-detail system for performance optimization
- **`AIDebugger.lua`** - AI system debugging and performance monitoring tools
- **`ChunkManager.lua`** - Procedural terrain generation and chunk management
- **`PlayerStatsManager.lua`** - Player hunger/thirst system

### AI & Creatures
- **`AICreatureRegistry.lua`** - Centralized creature tracking and management
- **`CreaturePoolManager.lua`** - Handles creature pooling, respawning, and population limits
- **`Base.lua`** - Base creature class with shared behaviors
- **`Passive.lua`** - Peaceful creatures (rabbits, deer)
- **`Hostile.lua`** - Aggressive creatures (wolves, mummies)
- **`CreatureSpawner.lua`** - Handles creature spawning logic

### Behaviors
- **`Roaming.lua`** - Random movement patterns for idle creatures
- **`Chasing.lua`** - Pursuit behavior for hostile creatures
- **`Fleeing.lua`** - Escape behavior for passive creatures

### Client UI
- **`StatsDisplay.client.lua`** - Player hunger/thirst bars
- **`CreatureHealthBars.client.lua`** - Health indicators above creatures
- **`BackpackUI.client.lua`** - LIFO inventory counter and mobile controls
- **`EconomyUI.client.lua`** - Money display with green background
- **`ItemHoverHighlighting.client.lua`** - Visual affordability feedback for buyable items

### Economy System
- **`EconomyService.lua`** - Core money management and transaction handling
- **`BuyZoneHandler.server.lua`** - Auto-spawns buyable items with proximity prompts
- **`SellZoneHandler.server.lua`** - Processes item sales and spawns cash
- **`CashPoolManager.lua`** - Object pooling for cash collection efficiency

### Inventory System
- **`BackpackService.lua`** - Server-side LIFO stack management with object pooling
- **`BackpackController.client.lua`** - Client input handling (E/F keys, mobile buttons)
- **`BackpackHandler.server.lua`** - RemoteEvent communication bridge

### Configuration
- **`AIConfig.lua`** - Core AI system settings and performance tuning
- **`PlayerStatsConfig.lua`** - Hunger/thirst mechanics and UI settings
- **`EconomyConfig.lua`** - Economy system settings, item values, and buy/sell configuration
- **`ChunkConfig.lua`** - World generation parameters
- **`CollectionServiceTags.lua`** - Centralized tag management for drag/drop and inventory systems

## ⚙️ Setup Instructions

### Setting Up Buy/Sell Zones

1. **Create Buy Zones:**
   - Place any Part or MeshPart in workspace
   - Add `BUY_ZONE` tag using CollectionService
   - Items will automatically spawn 1 stud above the part
   - Multiple parts can use the same tag (each gets its own item)

2. **Create Sell Zones:**
   - Place any Part or MeshPart in workspace  
   - Add `SELL_ZONE` tag using CollectionService
   - Drag sellable items (tagged with `SELLABLE_LOW`, `SELLABLE_MID`, `SELLABLE_HIGH`) into the zone
   - Cash will spawn where the item was sold

3. **Tag Items for Trading:**
   - `SELLABLE_LOW` - 15 coins (scrap, basic materials)
   - `SELLABLE_MID` - 25 coins (refined materials, tools)
   - `SELLABLE_HIGH` - 50 coins (rare materials, gems)
   - Items in `ReplicatedStorage.Items` are automatically tagged when placed in buy zones

### UI Setup

The backpack system now uses manually created UI in Studio:
- Create `StarterGui > BackpackGui` (ScreenGui)
- Add `BackpackFrame > Counter` (TextLabel) for item count display
- Mobile buttons (`MobileButtons > StoreButton/RetrieveButton`) auto-appear on touch devices

## 🚀 Recent Improvements

### Economy & Trading System
- **Complete Economy Implementation**: Buy/sell zones with proximity prompts and cash collection
- **Session-Based Money**: Roguelike economy that resets each game join
- **Smart Item Purchasing**: ProximityPrompts on items with affordability feedback
- **Cash Collection System**: Physical cash spawning with object pooling for performance
- **Visual Feedback**: Green/red highlighting shows item affordability before purchase

### Inventory System Overhaul
- **LIFO Sack System**: 10-slot Last-In-First-Out inventory with visual counter
- **Object Pooling**: Items moved to ServerStorage instead of destroyed for performance
- **Mobile Support**: Automatic touch controls for store/retrieve actions
- **Manual UI Integration**: Moved from script-created to Studio-designed UI elements
- **Cross-Platform**: Keyboard (E/F keys) and mobile (touch buttons) support

### Performance & Architecture
- **Creature Pooling System**: Eliminates frame drops by reusing creature models instead of destroying them
- **Reduced Instance Creation**: Economy and backpack systems minimize `Instance.new()` usage
- **Tag-Based Architecture**: Centralized CollectionService tag management
- **AI Performance**: LOD system with fair budget allocation prevents creatures from getting stuck
- **Player Position Caching**: Eliminates expensive character lookups during distance calculations

---

**Built with Rojo** • **Procedural Generation** • **AI Systems** • **Roblox**