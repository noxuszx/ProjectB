# ProjectB - Procedural Desert World

A Roblox game featuring a chunk-based procedural terrain generation system with dynamic day/night cycle and custom model spawning, built with Rojo for modern development workflow.

## 🎮 Project Overview

This project implements a Minecraft-inspired chunk-based terrain generation system for Roblox with a **Fallout-inspired desert theme**. The terrain is generated procedurally using noise functions to create natural-looking desert landscapes, enhanced with a dynamic day/night cycle and custom model spawning system.

## 🔧 System Architecture

### **Chunk-Based Generation**
- **32x32 stud chunks** organized in a grid system
- **4x4 subdivisions** per chunk (16 terrain parts per chunk)
- **7x7 chunk grid** around spawn point (224x224 stud area)
- **No overlapping parts** - clean, organized terrain structure

### **Key Features**
- ✅ **Procedural Terrain**: Noise-based height generation
- ✅ **Chunk System**: Minecraft-inspired organization
- ✅ **Day/Night Cycle**: Dynamic lighting with 8 time periods
- ✅ **Item Spawning**: Session-based loot system with MeshParts & Tools
- ✅ **Model Spawning**: Custom vegetation, rocks, and structures
- ✅ **Village Generation**: Procedural villages with random layouts
- ✅ **AI Creature System**: Intelligent NPCs with behavior-driven AI
- ✅ **Procedural Spawner Placement**: Noise-based creature distribution
- ✅ **Drag & Drop System**: Interactive object manipulation with welding
- ✅ **Desert Theme**: Egypt Theme
- ✅ **Performance Optimized**: Batched generation and smooth transitions
- ✅ **Highly Configurable**: Easy customization of all systems

## 📁 Project Structure

```
ProjectB/
├── src/
│   ├── client/
│   │   ├── dragdrop/
│   │   │   ├── interactableHandler.client.lua  # Main drag-drop and rotation logic
│   │   │   └── weldSystem.lua                  # Touch-based welding system
│   │   ├── FlyScript.client.lua                # Flying controls (G to toggle)
│   │   └── init.client.luau                    # Client-side initialization
│   ├── server/
│   │   ├── dragdrop/
│   │   │   ├── interactableHandler.server.lua  # Network ownership management
│   │   │   └── itemSetup.server.lua            # Legacy item setup (unused)
│   │   ├── terrain/
│   │   │   └── ChunkManager.lua      # Chunk generation logic
│   │   ├── spawning/
│   │   │   ├── ItemSpawner.lua        # Session-based item spawning
│   │   │   ├── CustomModelSpawner.lua # Model spawning system
│   │   │   └── VillageSpawner.lua     # Village generation system
│   │   ├── ai/
│   │   │   ├── creatures/
│   │   │   │   ├── BaseCreature.lua      # Base creature class
│   │   │   │   ├── PassiveCreature.lua   # Passive creature AI
│   │   │   │   └── HostileCreature.lua   # Hostile creature AI
│   │   │   ├── behaviors/
│   │   │   │   ├── AIBehavior.lua        # Base behavior class
│   │   │   │   ├── RoamingBehavior.lua   # Roaming behavior
│   │   │   │   ├── ChasingBehavior.lua   # Chasing behavior
│   │   │   │   └── FleeingBehavior.lua   # Fleeing behavior
│   │   │   ├── AIManager.lua             # Central AI coordination
│   │   │   ├── CreatureSpawner.lua       # Creature spawning system
│   │   │   └── SpawnerPlacement.lua      # Procedural spawner placement
│   │   ├── environment/
│   │   │   ├── DayNightCycle.lua     # Time management system
│   │   │   └── LightingManager.lua   # Dynamic lighting transitions
│   │   └── ChunkInit.server.lua      # Server initialization
│   └── shared/
│       ├── config/
│       │   ├── ChunkConfig.lua       # Terrain configuration
│       │   ├── ItemConfig.lua        # Item spawning loot tables
│       │   ├── DragDropConfig.lua    # Drag and drop settings
│       │   ├── ModelSpawnerConfig.lua # Model spawning config
│       │   ├── VillageConfig.lua     # Village spawning config
│       │   ├── TimeConfig.lua        # Day/night cycle config
│       │   ├── AIConfig.lua          # AI creature configuration
│       │   ├── CreatureSpawnConfig.lua # Creature spawn types
│       │   └── SpawnerPlacementConfig.lua # Procedural spawner settings
│       └── utilities/
│           ├── NoiseGenerator.lua       # Noise generation utilities
│           ├── TimeDebugger.lua         # Time debugging tools
│           └── CollectionServiceTags.lua # Drag-drop object tagging system
├── Items/                           # Item models folder
│   └── README.md                    # Item requirements and guide
├── NPCs/                            # Creature models folder (ReplicatedStorage)
│   ├── PassiveCreatures/            # Passive creature models (Rabbit, Deer, etc.)
│   └── HostileCreatures/            # Hostile creature models (Wolf, Bear, etc.)
├── default.project.json             # Rojo project configuration
├── aftman.toml                      # Tool dependencies
└── README.md                        # This file
```

