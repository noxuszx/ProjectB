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
- **Procedural terrain generation** with chunk-based infinite worlds
- **Advanced AI creature system** with 200+ creatures, pooling, and LOD optimization
- **Survival mechanics** including hunger/thirst, hunting, cooking, and building
- **Dynamic day/night cycles** affecting spawning and gameplay
- **Interactive building system** with drag/drop, welding, and rotation mechanics
- **Combat and riding systems** with multiple creature types

## Build and Development Commands

This project uses Rojo for asset management:

```bash
# Build the project (requires Rojo installation via aftman)
rojo build -o ProjectB.rbxlx

# Serve for live development
rojo serve

# Install tools
aftman install
```

The project file structure is defined in `default.project.json` and should be built using Rojo 7.5.1 or later.

## Architecture Overview

### Core Systems Architecture

**Self-Contained AI System (`src/server/ai/`)**
- `LODManager.lua` - Global performance controller tracking all creatures via CollectionService
- `CreatureSpawner.lua` - Modified to tag spawned creatures for LOD tracking
- `CreaturePoolManager.lua` - Memory pooling system preventing frame drops
- `LODPolicy.lua` - Distance-based performance optimization (30Hz close, 2Hz far)
- `ParallelLODActor.lua` - Parallel processing for large creature populations

**Individual Creature Scripts (Self-Contained Pattern)**
- Each creature type has its own AI script (e.g., `RabbitAI.server.lua`, `CoyoteAI.server.lua`)
- Scripts respond to LOD attributes: `LOD_Active`, `LOD_Level`, `LOD_UpdateRate`
- No cross-dependencies between creatures - fully isolated behavior
- Easy to debug individual creature types

**Current AI Architecture (Hybrid System)**
- ✅ `AIManager.lua` - Centralized creature registry and management
- ✅ `BaseCreature.lua` - Base class for common creature functionality
- ✅ Individual creature AI scripts - Self-contained behavior patterns
- ✅ `LODManager.lua` - Performance optimization system
- ✅ `CreaturePoolManager.lua` - Memory pooling for specific creatures

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
When working with creatures, follow the self-contained pattern:
1. Define creature stats in `AIConfig.lua` first
2. Create individual AI scripts following the template pattern (see `Self-Contained-Creature-System-Documentation.md`)
3. Scripts must check `LOD_Active` attribute and respect `LOD_UpdateRate` for performance
4. Use CollectionService "Creature" tag for automatic LOD tracking
5. Leverage the pooling system for performance (creatures are reused, not destroyed)
6. Test with high creature counts (100+) to ensure performance

**Self-Contained AI Script Template:**
```lua
-- Example: CamelAI.server.lua
local model = script.Parent
local humanoid = model:WaitForChild("Humanoid")
local creatureType = model:GetAttribute("CreatureType")
local config = require(game.ReplicatedStorage.Shared.config.ai.AIConfig).CreatureTypes[creatureType]

-- Main AI loop
while model.Parent do
    local isActive = model:GetAttribute("LOD_Active")
    local updateRate = model:GetAttribute("LOD_UpdateRate") or 1
    
    if isActive then
        -- Run creature-specific AI logic here
        performCreatureAI()
        wait(1/updateRate)
    else
        wait(1) -- Paused when far from players
    end
end
```

### Building System Integration
The drag/drop system uses:
- `CollectionService` tags for interactable objects
- `WeldConstraints` for object attachment (press Z)
- Mouse-based positioning with collision detection
- Server-side validation for all interactions

### Performance Considerations
- Always use `os.clock()` for timing consistency
- Self-contained AI scripts must respect LOD system (check `LOD_Active`, use `LOD_UpdateRate`)
- Use LOD principles for any distance-based systems
- Cache expensive calculations (player positions, etc.)
- LODManager automatically handles performance optimization - don't override its decisions

## Testing and Verification

When making changes:
1. Test with 100+ creatures spawned to verify performance
2. Verify LOD system is working (`LODManager.getLODStats()` for debugging)
3. Ensure creature AI scripts respect LOD attributes properly
4. Verify day/night cycle affects creature behavior appropriately  
5. Test building system interactions (drag, weld, rotate)
6. Check player stats UI updates correctly
7. Ensure creatures properly pool/reuse without memory leaks

## File Organization Conventions

- **Modules**: PascalCase filenames, return single table/class
- **Services**: Use Roblox services at the top of files
- **Configs**: Centralized in `src/shared/config/` with clear hierarchies
- **Tags**: Use `CollectionService` tags defined in `CollectionServiceTags.lua`
- **Remotes**: Defined in project structure, accessed via ReplicatedStorage.Remotes
- **Creature AI Scripts**: Individual scripts per creature type, following self-contained pattern

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

2. **Create individual AI script** (e.g., `WolfAI.server.lua`):
- Follow the self-contained template pattern
- Check `LOD_Active` and respect `LOD_UpdateRate`
- Implement creature-specific behavior logic

3. **Add to spawn weights** (optional):
```lua
SpawnSettings = {
    CreatureWeights = {
        Wolf = 5, -- Spawn frequency
    }
}
```

4. **Place script in creature model** in ReplicatedStorage or inject at runtime

The creature will automatically be tracked by LODManager and respect performance optimization.

The codebase follows a self-contained modular architecture where each creature manages its own behavior independently, while LODManager handles global performance optimization.

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