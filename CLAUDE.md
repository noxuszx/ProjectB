# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Development Guidelines

## Core Principles

### 1. Don't Reinvent the Wheel
**Always use existing solutions before building custom ones:**

- **Roblox Built-in Services First** - Seat systems, Humanoid movement, network ownership, UserInputService
- **Community Frameworks Second** - ZonePlus for zones, ProfileService for data, Roact for UI
- **Custom Solutions Last** - Only when no proven solution exists

### 2. Industry Standards & Best Practices
- Follow established patterns and conventions
- Use battle-tested solutions over experimental approaches
- Prioritize maintainable, readable code over clever solutions
- Leverage optimized C++ systems over Lua reimplementations

### 3. Examples
```lua
-- L BAD: Custom collision detection
while true do
    local rayResult = workspace:Raycast(...)
    -- 50+ lines of edge case handling
end

--  GOOD: Use ZonePlus
local zone = ZonePlus.new(part)
zone.playerEntered:Connect(function(player) end)
```

```lua
-- L BAD: Complex behavior state management for riding
MountedBehavior, RoamingBehavior, FleeingBehavior conflicts

--  GOOD: Use Roblox seat system
seat:GetPropertyChangedSignal("Occupant"):Connect(...)
humanoid:Move(inputVector.Unit, true)
```

---

*"If Roblox has a service for it, use it. If the community has a proven solution, use it. Only build custom when neither exists."*

## Project Overview

ProjectB is a Roblox desert survival game featuring:
- **Procedural terrain generation** with chunk-based world (infinite possible but not used.)
- **Advanced AI creature system** with 200+ creatures, pooling, and LOD optimization
- **Survival mechanics** including hunger/thirst, hunting, cooking, and building
- **Dynamic day/night cycles** affecting spawning and gameplay
- **Interactive building system** with drag/drop, welding, and rotation mechanics
- **Combat and riding systems** with multiple creature types

The project file structure is defined in `default.project.json` and should be built using Rojo 7.5.1 or later.

## Architecture Overview

### Core Systems Architecture

**Centralized AI System (`src/server/ai/`)**
- `AIManager.lua` - Singleton pattern central coordinator handling creature lifecycle and updates
- `AICreatureRegistry.lua` - Centralized creature tracking and management registry
- `CreaturePoolManager.lua` - Memory pooling system preventing frame drops by reusing models
- `CreatureSpawner.lua` - Spawns creatures using class-based system with pooling integration
- `NightHuntManager.lua` - Night-specific creature spawning and behavior management
- `SpawnerPlacement.lua` - Spawner positioning and zone-based placement logic
- `ZoneSpawnerController.server.lua` - Zone-based spawning control system
- `UpdateExistingCreatures.server.lua` - Runtime creature updates and modifications

**Modular Creature Architecture (`creatures/` folder)**
- `Base.lua` - Abstract base class providing common functionality and interface
- `Passive.lua` - Inherits from Base, handles roaming and fleeing behaviors
- `Hostile.lua` - Inherits from Base, handles chasing and attacking behaviors
- `RangedHostile.lua` - Specialized ranged combat creature with projectile attacks
- No individual creature scripts - all logic handled through class inheritance

**Enhanced Behavior System (`behaviors/` folder)**
- `AIBehavior.lua` - Base behavior class with standardized interface
- `Roaming.lua` - Wandering movement patterns for passive creatures
- `Chasing.lua` - Pursuit behavior for hostile creatures
- `Fleeing.lua` - Escape behavior when threatened
- `RangedAttack.lua` - Projectile-based combat behavior
- `RangedChasing.lua` - Ranged pursuit with distance management

**Arena Combat System (`arena/` folder)**
- `ArenaAIManager.lua` - Specialized AI manager for arena-based combat encounters
- `ArenaCreature.lua` - Arena-specific creature behaviors and mechanics
- `ArenaCreatureSpawner.lua` - Arena creature spawning and management

**Audio Integration (`audio/` folder)**
- `AutoBindSFX.server.lua` - Automatic sound effect binding to creature actions
- `SFXManager.lua` - Centralized audio management for AI creatures