## ⚙️ Configuration

### **ChunkConfig.lua Parameters**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CHUNK_SIZE` | 264 | Size of each chunk in studs |
| `RENDER_DISTANCE` | 3 | Chunks to render in each direction |
| `SUBDIVISIONS` | 4 | Parts per chunk axis (4x4 = 16 parts) |
| `HEIGHT_RANGE` | 0-25 | Min/max terrain height in studs |
| `NOISE_SCALE` | 0.03 | Terrain detail level (smaller = more detailed) |
| `NOISE_OCTAVES` | 4 | Number of noise layers for complexity |
| `TERRAIN_MATERIAL` | Grass | Material for terrain parts |
| `TERRAIN_COLOR` | Olive Green | Color of terrain parts |

### **TimeConfig.lua Parameters**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DAY_LENGTH` | 480 | Total day length in seconds (8 minutes) |
| `START_TIME` | 6 | Starting time in game hours (6 AM) |
| `TRANSITION_DURATION` | 1.5 | Lighting transition time in seconds |
| `UPDATE_INTERVAL` | 2 | Update frequency in seconds |

### **Performance Settings**
- **Total chunks**: 49 (7x7 grid)
- **Total parts**: ~784 (16 parts per chunk)
- **Generation area**: 224x224 studs
- **Generation delay**: 0.05 seconds between chunks
- **Day/Night cycle**: 8 minutes real-time = 24 hours game time
- **Lighting updates**: Every 2 seconds with smooth transitions

## 🚀 Getting Started

