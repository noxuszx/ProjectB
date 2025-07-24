# AI System Comprehensive Plan

## Overview
A performant, industry-standard AI system for ProjectB featuring two creature types: **Passive Creatures** (roam and flee when hurt) and **Hostile Creatures** (chase players when near). Built for handling hundreds of creatures simultaneously using OOP architecture and performance optimizations.

## System Architecture

### Core Principles
- **Performance-First Design**: Built for handling 200-500 creatures simultaneously
- **Object-Oriented Architecture**: Clean class hierarchy with inheritance and composition
- **Modular State Machine**: Behavior-driven design using Strategy pattern
- **LOD (Level of Detail) System**: Distance-based performance scaling
- **Integration-Friendly**: Follows existing project patterns (ChunkInit, CollectionService, etc.)

## Class Hierarchy

### Base Classes
```
BaseCreature (Abstract)
├── PassiveCreature
└── HostileCreature

AIBehavior (Abstract)
├── IdleBehavior
├── RoamingBehavior  
├── ChasingBehavior
└── FleeingBehavior

AIManager (Singleton)
CreatureSpawner
PerformanceMonitor
SpatialGrid
```

### BaseCreature (Abstract Base Class)
**Properties:**
- `model`: Model - The actual Roblox model from ReplicatedStorage
- `health`: number - Current health points
- `position`: Vector3 - Current world position
- `currentBehavior`: AIBehavior - Active behavior state
- `detectionRange`: number - Range for detecting players/threats
- `moveSpeed`: number - Movement speed in studs/second
- `isActive`: boolean - Whether creature is actively updating

**Methods:**
- `new(model, config)` - Constructor
- `update(deltaTime)` - Main update loop
- `takeDamage(amount)` - Handle damage received
- `setBehavior(behavior)` - Change current behavior
- `destroy()` - Cleanup and remove creature
- `getDistanceToPlayer()` - Calculate distance to nearest player

### PassiveCreature : BaseCreature
**Additional Properties:**
- `fleeTimer`: number - Time remaining in flee state
- `originalPosition`: Vector3 - Home position for returning
- `isFleeingFromDamage`: boolean - Whether currently fleeing from damage

**Behavior Flow:**
`Idle → Roaming → Fleeing (when hurt) → Returning → Idle`

### HostileCreature : BaseCreature
**Additional Properties:**
- `attackRange`: number - Range for attacking players
- `attackCooldown`: number - Time between attacks
- `lastAttackTime`: number - Timestamp of last attack
- `targetPlayer`: Player - Current target player

**Behavior Flow:**
`Idle → Roaming → Chasing (when player detected) → Attacking → Returning → Idle`

## Behavior System (Strategy Pattern)

### AIBehavior (Abstract)
**Methods:**
- `enter(creature)` - Called when behavior starts
- `update(creature, deltaTime)` - Called each frame
- `exit(creature)` - Called when behavior ends
- `canTransition(creature, newBehavior)` - Validation for state changes

### Concrete Behaviors

#### IdleBehavior
- Creature stands still, occasionally looks around
- Transitions to Roaming after random interval (5-15 seconds)

#### RoamingBehavior
- Creature wanders in area using waypoints
- Stays within designated area around spawn point
- Transitions to Chasing/Fleeing based on creature type and stimuli

#### ChasingBehavior (Hostile only)
- Pursues target player using pathfinding
- Transitions to Attacking when in range
- Gives up chase if player escapes detection range

#### FleeingBehavior (Passive only)
- Runs away from threat in opposite direction
- Transitions back to Roaming when timer expires
- Avoids obstacles while fleeing

## Manager Classes

### AIManager (Singleton)
**Properties:**
- `activeCreatures`: {BaseCreature} - Registry of all active creatures
- `spatialGrid`: SpatialGrid - Spatial partitioning for efficient queries
- `updateScheduler`: UpdateScheduler - Manages update frequencies
- `performanceMonitor`: PerformanceMonitor - Tracks system performance

**Methods:**
- `getInstance()` - Singleton access
- `registerCreature(creature)` - Add creature to system
- `unregisterCreature(creature)` - Remove creature from system
- `updateAllCreatures(deltaTime)` - Main update loop
- `getCreaturesInRange(position, range)` - Spatial queries

### CreatureSpawner
**Methods:**
- `spawnCreature(creatureType, position, config)` - Spawn single creature
- `spawnInChunk(chunkX, chunkZ)` - Spawn creatures in chunk area
- `populateWorld()` - Initial world population
- `despawnCreature(creature)` - Remove creature from world
- `getCreatureTemplate(creatureType)` - Get model from ReplicatedStorage

## Performance Optimizations

### Distance-Based LOD System
- **Close (0-50 studs)**: Full AI updates (30 FPS)
- **Medium (50-100 studs)**: Reduced updates (10 FPS)  
- **Far (100+ studs)**: Minimal updates (2 FPS)
- **Very Far (200+ studs)**: Paused/Culled