**Performance Optimization Systems (`optimization/` folder)**
- `LODPolicy.lua` - Distance-based performance optimization (30Hz close, 2Hz far)
- `ParallelLODActor.lua` - Parallel processing for large creature populations
- `PathNav.lua` - Advanced pathfinding navigation system
- `AIDebugger.lua` - Performance monitoring and debugging tools
- Player position caching system eliminates expensive character lookups
- Batched LOD updates with time-budgeted processing
- Registry-based creature management with efficient cleanup

### Performance Optimization Systems

The codebase is heavily optimized for handling 200+ creatures simultaneously:

**Memory Pooling** - `CreaturePoolManager.lua` prevents frame drops by reusing creature models instead of destroying them

**LOD System** - Distance-based update rates with parallel processing:
- Close (0-50 studs): 30Hz updates
- Medium (50-100 studs): 15Hz updates  
- Far (100-250 studs): 2Hz updates

**Batch Processing** - Registry operations and cleanup processed in time-budgeted batches

**Player Position Caching** - Eliminates expensive character lookups during distance calculations

### Configuration System

All systems are driven by configuration files in `src/shared/config/`:

**AI Configuration (`src/shared/config/ai/AIConfig.lua`)**
- Creature definitions (health, speed, behaviors, damage)
- Performance settings (LOD distances, update rates, pool sizes)
- Spawn parameters (weights, biomes, population limits)

**Core Game Configs**
- `PlayerStatsConfig.lua` - Hunger/thirst mechanics and UI settings
- `ChunkConfig.lua` - Procedural world generation parameters
- `DragDropConfig.lua` - Building system interaction settings

### Network Architecture

**RemoteEvents Structure (default.project.json)**
- Creature health updates for client health bars
- Riding system with network ownership transfer
- Building system (drag/drop, welding, item interactions)
- Player stats synchronization
- Combat/weapon damage events
- Backpack/inventory system (LIFO sack with object pooling)

**Client-Server Separation**
- Server: AI logic, spawning, physics, game state
- Client: UI, input handling, effects, health bar displays
- Shared: Configuration, utilities, common modules

## Key Development Patterns

### AI Creature Development
When working with creatures, follow the modular class-based inheritance pattern:
1. **Define creature stats** in `AIConfig.lua` first with all creature type configurations
2. **Extend creature classes** - Modify `creatures/Passive.lua`, `creatures/Hostile.lua`, or `creatures/RangedHostile.lua` for new behaviors
3. **Create behavior classes** - Add new behavior modules in `behaviors/` folder if needed
4. **Update CreatureSpawner** - Add new creature types to spawning logic
5. **Leverage pooling system** - Creatures are reused via `CreaturePoolManager`, not destroyed
6. **Test with high counts** - Verify performance with 100+ creatures

**Class-Based Creature Example:**
```lua
-- Example: Adding new behavior to creatures/Passive.lua
function Passive:update(deltaTime)
    -- Base creature update
    Base.update(self, deltaTime)
    
    -- Passive-specific logic
    if self.health <= self.maxHealth * 0.3 then
        self:setBehavior(FleeingBehavior.new())
    elseif self.currentBehavior:getType() ~= "Roaming" then
        self:setBehavior(RoamingBehavior.new())
    end
    
    -- Update current behavior
    self.currentBehavior:update(self, deltaTime)
end
```

**Adding New Creature Types:**
1. Add creature definition to `AIConfig.lua`
2. Determine if it extends `creatures/Passive.lua`, `creatures/Hostile.lua`, or `creatures/RangedHostile.lua`
3. Create new class file in `creatures/` folder if significantly different behavior needed
4. Update `CreatureSpawner.lua` to include in spawning logic
5. Consider arena variants using `arena/` system for combat encounters

### Building System Integration
The drag/drop system uses:
- `CollectionService` tags for interactable objects
- `WeldConstraints` for object attachment (press Z)
- Mouse-based positioning with collision detection
- Server-side validation for all interactions

