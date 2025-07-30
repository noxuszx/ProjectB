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
│   ├── environment/         # Environmental systems
│   │   ├── DayNightCycle.lua
│   │   └── Lighting.lua
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
    │   ├── Time.lua
    │   └── Village.lua
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
- **`FoodConsumption.client.lua`** - Food interaction system

### Configuration
- **`ai/ai.lua`** - Core AI system settings and performance tuning
- **`PlayerStatsConfig.lua`** - Hunger/thirst mechanics and UI settings
- **`ChunkConfig.lua`** - World generation parameters

## 🚀 Recent Improvements

- **Creature Pooling System**: Eliminates frame drops by reusing creature models instead of destroying them
- **Food & Cooking Mechanics**: Tag-based cooking system with raw/cooked meat states and hunger benefits
- **Automatic Respawning**: Population-controlled respawning maintains world creature density
- **Performance Optimization**: Frame drops eliminated through model pooling and optimized initialization
- **AI Performance**: LOD system with fair budget allocation prevents creatures from getting stuck
- **Timing Consistency**: Unified `os.clock()` timing throughout codebase  
- **Modular Architecture**: Extracted LODPolicy, AICreatureRegistry, and AIDebugger modules
- **Player Position Caching**: Eliminates expensive character lookups during distance calculations
- **Batch Processing**: Efficient creature cleanup and registry management

---

**Built with Rojo** • **Procedural Generation** • **AI Systems** • **Roblox**