# Project Improvement Suggestions

This document outlines potential improvements for various systems in the project.

---

## VillageSpawner.lua Improvements

### [] 1. Enforce Minimum Distance Between Villages
*   **Issue**: The spawner picks random locations for villages without checking if they are too close to already spawned villages, causing them to overlap.
*   **Suggestion**: Implement a "check-then-add" logic. Before spawning a new village, check its proposed location against a list of already spawned village positions. Ensure the distance is greater than a new configuration value (e.g., `MIN_VILLAGE_DISTANCE`). Only if the location is valid, spawn the village and add its position to the list.

---

## CustomModelSpawner.lua Improvements

### [] 1. Remove Generation Delay to Improve Performance
*   **Issue**: The `wait(ModelSpawnerConfig.GENERATION_DELAY)` call inside the main spawning loop artificially slows down the entire world generation process.
*   **Suggestion**: Remove the `wait()` call completely. Initial world generation should be as fast as possible. A brief, one-time period of high CPU usage during the loading screen is preferable to a long, drawn-out loading time.

### [] 2. Implement Bounding Box Check to Avoid Overlapping
*   **Issue**: The spawner currently places models without checking if the area is already occupied by other objects like villages or creature spawners, leading to models spawning on top of each other.
*   **Suggestion**: Before placing a model, use the `workspace:GetPartsInBox()` method to check if the target area is clear. This provides a simple and reliable way to detect any existing parts (excluding the terrain itself) and prevent the spawner from placing models in occupied space.

---

## FoodDropSystem.lua Improvements

### [] 1. Centralize Tags in `CollectionServiceTags`
*   **Issue**: The string `"Consumable"` is hardcoded in `FoodDropSystem.lua`.
*   **Suggestion**: Add a `CONSUMABLE` field to the `CollectionServiceTags` module to avoid magic strings and improve maintainability.

### [] 2. More Robust Unique Naming
*   **Issue**: `tick()` is used for generating unique food model names. While likely sufficient, it could theoretically produce collisions in high-frequency scenarios.
*   **Suggestion**: For greater robustness, consider using a simple incrementing counter or a dedicated UUID library if available.

### [] 3. Use a Raycast Whitelist for Drops
*   **Issue**: The raycast in `getDropPosition` uses a blacklist to ignore the `foodFolder`. This could allow food to spawn on unintended objects.
*   **Suggestion**: Switch to a whitelist to ensure food only spawns on designated surfaces like terrain.

### [] 4. Tag-Based Cooking Surface Detection
*   **Issue**: Cooking surfaces are detected by checking model names with `string.find`, which can be error-prone.
*   **Suggestion**: Use `CollectionService` to add a `"CookingSurface"` tag to all valid cooking models. This makes detection more explicit and reliable.

### [] 5. Optimize `onTouched` Function
*   **Issue**: The `isCooked` check is performed after other checks in the `onTouched` function.
*   **Suggestion**: Move the `isCooked` check to the beginning of the function to exit earlier and improve efficiency.

---
## AIManager.lua Improvements

### Performance / memory

* 1.1 **Re-use tables in getCreaturesInRange**
    table.insert on an ever-growing array can allocate a lot of tiny tables every frame.
    Keep a single “scratch” array, clear it with table.clear(scratch) (Luau built-in), then return a copy only if the caller actually needs to keep it.  
    Example:

```
local scratchInRange = {}
function AIManager:getCreaturesInRange(position, range)
    table.clear(scratchInRange)
    -- … fill scratchInRange …
    -- If caller must mutate the list, return table.clone(scratchInRange)
    return scratchInRange
end
```

* 1.2  **Distance check vectorisation**
    calculateLODLevel and getCreaturesInRange iterate all players for every creature.
    If you have 200 creatures × 20 players you are doing 4 000 magnitude calculations each frame.
    Cache the positions of all players every heartbeat:

```
local cachedPlayerData = {} -- [player] = {pos = Vector3, lastUpdate = number}
local function updatePlayerCache()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        local root = char and char.PrimaryPart
        cachedPlayerData[p] = root and {pos = root.Position, lastUpdate = tick()}
    end
end
```

Then calculateLODLevel becomes a small loop over 20 cached vectors instead of 20 root-part lookups.

