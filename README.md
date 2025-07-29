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
- **Performance Optimized** - LOD system handles 100+ creatures smoothly

## 🎯 Gameplay

### Survival
- Hunt rabbits, wolves, and other creatures for food
- Cook raw meat using campfires, stoves, or grills
- Press E near food to consume and restore hunger
- Explore villages for resources and building materials

### Combat
- **Passive**: Rabbits flee when attacked, drop meat
- **Hostile**: Wolves, mummies, skeletons chase players
- **Night creatures**: Some enemies only spawn after dark

### Building
- Drag and drop items with mouse
- Press Z to weld touching objects
- Press R to rotate, X to change rotation axis

## 🏗️ Project Structure

```
src/
├── client/                   # Client-side scripts and UI
│   ├── dragdrop/            # Drag & drop mechanics
│   │   ├── interactableHandler.client.lua
│   │   └── weldSystem.lua
│   ├── food/                # Client-side food consumption
│   │   └── FoodConsumption.client.lua
│   ├── ragdoll/             # Ragdoll effects
│   │   └── RagdollClient.client.lua
│   ├── ui/                  # UI components
│   │   └── CreatureHealthBars.client.lua
│   ├── FlyScript.client.lua
│   ├── init.client.luau
│   └── StatsDisplay.client.lua
├── server/                  # Server-side game logic
│   ├── ai/                  # AI system and creature behaviors
│   │   ├── behaviors/       # AI behavior implementations
│   │   │   ├── AIBehavior.lua
│   │   │   ├── chasing.lua
│   │   │   ├── fleeing.lua
│   │   │   └── roaming.lua
│   │   ├── creatures/       # Creature type definitions
│   │   │   ├── base.lua
│   │   │   ├── hostile.lua
│   │   │   └── passive.lua
│   │   ├── AICreatureRegistry.lua
│   │   ├── AIDebugger.lua
│   │   ├── AIManager.lua
│   │   ├── creatureSpawner.lua
│   │   ├── LODPolicy.lua
│   │   └── spawnerPlacement.lua
│   ├── dragdrop/            # Server-side drag & drop
│   │   ├── collisions.server.lua
│   │   └── interactableHandler.server.lua
│   ├── environment/         # Environmental systems
│   │   ├── dayNightCycle.lua
│   │   └── lighting.lua
│   ├── food/                # Server-side food management
│   │   └── FoodConsumptionServer.server.lua
│   ├── loot/                # Loot drop systems
│   │   └── FoodDropSystem.lua
│   ├── player/              # Player management
│   │   ├── PlayerDeathHandler.server.lua
│   │   └── PlayerStatsManager.lua
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
    │   │   ├── ai.lua
    │   │   ├── creatureSpawning.lua
    │   │   └── spawnerPlacing.lua
    │   ├── ChunkConfig.lua
    │   ├── DragDropConfig.lua
    │   ├── ItemConfig.lua
    │   ├── ModelSpawnerConfig.lua
    │   ├── PlayerStatsConfig.lua
    │   ├── time.lua
    │   └── village.lua
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
- **`base.lua`** - Base creature class with shared behaviors
- **`passive.lua`** - Peaceful creatures (rabbits, deer)
- **`hostile.lua`** - Aggressive creatures (wolves, mummies)
- **`creatureSpawner.lua`** - Handles creature spawning logic

### Behaviors
- **`roaming.lua`** - Random movement patterns for idle creatures
- **`chasing.lua`** - Pursuit behavior for hostile creatures
- **`fleeing.lua`** - Escape behavior for passive creatures

### Client UI
- **`StatsDisplay.client.lua`** - Player hunger/thirst bars
- **`CreatureHealthBars.client.lua`** - Health indicators above creatures
- **`FoodConsumption.client.lua`** - Food interaction system

### Configuration
- **`ai/ai.lua`** - Core AI system settings and performance tuning
- **`PlayerStatsConfig.lua`** - Hunger/thirst mechanics and UI settings
- **`ChunkConfig.lua`** - World generation parameters

## 🚀 Recent Improvements

- **AI Performance**: LOD system with fair budget allocation prevents creatures from getting stuck
- **Timing Consistency**: Unified `os.clock()` timing throughout codebase  
- **Modular Architecture**: Extracted LODPolicy, AICreatureRegistry, and AIDebugger modules
- **Player Position Caching**: Eliminates expensive character lookups during distance calculations
- **Batch Processing**: Efficient creature cleanup and registry management

---

**Built with Rojo** • **Procedural Generation** • **AI Systems** • **Roblox**