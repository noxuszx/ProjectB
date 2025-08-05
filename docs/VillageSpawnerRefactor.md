# Village Spawner Upgrade Plan

This document describes the tasks required to give every village a fixed **core layout**:

* One central **Campfire** (exactly at the village centre)
* Exactly **one Shop1**, **one Shop2**, and **one Well** placed around the campfire
* Optional extra structures continue to spawn as before
* No overlaps, honouring the existing rotation system

---

## 0. Prerequisites

* All required models **Campfire**, **Shop1**, **Shop2**, **Well** exist in the `villageConfig.VILLAGE_MODEL_FOLDER` path.
* The minimum structure count in `villageConfig.STRUCTURES_PER_VILLAGE` must be **≥ 4**.

---

## 1. Configuration Updates (VillageConfig.lua)

| Key | Purpose | Suggested Value |
|-----|---------|-----------------|
| `MANDATORY_STRUCTURES` | List of models that **must** appear once per village | `{ "Shop1", "Shop2", "Campfire", "Well" }` |
| `CAMPFIRE_BUFFER` | Minimum gap (studs) between the campfire and any other structure | `40` |

Steps:
1. Open `src/shared/config/Village.lua` (or equivalent).
2. Append the two new fields shown above.
3. Ensure `STRUCTURES_PER_VILLAGE[1]` (min) is set to at least **4**.

---

## 2. VillageSpawner.lua Refactor

### 2.1  Helper Functions

* `placeCampfire(models, villageCenter, occupiedRects)`
  * Clones **Campfire**, positions it at `villageCenter` (Y = terrain height).
  * Builds its AABB, expands it by `CAMPFIRE_BUFFER`, pushes into `occupiedRects`.
  * Returns `placementInfo` or `nil`.

* `placeMandatory(models, name, occupiedRects)`
  * Attempts up to `MAX_ATTEMPTS` (reuse value 10) to place the given model using the existing candidate-search algorithm.
  * On success, inserts its rect into `occupiedRects` and returns info; else `nil`.

### 2.2  Updated `spawnVillage` Flow

1. **Select centre** – keep using the current `chunkPosition`.
2. **Place Campfire** – call `placeCampfire`. Abort the entire village if it fails.
3. **Place Shops & Well** – loop through the remaining mandatory list:
   * If any fails → abort village and try another chunk.
4. **Optional Structures** – continue existing random selection, but subtract the number of mandatory structures already placed if you want to keep the original total; otherwise allow extras.
5. **Overlap Checks** – unchanged logic, now works with the enlarged `occupiedRects` list.

### 2.3  Other Code Tweaks

* When building rects, buffer =
  * `STRUCTURE_SPACING` (8) for everything **plus**
  * `CAMPFIRE_BUFFER` only for the campfire.
* Campfire rotation: **none** (identity).
* Shops / Well: honour `villageConfig.ROTATION_MODE`.
* If a village aborts due to a mandatory placement failure, log a clear warning (`[VillageSpawner] Mandatory structure failed – skipping village`).

---

## 3. Testing Checklist

1. **Unit Test** – Run the spawner once in a blank world, verify:
   * Exactly one Campfire at each village’s centre.
   * Shop1, Shop2, Well all present and ≥ 40 studs from the campfire and ≥ 8 studs apart.
2. **Stress Test** – Spawn max-distance villages (edge of render distance) to ensure no placements violate the protected player spawn zone.
3. **Visual Review** – Fly around and confirm no overlaps or clipping.
4. **Performance** – Check spawn time hasn’t regressed noticeably.

---

## 4. Future Improvements

* Dynamic centre selection (random inside `VILLAGE_RADIUS`).
* Variable spacing per structure type.
* Village “blueprints” – lists of exact relative positions for themed layouts.

