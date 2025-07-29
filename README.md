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

## 🏗️ Structure

```
src/
├── client/          # UI, interactions, ragdoll
├── server/          
│   ├── ai/          # Creature behaviors and spawning
│   ├── terrain/     # Procedural world generation
│   ├── weapons/     # Combat system
│   └── food/        # Cooking and hunger
└── shared/
    ├── config/      # Game settings
    └── modules/     # Shared utilities
```

## 🚀 Recent Improvements

- **AI Performance**: LOD system with fair budget allocation prevents creatures from getting stuck
- **Timing Consistency**: Unified `os.clock()` timing throughout codebase  
- **Modular Architecture**: Extracted LODPolicy, AICreatureRegistry, and AIDebugger modules
- **Player Position Caching**: Eliminates expensive character lookups during distance calculations
- **Batch Processing**: Efficient creature cleanup and registry management

---

**Built with Rojo** • **Procedural Generation** • **AI Systems** • **Roblox**