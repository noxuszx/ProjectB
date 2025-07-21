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
- ✅ **Model Spawning**: Custom vegetation, rocks, and structures
- ✅ **Desert Theme**: Fallout-inspired atmosphere
- ✅ **Performance Optimized**: Batched generation and smooth transitions
- ✅ **Highly Configurable**: Easy customization of all systems
- ✅ **Professional Structure**: Clean, organized, and extensible codebase

## 📁 Project Structure

```
ProjectB/
├── src/
│   ├── client/
│   │   └── init.client.luau         # Client-side initialization
│   ├── server/
│   │   ├── terrain/
│   │   │   └── ChunkManager.lua     # Chunk generation logic
│   │   ├── spawning/
│   │   │   └── CustomModelSpawner.lua # Model spawning system
│   │   ├── environment/
│   │   │   ├── DayNightCycle.lua    # Time management system
│   │   │   └── LightingManager.lua  # Dynamic lighting transitions
│   │   └── ChunkInit.server.lua     # Server initialization
│   └── shared/
│       ├── config/
│       │   ├── ChunkConfig.lua      # Terrain configuration
│       │   ├── ModelSpawnerConfig.lua # Model spawning config
│       │   └── TimeConfig.lua       # Day/night cycle config
│       └── utilities/
│           ├── NoiseGenerator.lua   # Noise generation utilities
│           └── TimeDebugger.lua     # Time debugging tools
├── default.project.json             # Rojo project configuration
├── aftman.toml                      # Tool dependencies
└── README.md                        # This file
```

## ⚙️ Configuration

### **ChunkConfig.lua Parameters**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CHUNK_SIZE` | 32 | Size of each chunk in studs (32x32) |
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
5. **Press Play** to see the terrain generate!

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

### **Model Spawning System**
- **Three Categories**: Vegetation, Rocks, Structures
- **Smart Placement**: Models embed naturally into terrain
- **Distance Control**: Prevents overcrowding with minimum spacing
- **Size Variation**: Random scaling for natural variety
- **Configurable Chances**: Adjustable spawn rates per category
- **Performance Optimized**: Batched generation with delays

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

## 🎨 Customization Examples

### **Larger Terrain Area**
```lua
ChunkConfig.RENDER_DISTANCE = 5  -- 11x11 chunks (352x352 studs)
```

### **Higher Resolution**
```lua
ChunkConfig.SUBDIVISIONS = 8  -- 8x8 parts per chunk (64 parts per chunk)
```

### **Different Terrain Style**
```lua
ChunkConfig.NOISE_SCALE = 0.01  -- Larger, smoother hills
ChunkConfig.HEIGHT_RANGE.MAX = 50  -- Taller mountains
```

### **Desert Theme**
```lua
ChunkConfig.TERRAIN_MATERIAL = Enum.Material.Sand
ChunkConfig.TERRAIN_COLOR = Color3.fromRGB(194, 178, 128)
```

### **Faster Day/Night Cycle**
```lua
TimeConfig.DAY_LENGTH = 120  -- 2 minutes real-time = 24 hours game time
```



## 📈 Performance Metrics

- **Generation Time**: ~2-3 seconds for full 7x7 grid
- **Part Count**: 784 parts (vs 2500+ in old system)
- **Memory Usage**: Significantly reduced vs old system
- **Render Performance**: Smooth 60fps with current settings

## 🔧 Future Enhancements

### **Planned Features**
- [ ] **Enemy Systems**: Time-based spawning and behavior
- [ ] **Weather System**: Sandstorms, clear skies, temperature effects
- [ ] **Dynamic Events**: Time-triggered world events
- [ ] **Player Survival**: Temperature, visibility, and resource mechanics
- [ ] **Dynamic Chunk Loading**: Load/unload based on player position
- [ ] **Biome System**: Different terrain types and themes
- [ ] **Structure Generation**: Large buildings, settlements, ruins
- [ ] **Terrain Modification**: Tools for real-time terrain editing
- [ ] **Multiplayer Synchronization**: Shared world state
- [ ] **Infinite Worlds**: Terrain streaming for unlimited exploration

### **Performance Optimizations**
- [ ] Level-of-detail (LOD) system
- [ ] Occlusion culling
- [ ] Chunk caching system
- [ ] Background generation threading

## 🤝 Contributing

This is a learning project exploring procedural generation in Roblox. Feel free to:
- Experiment with different noise functions
- Try different chunk sizes and configurations
- Add new terrain features
- Optimize performance further

## 📝 Notes

- The system is designed for educational purposes and experimentation
- Current implementation focuses on clarity over maximum performance
- Terrain is static after generation (no dynamic modification yet)
- Uses Roblox's built-in math functions for noise generation

## 🏷️ Tags

`roblox` `procedural-generation` `terrain` `chunks` `noise` `day-night-cycle` `model-spawning` `desert` `fallout` `rojo` `lua`

---

**Last Updated**: July 11, 2025
**Rojo Version**: 7.5.1  
**Roblox Studio**: Compatible with current version
