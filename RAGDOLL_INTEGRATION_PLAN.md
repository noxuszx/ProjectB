# Ragdoll Integration Plan

## Overview
Integrate ragdoll physics for humanoid creatures and players while maintaining simple death mechanics for animals. Implement a comprehensive food drop system for animals that integrates with the existing drag-drop mechanics.

## Creature Death System Design

### Simple Creatures (Destroy + Loot Drop)
- **Rabbit, Wolf, Lizard**
- On death: Destroy rig immediately + drop animal-specific food models
- No ragdoll physics needed
- Quick cleanup, good performance
- Provides hunting/loot incentive for players

#### Food Drop System
- **Separate System**: Independent from ItemSpawner (industry standard)
- **Animal-Specific Foods**: Different food models per creature type
- **Cooking Mechanics**: 
  - Raw state: Pink/red colored part (lower hunger restoration)
  - Cooked state: Brown colored part (higher hunger restoration)
  - Cooking trigger: Food touches specific cooking surface models
- **Integration**: Food models tagged as draggable/weldable for existing systems
- **Consumption**: E key interaction for hunger restoration

### Humanoid Creatures + Players (Ragdoll Physics)
- **Villager1, Villager2, Mummy, Skeleton, Players**
- On death: Convert to permanent ragdoll
- More dramatic/realistic death for human-like entities
- Bodies remain in world as physics objects
- **No food drops** (maintains realism - they're humanoid, not animals)

## Technical Implementation

### Current Ragdoll System Status
- **Location**: `/Ragdoll/` folder in project root
- **Files**: `RagdollModule.lua`, `RagdollClient.client.lua`
- **RemoteEvent**: Already created in Roblox Studio environment
- **System**: Motor6D → BallSocketConstraint conversion with special Root/Neck handling

### Integration Tasks

#### 1. Create Food Drop System
- **New Module**: `src/server/loot/FoodDropSystem.lua`
- Animal-specific food model creation and spawning
- Cooking state management (color changes, hunger values)
- Integration with existing CollectionServiceTags for drag-drop compatibility
- Consumption mechanics via E key interaction

#### 2. Modify RagdollModule
- Add permanent NPC death ragdoll function (no restoration timer)
- Ensure compatibility with existing AI creature models
- Handle edge cases for missing joints/parts

#### 3. Hook into AI Death Events
- Add death event handling to humanoid creature classes
- Add death event handling to simple creature classes (for food drops)
- Call appropriate death function based on creature type
- Prevent default Roblox character cleanup for ragdolled creatures

#### 4. Player Death Handling
- Integrate player death ragdoll system
- Ensure proper camera handling during ragdoll state
- Handle respawn mechanics with ragdoll cleanup

## Current AI System Context

### Creature Types (from CreatureSpawnConfig.lua)
```lua
SpawnTypes = {
    Safe = {
        PossibleCreatures = {
            Rabbit = 0.8,  -- Simple death (destroy + RabbitMeat drop)
        }
    },
    Dangerous = {
        PossibleCreatures = {
            Wolf = 0.7,     -- Simple death (destroy + WolfMeat drop)
            Mummy = 0.5,    -- Ragdoll death (no drops)
            Skeleton = 0.6, -- Ragdoll death (no drops)
        }
    },
    Village = {
        PossibleCreatures = {
            Villager1 = 0.5, -- Ragdoll death (no drops)
            Villager2 = 0.5, -- Ragdoll death (no drops)
        }
    },
}
```

### Food System Integration
- **Drag-Drop Compatibility**: Food models use existing CollectionServiceTags system
- **Physics Integration**: Food models work with current welding/interaction systems
- **Cooking Surfaces**: Campfires, stoves, etc. trigger cooking state changes
- **Hunger System**: Raw vs cooked food provides different restoration values

### Known Issues to Address
- Current creatures disappear due to Roblox's default character cleanup
- No `Humanoid.Died` event handling in AI system
- Parts being removed automatically after death (see console logs)
- Need cooking surface detection system for food state changes

## Benefits of This Approach
1. **Performance**: Simple creatures clean up quickly, food drops are lightweight
2. **Immersion**: Humanoid deaths are more realistic, cooking mechanics add depth
3. **Gameplay**: Loot drops encourage hunting, cooking provides progression
4. **Visual Impact**: Ragdolled bodies add atmosphere, food models are interactive
5. **Distinction**: Clear difference between creature types and their rewards
6. **Industry Standard**: Separate loot system follows best practices

## System Architecture
```
Death Event → Creature Type Check
├── Simple Creature → Destroy + FoodDropSystem.dropFood()
└── Humanoid Creature → RagdollModule.PermanentNpcRagdoll()

Food Model → Tagged as Draggable/Weldable
├── Raw State → Pink/Red color, lower hunger value
├── Cooking Surface Touch → Color change to brown, higher hunger value
└── E Key Interaction → Consume for hunger restoration
```

## Implementation Status

### ✅ Completed - Ragdoll System
1. **✅ Created permanent ragdoll function for NPCs** - `RagdollModule.PermanentNpcRagdoll()`
2. **✅ Added death event handling to all creature classes** - BaseCreature now handles Humanoid.Died events
3. **✅ Set up player death ragdoll system** - PlayerDeathHandler.server.lua with client-side camera handling
4. **✅ Integrated ragdoll system with AI creature death events** - Smart creature type differentiation
5. **✅ Prevented default Roblox character cleanup** - BreakJointsOnDeath = false, PlatformStand = true
6. **✅ Updated project structure** - Moved files to proper locations and updated default.project.json
7. **✅ Fixed client script character loading** - Proper character wait handling
8. **✅ Added proper return values** - Functions now return success/failure status
9. **✅ Tested with player characters** - System working correctly in-game

### 🔄 Next Steps - Food Drop System (Future Implementation)
1. Create FoodDropSystem module with animal-specific food models
2. Implement cooking surface detection and state changes  
3. Add food consumption mechanics with E key interaction
4. Balance hunger restoration values for raw vs cooked food
5. Integrate food models with existing drag-drop system

## File Structure Changes
```
src/
├── shared/
│   └── modules/
│       └── RagdollModule.lua          # ✅ Moved from /Ragdoll/
├── server/
│   └── player/
│       └── PlayerDeathHandler.server.lua # ✅ New - handles player deaths
└── client/
    └── ragdoll/
        └── RagdollClient.client.lua   # ✅ Moved from /Ragdoll/

default.project.json                   # ✅ Updated to include modules folder
```

## System Status
- **Ragdoll Physics**: ✅ Fully operational for players and humanoid creatures
- **Death Handling**: ✅ Smart differentiation between creature types  
- **Cleanup Prevention**: ✅ Bodies remain as physics objects
- **Error Handling**: ✅ Robust with proper return values
- **Client Integration**: ✅ Camera handling and character loading fixed

---
**Created**: July 28, 2025
**Updated**: July 28, 2025
**Status**: ✅ Ragdoll System Complete - Ready for Food System Implementation
