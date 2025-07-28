# ProjectB - Procedural Desert Survival World

A comprehensive Roblox survival game featuring procedural terrain generation, intelligent AI creatures, hunting and cooking mechanics, and interactive building systems. Experience dynamic day/night cycles in a vast desert world filled with villages, wildlife, and survival challenges.

## 🎮 Key Features

- **✅ Procedural Terrain Generation** - Infinite desert landscapes with chunk-based optimization
- **✅ Intelligent AI Creatures** - Behavior-driven NPCs with fleeing, hunting, and roaming patterns
- **✅ Dynamic Day/Night Cycle** - 8-minute real-time cycles affecting creature spawning and world atmosphere
- **✅ Hunting & Cooking System** - Kill animals for meat, cook over fires, manage hunger levels
- **✅ Interactive Building** - Drag, drop, weld, and rotate objects to build structures
- **✅ Village Exploration** - Discover procedurally generated settlements with NPCs
- **✅ Weapon Combat System** - Engage creatures with distance-validated combat mechanics
- **✅ Performance Optimized** - LOD system, batch processing, and smart memory management
- **✅ Food & Survival** - Gather resources, cook meals, and survive in the harsh desert

## 📁 File Structure

```
ProjectB/
├── src/
│   ├── client/
│   │   ├── dragdrop/              # Drag-drop and building mechanics
│   │   ├── food/                  # Food consumption with E key interaction
│   │   ├── ragdoll/               # Client-side ragdoll handling
│   │   └── FlyScript.client.lua   # Development flying controls
│   ├── server/
│   │   ├── ai/                    # AI creature system
│   │   │   ├── behaviors/         # AI behavior patterns (roaming, chasing, fleeing)
│   │   │   ├── creatures/         # Creature classes (passive, hostile, base)
│   │   │   ├── AIManager.lua      # Central AI coordination with LOD system
│   │   │   ├── creatureSpawner.lua # Creature spawning and placement
│   │   │   └── spawnerPlacement.lua # Procedural spawner distribution
│   │   ├── dragdrop/              # Server-side object interaction
│   │   ├── environment/           # Day/night cycle and lighting systems
│   │   ├── food/                  # Server-side food consumption and hunger
│   │   ├── loot/                  # Food drop system for hunting
│   │   ├── player/                # Player death and ragdoll handling
│   │   ├── spawning/              # World population systems
│   │   ├── terrain/               # Chunk-based terrain generation
│   │   ├── weapons/               # Combat and damage systems
│   │   └── ChunkInit.server.lua   # World initialization sequence
│   └── shared/
│       ├── config/                # Game configuration files
│       │   ├── ai/                # AI creature settings and spawn rules
│       │   ├── ChunkConfig.lua    # Terrain generation parameters
│       │   ├── DragDropConfig.lua # Building system settings
│       │   ├── ItemConfig.lua     # Loot tables and item spawning
│       │   ├── ModelSpawnerConfig.lua # World decoration settings
│       │   ├── time.lua           # Day/night cycle configuration
│       │   └── village.lua        # Village generation rules
│       ├── modules/               # Shared utility modules
│       │   └── RagdollModule.lua  # Physics-based death system
│       └── utilities/             # Helper functions and tools
├── default.project.json           # Rojo build configuration
└── aftman.toml                   # Development tool dependencies
```

## 🎯 Gameplay Guide

### **Survival Basics**
- **Explore the Desert** - Navigate the procedural world to find resources and villages
- **Hunt for Food** - Use weapons to kill rabbits, wolves, and lizards for meat
- **Cook Your Meals** - Place raw meat near campfires, stoves, or grills to cook it
- **Manage Hunger** - Press E near food to consume it and restore hunger (shown in leaderstats)

### **Combat & Creatures**
- **Passive Creatures** - Rabbits and lizards flee when attacked, drop meat when killed
- **Hostile Creatures** - Wolves, mummies, and skeletons will chase and attack players
- **Night Dangers** - Mummies and skeletons only appear during night hours
- **Safe vs Dangerous Zones** - Green spawners = safe areas, Red spawners = hostile territory

### **Building & Interaction**
- **Drag & Drop** - Click and hold to move items, tools, and building materials
- **Welding System** - Press Z when objects touch to permanently connect them
- **Rotation Controls** - Press R to rotate objects, X to change rotation axis
- **Material Gathering** - Find building supplies in villages and construction sites

### **World Features**
- **Dynamic Time** - Experience realistic day/night transitions affecting gameplay
- **Village Discovery** - Find settlements with NPCs, shops, and resources
- **Procedural Spawning** - Every playthrough offers different creature and item distributions
- **Performance Scaling** - AI creatures use LOD system for smooth gameplay with 100+ NPCs

## 🆕 Recent Updates

### **LOD Performance System**
- ✅ **AI Optimization** - Implemented staggered LOD system for 100+ creatures
- ✅ **Distance-Based Updates** - Close creatures update 30fps, distant ones 2fps
- ✅ **Automatic Culling** - Creatures beyond 200 studs pause to save performance
- ✅ **Multi-Player Support** - LOD uses nearest player distance for fair gameplay

### **Food Drop & Cooking System**
- ✅ **Complete Food System** - Animal hunting with automatic food drops
- ✅ **Cooking Mechanics** - Raw food (pink/red) cooks to brown when touching heat sources
- ✅ **Hunger Management** - E key consumption with leaderstats tracking
- ✅ **Smart Integration** - Food items work with existing drag-drop building system

### **World Generation Improvements**
- ✅ **Model Spawning Fixes** - Vegetation and rocks now spawn across entire world
- ✅ **Collision Detection** - Objects no longer overlap with villages or spawners
- ✅ **Dynamic Creature Heights** - NPCs spawn at proper height based on model size
- ✅ **Performance Optimization** - Removed generation delays for faster world loading

### **Stability & Performance**
- ✅ **Batch Cleanup System** - Eliminated lag spikes from creature destruction
- ✅ **Deferred Destruction** - Uses Debris service for smooth model cleanup
- ✅ **Weapon System Fixes** - Proper PrimaryPart targeting for all creature types
- ✅ **Animation Support** - Server-side animate scripts for consistent NPC animations

---

**Built with Rojo** • **Desert Survival** • **Procedural Generation** • **AI Creatures** • **Roblox**