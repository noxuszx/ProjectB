# Tower Spawner System – High-Level Design

> Last updated: 2025-08-06
> **Integration Review**: Added recommendations for ProjectB architecture integration

## 1. Goals

* Activate enemy spawners only when players are nearby to keep server load predictable.
* Allow designers to add new towers or tweak spawn rates **without editing code**.
* Keep the solution data-driven, resilient, and easy to unit-test.

---

## 2. Content Hierarchy (in Roblox Studio)

```
Workspace
└─ Towers
   ├─ Tower_A ──┐                -- tagged "Tower"
   │  ├─ Floor1 ──┐              -- Attribute FloorIndex = 1
   │  │  ├─ Trigger (Part)       -- zone volume per floor
   │  │  └─ Spawner (Folder)     -- tagged "MobSpawner"
   │  └─ Floor2 ...
   └─ Tower_B ...
```

Naming is only a convention; the **tags** and **attributes** are what the scripts rely on:

| Object                 | Tag / Attribute | Purpose                                   |
|------------------------|-----------------|-------------------------------------------|
| Tower model            | `"Tower"` tag   | Auto-discovery of all towers              |
| Floor model            | `FloorIndex`    | Determines which floor is “above”         |
| Spawner object         | `"MobSpawner"`  | Allows Mass collection via CollectionService |
| Spawner object         | `SpawnInterval` | Seconds between spawn attempts (number)   |
| Spawner object         | `MaxActive`     | Cap on simultaneous monsters              |

> Ground-floor spawner (FloorIndex 1) is always active on server start.

---

## 3. Runtime Architecture

