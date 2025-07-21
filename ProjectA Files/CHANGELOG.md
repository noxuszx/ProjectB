# Changelog

All notable changes to the Mob Spawner System will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [v1.2.0] - 2025-01-16

### ✨ Major Features
- **CollectionService Integration**: Replaced name-based spawner discovery with CollectionService tagging for better performance and flexibility
- **Zone-Based Spawning**: Added intelligent spawn behavior based on part collision settings
  - `CanCollide = false`: Spawn inside the part's bounding box (zone mode)
  - `CanCollide = true`: Spawn around the part using SpawnRadius (traditional mode)
- **Modern Task Library**: Updated all `wait()` and `spawn()` calls to use `task.wait()` and `task.spawn()` for better performance

### 🔧 Critical Bug Fixes
- **Fixed ChaserNPC Configuration Bug**: Added missing `MAX_HEALTH` field to all mob configurations, preventing nil value errors
- **Removed Redundant DefaultConfig**: Eliminated duplicate configuration in ChaserNPC.lua, now properly uses SpawnerConfig values

### ⚡ Performance Improvements
- **Efficient Spawner Discovery**: Only listens for tagged parts instead of checking every part added to workspace
- **Better Memory Usage**: Modern task library provides more efficient scheduling and timing
- **Spatial Flexibility**: Parts can now be anywhere in workspace hierarchy, not just direct children

### 🔍 Technical Details
- Uses `CollectionService:GetTagged()` and instance signals for spawner management
- Zone spawning uses `CFrame:PointToWorldSpace()` for proper rotation support
- Mob configurations now include complete health values for all types:
  - BasicChaser: 100 HP, FastChaser: 80 HP, SlowChaser: 60 HP, TankChaser: 200 HP, Zombie: 100 HP

### 📚 Usage Changes
- **Setup Method**: Use CollectionService to tag parts with "MobSpawner" instead of naming them
- **Tagging Options**: Use Studio's Tag Editor plugin or `CollectionService:AddTag(part, "MobSpawner")`
- **Zone Creation**: Set `CanCollide = false` to create spawn zones, `CanCollide = true` for traditional radius spawning

## [v1.1.1] - 2025-01-07

### 🔧 Bug Fixes
- **Fixed Spawn Radius Position Bug**: NPCs now properly spawn at random positions within the configured spawn radius instead of always spawning at the same location
- **Fixed Position Drift Issue**: Added position verification and correction after mob spawning to ensure NPCs appear exactly where intended
- **Improved Spawn Distribution**: Modified spawn distance calculation to use 30-100% of radius instead of 0-100% for better spread

### ✨ Improvements
- **More Reliable Positioning**: Now uses `SetPrimaryPartCFrame()` for more reliable mob positioning
- **Position Verification**: Added double-checking mechanism with physics-disabled repositioning if position drift is detected
- **Cleaner Console Output**: Removed excessive debug prints across all modules while keeping essential system status messages
- **Better Random Generation**: Improved random number generation for spawn positions
- **Streamlined Code**: Cleaned up debug output in MobSpawner, SpawnerController, and SpawnerConfig modules
- **Production Ready**: Optimized console output for deployment environments

### 🔍 Technical Details
- Moved position setting to after parenting to workspace to prevent Roblox from resetting positions
- Added temporary collision disabling when forcing positions to prevent physics interference
- Stored intended position separately to maintain accuracy through the spawning process
- Removed `math.randomseed` calls that could interfere with randomness in rapid succession
- Streamlined debug output for better performance and readability

## [v1.1.0] - 2025-01-07

### 🔧 Bug Fixes
- **Fixed Empty MobType Configuration Bug**: Empty or whitespace-only `MobType` attributes now properly default to "BasicChaser" instead of causing parsing errors
- **Fixed Mob Count Overflow Bug**: Spawners now strictly respect `MaxMobs` limits and won't create excess mobs due to race conditions
- **Fixed Spawn Rate Timing Bug**: Mobs now spawn at proper intervals (respecting `SpawnRate`) instead of spawning all simultaneously at startup
- **Fixed Race Condition in Heartbeat Loop**: Added immediate mob count validation and proper spawn timing to prevent multiple concurrent spawns

### ✨ Improvements  
- **Enhanced Debugging**: Added detailed spawn timing and count tracking messages for easier troubleshooting
- **Better Error Handling**: Improved fallback behavior for failed mob creation scenarios
- **Spawn Timer Protection**: Added safeguards to prevent spawn timer penalties when mob creation fails

### 🔍 Technical Details
- Moved `lastSpawnTime` update to before spawning to prevent race conditions
- Added immediate mob count increment/decrement for proper slot reservation
- Enhanced `parseMobType()` function with whitespace detection using `mobTypeString:match("^%s*$")`
- Implemented proper startup timing to prevent immediate mass spawning

## [v1.0.0] - 2025-01-06

### ✨ Features
- **Random Mob Selection**: Support for `MobType = "RANDOM"` and weighted selections like `"Zombie:3,Knight:1"`
- **Dual AI System**: Managed NPCs with built-in AI or custom-scripted behaviors
- **Flexible Configuration**: 20+ configurable attributes via part attributes
- **Performance Optimization**: Batch processing and spatial optimization for large-scale spawning
- **Auto-Detection**: Automatic spawner detection and setup from part naming
- **Player Proximity**: Smart spawning/despawning based on player distance
- **Custom Mob Support**: Use any character models with Humanoid components

### 🏗️ System Architecture
- `SpawnerController.server.lua`: Main controller with auto-detection
- `MobSpawner.lua`: Individual spawner class with full configuration support  
- `SpawnerConfig.lua`: Centralized configuration and validation
- `NPCManager.lua`: Performance-optimized NPC management
- `ChaserNPC.lua`: Built-in chasing AI for managed NPCs

### 📚 Documentation
- Complete setup guide with examples
- Troubleshooting section
- Performance tips and monitoring
- API documentation for advanced usage

---

## Types of Changes
- 🔧 **Bug Fixes** - for bug fixes
- ✨ **Features** - for new features  
- 🔍 **Technical** - for technical improvements
- 📚 **Documentation** - for documentation changes
- ⚡ **Performance** - for performance improvements
- 🔄 **Changes** - for changes in existing functionality