### Performance Considerations
- Always use `os.clock()` for timing consistency
- AI classes are managed by `AIManager` singleton - avoid direct creature instantiation
- LOD system is handled automatically by `LODPolicy` - creatures receive optimized update rates
- Use cached player positions from `AIManager` instead of expensive character lookups
- Leverage `CreaturePoolManager` for creature reuse instead of destruction/creation

## File Organization Conventions

- **Modules**: PascalCase filenames, return single table/class
- **Services**: Use Roblox services at the top of files
- **Configs**: Centralized in `src/shared/config/` with clear hierarchies
- **Tags**: Use `CollectionService` tags defined in `CollectionServiceTags.lua`
- **Remotes**: Defined in project structure, accessed via ReplicatedStorage.Remotes
- **Creature Classes**: Modular class-based inheritance system in `creatures/` folder extending from `Base.lua`

## Adding New Creature Types

To add a new creature type (e.g., Wolf):

1. **Define in AIConfig.lua:**
```lua
CreatureTypes = {
    Wolf = {
        Type = "Hostile",
        Health = 120,
        MoveSpeed = 18,
        DetectionRange = 35,
        TouchDamage = 15,
        -- etc...
    }
}
```

2. **Determine creature class** - Decide if Wolf extends `creatures/Passive.lua`, `creatures/Hostile.lua`, or `creatures/RangedHostile.lua`

3. **Update CreatureSpawner** - Add Wolf to the spawning logic in `CreatureSpawner.lua`

4. **Add to spawn weights** (optional):
```lua
SpawnSettings = {
    CreatureWeights = {
        Wolf = 5, -- Spawn frequency
    }
}
```

5. **Create custom behaviors** (if needed) - Add new behavior classes in `behaviors/` folder

The creature will automatically be managed by `AIManager` and tracked by the registry system for performance optimization.

The codebase follows a centralized class-based architecture where `AIManager` coordinates all creatures using inheritance patterns, with `CreaturePoolManager` handling efficient reuse and `LODPolicy` managing performance optimization.

## Performance & Instance Creation Optimization

### UI System Improvements
The project has moved away from script-created UI to manually designed UI elements:

**Before (Heavy Instance.new() usage):**
```lua
local screenGui = Instance.new("ScreenGui")
local frame = Instance.new("Frame") 
local label = Instance.new("TextLabel")
-- 10+ Instance.new() calls per UI system
```

**After (Reference existing elements):**
```lua
local screenGui = playerGui:WaitForChild("BackpackGui")
local frame = screenGui:WaitForChild("BackpackFrame")
local label = frame:WaitForChild("Counter")
-- 0 Instance.new() calls - references Studio-created UI
```

### Benefits of Manual UI Creation
- ✅ **Reduced runtime overhead** - No UI creation during gameplay
- ✅ **Version-controlled UI** - UI elements saved in place files
- ✅ **Easier maintenance** - Visual editing in Studio vs code
- ✅ **Better performance** - Eliminates UI creation frame drops
- ✅ **Consistent styling** - Manual positioning and styling in Studio

### Implementation Pattern
When creating new UI systems:
1. **Design UI in Studio** - Create ScreenGui and elements manually
2. **Reference in scripts** - Use WaitForChild() to get existing elements  
3. **Conditional elements** - Use FindFirstChild() for optional elements (mobile buttons)
4. **No Instance.new()** - Avoid runtime UI creation unless absolutely necessary

## Backpack/Inventory System

The game features a LIFO (Last In, First Out) sack-based inventory system with object pooling:

### Key Features
- **10-slot capacity** with LIFO stack behavior
- **Object pooling** - Items moved to ServerStorage instead of destroyed/recreated
- **Dead creature storage** - Ragdolled creatures (Villager1, Villager2, Mummy, Skeleton) can be stored
- **Safety checks** - Prevents storing alive creatures
- **Multi-player support** - Each player has isolated inventory
- **Responsive UI** - Simple counter with black outline, shows only when sack is equipped