| Layer            | Script / Module                                | Responsibility                                               |
|------------------|------------------------------------------------|-------------------------------------------------------------|
| **Bootstrap**    | `TowerBootstrap.server.lua`                    | Calls `TowerController.init()` on Server start              |
| **Controller**   | `TowerController.lua` *(Module)*               | Builds tower tables, sets up zones, activates floors        |
| **Spawner Logic**| `MobSpawner.lua` *(Module)*                    | Handles individual spawn loops & monster bookkeeping        |
| **Zone Engine**  | [ZonePlus](https://devforum.roblox.com/t/zoneplus/) | Efficient proximity detection (preferred over Region3)      |
| **VFX / SFX**    | `TowerFX` *(RemoteEvent)*                      | Notifies clients when a floor unlocks                       |

### Activation Flow

1. **Server starts** → `TowerController.init()` scans all models tagged `"Tower"`.
2. For each tower:
   1. Floors are cached in a table: `floors[index] = {trigger, spawner, zone}`.
   2. Floor 1 spawner activates immediately.
   3. A `Zone` object is built from each floor’s *Trigger* part.
3. **Player enters** floor *n* zone → callback runs `activateFloor(n + 1)`.
4. `activateFloor()` starts a coroutine that:
   * Checks `#liveMobs < MaxActive`.
   * Clones monster template, parents to Workspace, positions near spawner.
   * Waits `SpawnInterval` seconds and repeats while `floor.active == true`.
5. **Optional reset**: when no players remain in any zones of a tower, you may clear mobs & deactivate floors for replayability.

---

## 4. Performance & Reliability Practices

* **Server-side authority** – all detection & spawning run on server; clients only play FX.
* **StreamingEnabled** – unloaded towers cost zero; ZonePlus handles streamed parts gracefully.
* **Debounce** zone callbacks for ~0.2 s to avoid rapid re-entries on boundary edges.
* **Weak tables** in `MobSpawner` keep memory clean when monsters die.
* **Attributes & Tags** > hard-coded names – makes content fully data-driven.

---

## 5. Testing Checklist

- [ ] Unit tests for `MobSpawner` (TestEZ).
- [ ] Stress-test with 10 simulated players (Roblox Studio > Test > Start).
- [ ] Verify tower reset logic after clearing floors.
- [ ] Confirm spawn caps hold at high latency.

---

## 6. Next Steps

1. Commit `TowerController.lua`, `MobSpawner.lua`, and `TowerBootstrap.server.lua`.
2. Add at least one sample tower in **Workspace** for play-testing.
3. Iterate spawn balance via `MaxActive` and `SpawnInterval` attributes.

---

## 7. ProjectB Integration Recommendations

After reviewing the existing ProjectB architecture, here are key recommendations for better system integration:

### 7.1 Architecture Conflicts & Solutions

**Problem**: The proposed MobSpawner creates a separate creature management system that conflicts with the existing centralized AIManager singleton.

**Recommended Solution**: 
- Integrate tower spawning as a **spawn source** within the existing AIManager rather than creating parallel systems
- Extend `CreatureSpawner.lua` to support zone-based activation alongside procedural spawning
- All creatures (procedural + tower-based) managed by the single AIManager for consistent performance optimization

### 7.2 Leverage Existing Performance Systems

**Current Optimization**: ProjectB is heavily optimized for 200+ creatures with:
- CreaturePoolManager (memory pooling prevents frame drops)
- LOD system (30Hz/15Hz/2Hz update rates by distance)  
- Class-based architecture (BaseCreature → PassiveCreature/HostileCreature)
- Batch processing and frame budgeting

**Integration**: Tower-spawned creatures should **inherit all existing optimizations**:
- Use CreaturePoolManager for efficient reuse
- Participate in LOD system for distance-based performance scaling
- Extend existing creature classes (not create new ones)
- Be managed by AICreatureRegistry for consistent cleanup

### 7.3 Configuration System Integration

**Current System**: Data-driven configs in `src/shared/config/ai/AIConfig.lua`

**Recommended Integration**:
```lua
-- Add to AIConfig.lua
TowerSpawning = {
    Settings = {
        DeactivationDelay = 30, -- Seconds before deactivating empty floors
        MaxTowerCreatures = 50, -- Per-tower creature limit
        ForceDeactivationTime = 120, -- Force deactivation if zone empty this long (safety)
        IndoorLODBias = 1.5,    -- Multiplier for indoor LOD rates (less aggressive throttling)
        ZoneDebounceTime = 0.2, -- Debounce zone callbacks to avoid rapid re-entries
    },
    
    -- Per-tower configuration for designer control
    Towers = {
        Tower_A = {
            MaxCreatures = 25,
            CreatureOverrides = {
                TowerSkeleton = { Health = 80, MoveSpeed = 22 }
            }
        },
        Tower_B = {
            MaxCreatures = 30,
            CreatureOverrides = {
                TowerMummy = { Health = 200, TouchDamage = 25 }
            }
        }
    },
    
    -- Tower-specific creature variants (extend existing CreatureTypes)
    TowerCreatureTypes = {
        TowerSkeleton = {
            BaseType = "Skeleton",  -- Inherits from existing Skeleton config
            Health = 80,           -- Override specific values
            MoveSpeed = 22,
            SpawnWeight = 5,
        }
    }
}
```

### 7.4 Improved Architecture Proposal

**Instead of**: Separate TowerController + MobSpawner classes
**Propose**: 
1. **ZoneSpawnerController.server.lua** - Event-based interface with AIManager
   - `AIManager:RegisterSpawnSource(sourceId, spawnCallback)` for loose coupling
   - Future quest/event spawners can plug in without tight coupling
2. **Extended CreatureSpawner.lua** - Add `activationMode = "Zone"` branch
   - Merge MobSpawner logic into existing CreatureSpawner rather than separate module
   - Supports both procedural and zone-triggered spawning modes
3. **Unified Creature Management** - All creatures flow through AIManager regardless of spawn source
4. **Configuration Harmony** - Tower spawning configs integrated with AIConfig structure

### 7.5 CollectionService Integration

**Excellent Fit**: ProjectB already uses CollectionService extensively for:
- STORABLE/DRAGGABLE tags (economy system)
- SELLABLE/BUY_ZONE tags (commerce)
- Protected geometry collision detection

The proposed Tower/MobSpawner tagging approach aligns perfectly with existing patterns.

### 7.6 Implementation Priority

**Phase 1**: Zone detection and activation (integrate ZonePlus)
**Phase 2**: Extend CreatureSpawner for zone-based spawning  
**Phase 3**: Configure tower creature variants in AIConfig
**Phase 4**: Test integration with existing 200+ creature performance optimization

### 7.7 Critical Implementation Details

**CreaturePoolManager Integration:**
- Tower creatures MUST call `Reset()` / `ReturnToPool()` on death
- Custom ragdoll FX must fire BEFORE returning to pool to avoid visual glitches
- Verify pool cleanup handles tower-specific creature variants

**LOD System Adjustments:**
- Indoor floors need "indoor bias" - less aggressive throttling since players are closer
- Apply `IndoorLODBias = 1.5` multiplier to update rates for tower creatures
- Close: 30Hz → 45Hz, Medium: 15Hz → 22Hz, Far: 2Hz → 3Hz indoors

**ZonePlus + StreamingEnabled Safety:**
- Create wrapper for trigger parts that handles AncestorChanged events
- Re-create zones when trigger parts stream back in to avoid stale connections
- Monitor for StreamingEnabled conflicts with zone detection

**Deactivation Safety Mechanisms:**
- `DeactivationDelay = 30s` for normal PvE loops
- `ForceDeactivationTime = 120s` - force floor inactive if zone empty this long (prevents stuck flags)
- Server memory safeguard: `if #liveMobs == 0 and zoneEmptyDuration > 120s then forceDeactivate()`

**File Organization:**
- `ZoneSpawnerController.server.lua` under `ServerScriptService/AI/` (with other AI scripts)
- Merge MobSpawner logic into `CreatureSpawner.lua` as activation mode rather than separate module

### 7.8 Testing Considerations

- **Performance**: Verify tower creatures don't break existing 200-creature optimization  
- **LOD System**: Test indoor bias multiplier maintains smooth performance
- **Memory**: Ensure CreaturePoolManager handles tower creature variants and ragdoll FX properly
- **AI Behavior**: Tower creatures should use existing behavior classes (Roaming, Chasing, etc.)
- **StreamingEnabled**: Test zone re-creation when parts stream in/out
- **Safety Systems**: Verify force deactivation prevents stuck spawners

---

*Integration maintains ProjectB's performance-first, data-driven architecture while adding tower functionality*