* 1.3  Replace tick() with os.clock() or workspace:GetServerTimeNow()
    tick() is deprecated and slightly more expensive.
    (If you need deterministic replays, prefer workspace:GetServerTimeNow()).

*  1.4  Early-exit in update loop
If the update budget is exhausted (deltaTime > self.updateBudget) skip all remaining creatures this frame.
Right now you always finish the whole list.

---

## Combat System & Network Optimization

### [] 1. Implement Client-Side Prediction for Combat
*   **Issue**: Players with poor internet experience delayed damage feedback due to client → server → validation → apply damage flow.
*   **Suggestion**: Add client-side prediction where the client immediately shows visual damage effects (health bar changes, hit effects) while the server validates in the background. Server can correct/reconcile any discrepancies later.

### [] 2. Set NetworkOwnership to nil for Combat Entities
*   **Issue**: Combat entities (players, NPCs) may have choppy movement for other players due to network ownership being assigned to the closest player.
*   **Suggestion**: During combat encounters, set `character.PrimaryPart:SetNetworkOwner(nil)` to ensure the server controls movement, providing smoother visual experience for all players.

### [] 3. Combat Entity Network Ownership Best Practices
*   **AI/NPC entities**: Always use `SetNetworkOwner(nil)` for consistent server-controlled movement
*   **Player characters**: Consider temporarily setting to nil during active combat
*   **Environmental objects**: Leave default unless causing visual issues
*   **Note**: This increases server CPU usage but significantly improves player experience

### [] 4. Network Latency Compensation
*   **Issue**: High-ping players may miss fast-moving targets or experience delayed hit registration.
*   **Suggestion**: Implement lag compensation by using timestamps and rewinding game state for hit validation, similar to Source engine's approach.

---

## DragDrop Building System Improvements

### [] 1. Implement Grid-Based Positioning
*   **Issue**: Objects can be placed at any position, making alignment difficult and structures unstable.
*   **Suggestion**: Add a building grid system that snaps objects to discrete positions (e.g., 4x4 stud grid). Include a toggle between "Free Mode" and "Build Mode" where Build Mode enforces grid snapping.

### [] 2. Replace Fine Rotation with Snap Rotation
*   **Issue**: Current 15-degree rotation steps are too precise, leading to tilted and unstable structures.
*   **Suggestion**: Change rotation to 90-degree snaps (0°, 90°, 180°, 270°) for building stability. Keep fine rotation as an optional "Advanced Mode" for decorative items.

### [] 3. Add Surface Alignment System
*   **Issue**: Objects don't automatically align to surfaces, causing gaps and floating pieces.
*   **Suggestion**: Implement automatic surface detection that:
   - Snaps bottom face of objects to the surface below
   - Aligns objects to the normal of the surface they're placed on
   - Provides visual preview showing where the object will snap

### [] 4. Implement Foundation/Base Detection
*   **Issue**: Buildings can be constructed without proper foundations, leading to physics instability.
*   **Suggestion**: Add a foundation system where:
   - First placed objects automatically anchor to terrain
   - Subsequent objects must connect to anchored structures
   - Visual feedback shows "structural integrity" of builds

### [] 5. Add Build Preview System
*   **Issue**: Players can't see where objects will be placed until they release them.
*   **Suggestion**: Show a semi-transparent preview of the object at its snap position while dragging, including:
   - Grid alignment visualization
   - Surface normal indicators
   - Collision warnings (red preview if placement is invalid)

### [] 6. Simplify Rotation Controls
*   **Issue**: Current X/R key system for 3-axis rotation is complex and confusing.
*   **Suggestion**: Simplify to:
   - **R key only**: Rotate around Y-axis (vertical) in 90° increments
   - **Hold Shift + R**: Rotate around other axes if needed
   - Visual compass showing current rotation angle

### [] 7. Add Smart Welding
*   **Issue**: Manual welding with Z key requires precise positioning and knowledge.
*   **Suggestion**: Implement automatic welding when objects are placed adjacent to each other:
   - Auto-weld when objects touch and are aligned
   - Visual indicators showing successful connections
   - "Weld All Touching" button for bulk operations

### [] 8. Implement Building Zones
*   **Issue**: Objects can be built anywhere, potentially blocking paths or other players.
*   **Suggestion**: Define buildable areas where:
   - Grid snapping is enforced
   - Terrain automatically provides foundation points
   - Clear boundaries prevent building in restricted areas