### Architecture
- `BackpackService.lua` - Server-side LIFO stack management and object pooling
- `BackpackHandler.server.lua` - RemoteEvent handling for client-server communication
- `BackpackController.client.lua` - Client input handling (E/F keys, mobile buttons)
- `BackpackUI.client.lua` - References manually created UI elements (no more Instance.new())
- Uses `CollectionService` tags (STORABLE, DRAGGABLE) for item validation

### Usage Pattern
1. Equip sack tool to show UI counter
2. Look at storable objects and press E to store (F on mobile via touch buttons)
3. Press F to retrieve (drops 5 studs in front, 0.5 studs up) 
4. Dead humanoid creatures automatically get storable tags when ragdolled
5. Pooled creatures (rabbit, scorpion, coyote) use separate food drop system

### UI Implementation 
- **Manual UI Creation** - Create `StarterGui > BackpackGui` (ScreenGui) in Studio
- **Required Elements**: `BackpackFrame > Counter` (TextLabel for "0/10" display)
- **Mobile Support**: `MobileButtons > StoreButton/RetrieveButton` (auto-hidden on desktop)
- **No Instance.new()** - Script references existing UI elements instead of creating them

## Economy System

The game features a cash-based economy system with physical money and item trading:

### Key Features
- **Session-based economy** - Money resets each game join (roguelike style)
- **Physical cash system** - Selling items spawns collectible cash meshparts
- **Buy/sell zones** - Tagged parts for item commerce
- **3-tier item values** - Items worth 15, 25, or 50 coins
- **Visual affordability** - Item highlighting based on player money

### Architecture
- `EconomyService.lua` - Server-side money management and transaction handling
- `SellZoneHandler.server.lua` - Processes item sales and spawns cash
- `BuyZoneHandler.server.lua` - Auto-spawns buyable items at tagged zones
- `EconomyUI.client.lua` - Green money display with gold dollar sign
- `ItemHoverHighlighting.client.lua` - Green/red item highlighting on hover
- Individual cash collection scripts in each cash meshpart
- **Remote Event Management** - All RemoteEvents pre-defined in `default.project.json` (no runtime creation)

### Selling System
1. **Tag items** with `SELLABLE_LOW` (15 coins), `SELLABLE_MID` (25 coins), or `SELLABLE_HIGH` (50 coins)
2. **Tag parts** with `SELL_ZONE` for selling areas
3. **Drag tagged items** into sell zones → Item destroyed, cash spawns
4. **Collect cash** via proximity prompts on spawned cash meshparts

### Buying System  
1. **Tag parts** with `BUY_ZONE` → Auto-spawns random buyable items with ProximityPrompts
2. **Approach items** → ProximityPrompt appears showing "Buy [ItemName] - [Cost] coins"
3. **Hold E** (0.5 seconds) → Purchase if affordable, ProximityPrompt destroyed, item becomes regular draggable
4. **Visual feedback** → Green/red highlighting on hover shows affordability

### Cash Collection
- Cash meshparts (cash15, cash25, cash50) spawn where items are sold
- Each contains ProximityPrompt and CashCollection.server.lua script
- Players collect cash via proximity interaction
- Cash value automatically determined from meshpart name

### Configuration
- `EconomyConfig.lua` - Defines sellable values, buyable items, UI settings
- Integration with existing CollectionService tag system
- Uses RemoteEvents: SellItem, BuyItem, UpdateMoney, CollectCash, RefreshBuyZones
- ProximityPrompt-based purchasing system with 0.5 second hold duration

### Key Implementation Details
- **No instant respawning** - Buy zones become empty after purchase (items respawn during specific day/night times)
- **Item preservation** - Purchased items remain in world as regular draggable objects
- **Multiple zone support** - Each BUY_ZONE/SELL_ZONE tagged part operates independently
- **Object pooling** - Cash collection uses pooled meshparts for performance
- **Pre-defined RemoteEvents** - Economy RemoteEvents defined in project structure, accessed via `WaitForChild()`
- **No runtime creation** - Follows project pattern of avoiding `Instance.new()` for RemoteEvents