### **Prerequisites**
- [Rojo](https://rojo.space/) (7.5.1 or later)
- Roblox Studio
- [Aftman](https://github.com/LPGhatguy/aftman) (optional, for tool management)

### **Setup**
1. **Clone or download** this project
2. **Install Rojo** if not already installed
3. **Build the project**:
   ```bash
   rojo build -o ProjectB.rbxlx
   ```
4. **Open `ProjectB.rbxlx`** in Roblox Studio
5. **Add creature models** to the NPCs folders (see Creature Setup below)
6. **Press Play** to see the terrain generate with creatures!

### **Creature Setup**
To add creatures to your world:
1. **Create or import creature models** in Roblox Studio
2. **Set PrimaryPart** for each model (usually the main body part)
3. **Place models** in the appropriate ReplicatedStorage folders:
   - `ReplicatedStorage/NPCs/PassiveCreatures/` - Rabbit, Lizard (day/night spawning)
   - `ReplicatedStorage/NPCs/HostileCreatures/` - Wolf, Mummy, Skeleton (night-only: Mummy, Skeleton)
4. **Name models** to match creature types in `CreatureSpawnConfig.lua`
5. **Restart the game** to see creatures spawn:
   - **Green spawners** (Safe areas): Only passive creatures (Rabbit, Lizard)
   - **Red spawners** (Dangerous areas): Only hostile creatures (Wolf always, Mummy/Skeleton at night)

### **Development Workflow**
1. **Edit Lua files** in your preferred editor
2. **Rebuild** with `rojo build -o ProjectB.rbxlx`
3. **Reload** the place file in Studio
4. **Test** your changes

## 🎯 How It Works

### **Terrain Generation Process**
1. **Chunk Grid**: System calculates 7x7 grid of chunks around spawn
2. **Noise Sampling**: Each chunk subdivision samples noise for height
3. **Part Creation**: Creates terrain parts with calculated heights
4. **Organization**: Parts are organized in "Chunks" folder in Workspace

### **Noise Generation**
- **Fractal Noise**: Multiple octaves of noise for natural terrain
- **Smooth Interpolation**: Bilinear interpolation for smooth height transitions
- **Configurable Parameters**: Scale, octaves, and persistence for different terrain types

### **Chunk System Benefits**
- **Reduced Part Count**: ~784 parts vs thousands in old system
- **No Overlap**: Perfect alignment between chunks
- **Organized Structure**: Easy to manage and extend
- **Performance**: Efficient generation and rendering

### **Day/Night Cycle System**
- **8 Time Periods**: Night, Dawn, Sunrise, Morning, Noon, Afternoon, Sunset, Dusk
- **8-Minute Cycles**: Real-time minutes = 24 hours game time
- **Realistic Sun/Moon**: ClockTime controls natural sun and moon movement
- **Dynamic Lighting**: Smooth transitions between desert-themed color palettes
- **Event System**: Time-based callbacks for other systems
- **Debug Tools**: Console commands for testing and development

### **Item Spawning System**
- **Session-Based**: One-time world population for scavenging gameplay
- **MeshPart & Tool Support**: Performance-optimized item types only
- **4 Spawner Types**: VillageCommon, DungeonChest, BuildingResource, ConstructionSite
- **Probabilistic Loot Tables**: Weighted chance system with empty spawners
- **Smart Positioning**: Scatter placement with collision avoidance
- **Auto-Discovery**: Automatically detects items from ReplicatedStorage.Items
- **Ground Detection**: Raycast positioning for natural item placement
- **Current Items**: MetalRoof, WoodPlank1, WoodPlank2 (building materials)

### **Model Spawning System**
- **Three Categories**: Vegetation, Rocks, Structures
- **Smart Placement**: Models embed naturally into terrain
- **Distance Control**: Prevents overcrowding with minimum spacing
- **Size Variation**: Random scaling for natural variety
- **Configurable Chances**: Adjustable spawn rates per category
- **Performance Optimized**: Batched generation with delays

### **Village Generation System**
- **Procedural Villages**: 1-3 villages spawn randomly per session
- **Dynamic Composition**: 2-4 structures per village (houses, shops)
- **Random Rotations**: Natural-looking placement with varied orientations
- **Smart Positioning**: Structures cluster together with proper spacing
- **Obstacle Avoidance**: Villages avoid large rocks and terrain features

### **AI Creature System**
- **Intelligent NPCs**: Behavior-driven AI with state machines and advanced pathfinding
- **Two Creature Types**: Passive (flee when hurt) and Hostile (chase players)
- **Touch-Based Combat**: Hostile creatures deal damage on contact
- **Time-Based Spawning**: Night-only creatures (Mummies, Skeletons) for dynamic gameplay
- **Procedural Spawning**: Noise-based placement creates natural Safe vs Dangerous zones
- **Pure Zone System**: Safe areas = only passive creatures, Dangerous areas = only hostile creatures
- **Collision System**: Creatures use separate collision group, can't be dragged or welded
- **Performance Optimized**: Handles hundreds of creatures with robust error handling
- **Configurable Behaviors**: Easy to customize creature stats, spawn rates, and AI parameters

### **Creature Spawning Mechanics**
- **Safe Zones (Green Spawners)**: 75% of world areas, spawn 2-4 passive creatures each
  - **Day & Night**: Rabbits (80% chance), Lizards (90% chance)
  - **Peaceful exploration** with wildlife observation opportunities
- **Dangerous Zones (Red Spawners)**: 25% of world areas, spawn 3-5 hostile creatures each
  - **Day**: Wolves (70% chance) - moderate danger
  - **Night**: Wolves (70%) + Mummies (50%) + Skeletons (60%) - high danger
  - **Risk/reward gameplay** - dangerous but potentially rewarding areas
- **Dynamic Difficulty**: World becomes significantly more dangerous at night
- **Spawner Visibility**: Colored debug parts show spawner locations (can be toggled off)

## 📈 Performance Metrics

- **Generation Time**: ~2-3 seconds for full 7x7 grid
- **Part Count**: 784 parts (vs 2500+ in old system)
- **Memory Usage**: Significantly reduced vs old system
- **Render Performance**: Smooth 60fps with current settings

## 📝 Notes

- The system is designed for educational purposes and experimentation
- Current implementation focuses on clarity over maximum performance
- Terrain is static after generation (no dynamic modification yet)
- Uses Roblox's built-in math functions for noise generation

## 🔧 Troubleshooting

### **No Creatures Spawning**
- Ensure creature models are in correct ReplicatedStorage folders
- Check that models have PrimaryPart set
- Verify model names match those in `CreatureSpawnConfig.lua`
- Enable debug mode in `SpawnerPlacementConfig.lua` to see spawner placement

### **AI System Crashes**
- Recent updates include robust error handling for missing creature models
- Check console for "[AIBehavior]" warning messages about invalid creatures
- Ensure all creature models have proper PrimaryPart configuration

### **No Green Spawners**
- Check hostility threshold in `SpawnerPlacementConfig.lua` (should be > 0.75)
- Enable debug mode to see spawner type distribution
- Verify noise-based spawning is enabled in config

## 🏷️ Tags

`roblox` `procedural-generation` `terrain` `chunks` `noise` `day-night-cycle` `item-spawning` `meshparts` `tools` `model-spawning` `desert` `fallout` `rojo` `lua`

---

**Last Updated**: July 28, 2025
**Rojo Version**: 7.5.1
**Roblox Studio**: Compatible with current version

## 🆕 Recent Updates

### **July 28, 2025 - Fleeing Behavior Improvements**
- ✅ **Fixed Villager Fleeing**: Resolved erratic wiggling movement when fleeing from threats
- ✅ **Enhanced Damage System**: PassiveCreature takeDamage now properly passes threat source to fleeing behavior
- ✅ **Weapon Integration**: Updated weapon system to correctly identify player as threat source
- ✅ **Smooth Movement**: Villagers now flee smoothly and naturally from players when attacked

### **July 25, 2025 - AI Creature System Enhancements**
- ✅ **Time-Based Spawning**: Mummies and Skeletons now only spawn at night/dusk
- ✅ **Pure Zone System**: Eliminated mixed spawning - Safe areas are truly safe, Dangerous areas are purely hostile
- ✅ **Improved Spawner Placement**: Fixed raycast issues, spawners now place much closer to player spawn
- ✅ **Better Balance**: 75% Safe zones vs 25% Dangerous zones for optimal gameplay
- ✅ **Robust Error Handling**: AI system now handles creature model issues gracefully without crashes
- ✅ **Collision System**: Creatures use separate collision group, can't be dragged or welded like items
- ✅ **Higher Spawn Rates**: Increased creature density for more lively desert world
- ✅ **Debug Improvements**: Better console output and spawner visualization for development

## 🔄 Evolution History

### **Version 1: Part-Based System**
- Individual parts for each terrain position
- High part count (~2500+ parts)
- Overlapping issues
- Performance concerns

### **Version 2: Chunk-Based System** (Current)
- Minecraft-inspired chunk organization
- Reduced part count (~784 parts)
- Clean, non-overlapping terrain
- Better performance and organization

### **Drag & Drop System**
- **Interactive Objects**: Click and drag spawned items and draggable objects
- **Auto-Integration**: All items spawned by ItemSpawner are automatically draggable
- **Object Support**: MeshParts, Tools, and Models with proper physics handling
- **Smart Detection**: Uses CollectionService tags for efficient object identification
- **Network Optimization**: Delayed network ownership transfer reduces lag
- **Collision Management**: Items become non-collidable with players during drag

### **Welding System**
- **Touch-Based Welding**: Objects must physically touch to be weldable
- **Smart Assembly Detection**: Uses Roblox's built-in Assembly system for anchored part detection
- **Terrain Integration**: Items can weld to terrain but become immovable (prevents terrain dragging)
- **Chain Welding**: Complex welded structures move as single assemblies
- **Automatic Validation**: Prevents welding to players and problematic parts
- **Performance Optimized**: Engine-level assembly checks instead of manual traversal

### **Orientation System**
- **Precise Rotation**: 15° increments around X, Y, or Z axes
- **Axis Switching**: Cycle between rotation axes during drag
- **Position Stability**: Objects stay in place while rotating (no drift)
- **Smooth Animation**: Lerped rotation for fluid visual feedback
- **State Management**: Rotation resets when dropping and picking up objects

### **Control Scheme**
- **Left Click + Hold**: Drag objects
- **Z Key**: Weld/unweld objects (only when touching)
- **R Key**: Rotate object 15° around current axis
- **X Key**: Switch rotation axis (X → Y → Z → X)
- **Release Click**: Drop objects (maintains rotation and welds)
