# Village Spawning: Changes, Configuration, and Roadmap

This document summarizes the recent improvements to village spawning, how to configure/tune them, and a roadmap for follow-up testing and enhancements.

---

## What We Changed

1) Switched placement to Model:PivotTo
- Files: `src/server/spawning/VillageSpawner.lua`
- Replaced `SetPrimaryPartCFrame` with `PivotTo` for model placement and bounding-box calculations.
- Benefits: safer placement (no need to set PrimaryPart), correct pivot-based orientation, fewer edge cases.

2) Spawner placement distance checks now use GetPivot
- Files: `src/server/ai/SpawnerPlacement.lua`
- Replaced `village.PrimaryPart.Position` with `village:GetPivot().Position` to measure distance from villages.
- Ensures spawners still avoid villages after the `PivotTo` switch.

3) Rotation improvements
- Files: `src/server/spawning/VillageSpawner.lua`
- CENTER_FACING now uses `CFrame.lookAt` to face the center (campfire), with optional `angle_offset`.
- CARDINAL now selects the nearest cardinal yaw that faces inward, preserving the cardinal style while pointing toward the center.
- Config: You can globally adjust facing via `ROTATION_SETTINGS.CARDINAL.angle_offset`.

4) Main-street layout (A/B tested)
- Files: `src/server/spawning/VillageSpawner.lua`, `src/shared/config/Village.lua`
- New A/B layout that creates two inward-facing rows (“western town” street) with organic spacing, occasional gaps, and optional T-intersection.
- Still uses collision/overlap checks and falls back to scatter when needed.
- Mandatory structures fill the closest valid slots first; optionals fill outward for a denser town core.

---

## Configuration

Edit `src/shared/config/Village.lua`.

Key fields:
- `ROTATION_MODE`: keep `"CARDINAL"` to retain cardinal snapping.
- `ROTATION_SETTINGS.CARDINAL.angle_offset`: set to `180` if models initially face the wrong direction (flip), or `90/-90` depending on asset orientation.

A/B layout:
- `LAYOUT_AB_TEST_PROB`: probability [0..1] per village to use the main-street layout. Set to `1.0` to force for testing; dial back later (e.g., `0.5`).
- `MAIN_STREET`:
  - `HalfWidth` (default 20): distance from street centerline to each row center.
  - `FrontageSpacing` (default {18, 26}): spacing between adjacent buildings along the row.
  - `JitterAlong` (default 3): small +/- along-street jitter to avoid perfect alignment.
  - `JitterSetback` (default 2): small +/- offset toward/away from the street centerline.
  - `SkipChance` (default 0.12): probability to skip a slot (empty lot effect).
  - `TIntersectionChance` (default 0.4): probability to add a short perpendicular “T” near the center.
  - `TCrossLengthRatio` (default 0.5): relative length of the T’s short perpendicular.

---

## Testing Checklist

Basic verification:
- Villages spawn without errors in output.
- Spawners do not appear within village avoidance radii (still respected after `GetPivot` change).
- With `ROTATION_MODE = "CARDINAL"`, buildings snap to 0/90/180/270 and face inward (adjust `angle_offset` if reversed).

A/B layout:
- Set `LAYOUT_AB_TEST_PROB = 1.0` to force main-street layout while tuning.
- Tune `HalfWidth` (e.g., 18–24) to set street feel; ensure no collisions across rows.
- Tune `FrontageSpacing` (narrower for denser blocks). Check for overlap and visual density.
- Adjust `SkipChance` to introduce organic empty lots (e.g., 0.12–0.2).
- Verify T-intersections appear at the target frequency (`TIntersectionChance`) and don’t intersect buildings.

Performance:
- Observe frame times during generation; FrameBatched should keep frame budget stable.
- If you notice heavy CPU during placement, we can cache bounding boxes per structure/rotation (planned below).

---

## Known Limitations / Notes

- Model forward direction is defined by pivot orientation now. If an individual model’s “front” is off, either fix the pivot in Studio or add a per-structure yaw correction (see Roadmap).
- The main-street generator tries best-effort slots first, then falls back to scatter for any remaining buildings that don’t fit, to ensure village completion.

---

## Roadmap / Next Improvements

1) Bounding box caching
- Cache per-structure bounding box sizes (and optionally per cardinal orientation) to avoid repeated clone+GetBoundingBox during placement attempts.
- Benefit: less CPU during heavy placement (esp. large villages).

2) Per-structure facing offsets
- Add an optional map (e.g., `FRONT_OFFSETS = { House1 = 180, Shop1 = 0 }`) to fine-tune each asset’s front yaw relative to the chosen direction.
- Keeps global `angle_offset` for broad defaults, with per-asset overrides.

3) Smarter slot selection
- Prefer wider-frontage structures for larger slots automatically; smaller structures can fill tighter gaps.
- Could be heuristic-only (no size data) or read approximate widths from cached bounds.

4) Street variety
- Rare cross streets (+ intersections) vs T streets only, controlled by config.
- Add square/plaza option: occasional open area near campfire with tighter clusters around it.

5) Village spacing & deduplication
- We implemented min-distance enforcement; consider setting `MIN_VILLAGE_DISTANCE` in config to a non-zero value for better spread.
- Deduplicate village job chunk positions when building the job list (minor improvement).

6) Root tagging
- We already tag descendants as protected. Optionally also tag the village root model itself to make protection filters even more consistent across systems.

7) Telemetry / debug tools
- Add counters and labels: number of slots generated/used/skipped, success rate per layout mode.
- Optional debug rendering of slot positions and street centerlines (e.g., adornments/parts in a debug mode).

8) Asset curation / pivots
- Standardize pivots so all storefronts share the same forward axis, reducing config fiddling.

---

## Quick How-To

- Force main-street layout for testing:
  - `src/shared/config/Village.lua`: set `LAYOUT_AB_TEST_PROB = 1.0`.
- Make the street narrower or wider:
  - `MAIN_STREET.HalfWidth = 18` (narrow) or `24` (wider).
- Increase density:
  - Reduce `FrontageSpacing` min/max slightly and reduce `STRUCTURE_SPACING` cautiously.
- More organic feel:
  - Increase `SkipChance` and/or `JitterAlong`/`JitterSetback` a bit.
- Flip global facing:
  - Adjust `ROTATION_SETTINGS.CARDINAL.angle_offset` (commonly 0, 90, 180, -90).

---

If you want, we can next implement bounding box caching and per-structure facing offsets, then iterate on spacing to dial in the exact “western main street” vibe you have in mind.