### Spatial Partitioning
- Grid-based creature tracking for efficient neighbor queries
- O(1) lookups for creatures in range
- Reduces collision detection overhead

### Batch Processing
- Update multiple creatures per frame efficiently
- Spread updates across multiple frames to maintain 60 FPS
- Priority system for important creatures (near players)

### Memory Management
- Object pooling for creature instances
- Reuse behavior objects to reduce garbage collection
- Efficient data structures for large creature counts

## Model Storage Structure

```
ReplicatedStorage/
├── Models/
│   ├── Creatures/
│   │   ├── PassiveCreatures/
│   │   │   ├── Rabbit.rbxm
│   │   │   ├── Deer.rbxm
│   │   │   ├── Bird.rbxm
│   │   │   └── Sheep.rbxm
│   │   └── HostileCreatures/
│   │       ├── Wolf.rbxm
│   │       ├── Bear.rbxm
│   │       ├── Goblin.rbxm
│   │       └── Orc.rbxm
```

## Configuration System

### AIConfig.lua
```lua
AIConfig = {
    Settings = {
        MaxCreatures = 300,
        UpdateBudgetMs = 5,
        DebugMode = false,
        SpatialGridSize = 50
    },
    
    CreatureTypes = {
        Rabbit = {
            Type = "Passive",
            Health = 25,
            MoveSpeed = 16,
            DetectionRange = 20,
            FleeSpeed = 24,
            FleeDuration = 10
        },
        Wolf = {
            Type = "Hostile", 
            Health = 100,
            MoveSpeed = 18,
            DetectionRange = 40,
            AttackRange = 5,
            AttackDamage = 20,
            AttackCooldown = 2
        }
    },
    
    SpawnSettings = {
        CreaturesPerChunk = {2, 5},
        SpawnChance = 0.7,
        MinDistanceFromPlayer = 30,
        RespawnDelay = 300
    }
}
```

## Integration Points

### ChunkInit Integration
```lua
-- In ChunkInit.server.lua (after existing systems)
local AIManager = require(script.Parent.ai.AIManager)
local CreatureSpawner = require(script.Parent.ai.CreatureSpawner)

-- Initialize AI system
AIManager.getInstance():init()
print("AI system initialized")

-- Populate world with creatures
CreatureSpawner.populateWorld()
print("Creatures spawned")
```

### CollectionService Tags
- Creatures tagged as "AICreature" for identification
- Spawn points tagged as "CreatureSpawner" 
- Integration with existing drag-drop system (creatures non-draggable)

### Spawn Point System
```lua
-- Spawn points with attributes (similar to ItemSpawner)
spawnPoint:SetAttribute("CreatureType", "Rabbit")
spawnPoint:SetAttribute("SpawnChance", 0.7)
spawnPoint:SetAttribute("MaxCreatures", 3)
spawnPoint:SetAttribute("SpawnRadius", 10)
```

## Technical Specifications

### Performance Targets
- **Update Frequency**: Variable based on distance (2-30 FPS)
- **Max Creatures**: 200-500 depending on hardware
- **Memory Usage**: ~1KB per creature (pooled instances)
- **CPU Budget**: <5ms per frame for all AI processing
- **Frame Rate Impact**: <5% reduction at max creature count

### Creature Specifications

#### Passive Creatures
- **Behavior**: Wander → Flee when hurt → Return to area
- **Detection Range**: 20-30 studs for players/threats
- **Flee Duration**: 10-15 seconds
- **Move Speed**: 12-16 studs/second
- **Flee Speed**: 20-24 studs/second (faster when scared)

#### Hostile Creatures  
- **Behavior**: Patrol → Chase player → Attack → Return
- **Detection Range**: 30-50 studs for players
- **Attack Range**: 3-8 studs
- **Chase Duration**: Until player escapes or creature dies
- **Move Speed**: 14-18 studs/second
- **Attack Cooldown**: 1-3 seconds

## Implementation Phases

1. **Configuration System** - Create config files and creature definitions
2. **Core AI Manager** - Build central management system
3. **Behavior State Machine** - Implement behavior system
4. **Passive Creature AI** - Create passive creature behaviors
5. **Hostile Creature AI** - Create hostile creature behaviors  
6. **Spawning System** - Build creature spawning system
7. **Performance Optimizations** - Add LOD and optimization systems
8. **System Integration** - Integrate with existing ChunkInit system
9. **Debugging Tools** - Create visualization and debugging tools

## Benefits

✅ **Scalability**: Handles hundreds of creatures efficiently  
✅ **Maintainability**: Clean, modular OOP design  
✅ **Performance**: Multiple optimization layers  
✅ **Flexibility**: Easy to add new creature types and behaviors  
✅ **Integration**: Seamless integration with existing systems  
✅ **Industry Standard**: Follows established game AI patterns
