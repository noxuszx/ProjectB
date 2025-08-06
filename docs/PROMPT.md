High-level refactor plan for SpawnerPlacement & Creature population
===================================================================

A. Remove noise-based biome logic  
   • Set `SpawnerPlacementConfig.Settings.UseNoiseBasedSpawning = false`  
   • Delete the temperature / humidity / hostility code paths for clarity (or gate them with an `if` so they stay available for future).

B. 60 / 40 spawn-type ratio (Passive safer)  
   • Update `RandomSpawning.SpawnTypeProbabilities` →  
      `Safe = 0.60`  
      `Dangerous = 0.40`  
   • Add comment so designers know where to tune.

C. Spatial variance & occasional clustering  
   1. Allow up to 3 spawners per chunk  
      `Performance.MaxSpawnersPerChunk = 3`  
   2. Jitter placement inside a chunk  
      Replace current uniform `math.random(-chunkSize/2…)` with  

```lua
local baseX  = math.random(-chunkSize/2,  chunkSize/2)
local baseZ  = math.random(-chunkSize/2,  chunkSize/2)
local jitter = (math.random() - 0.5) * chunkSize * 0.4
offsetX = baseX + jitter
offsetZ = baseZ - jitter
```
   3. Variable clearance radius  
```lua
local clearance = SpawnerPlacementConfig.TerrainValidation.ClearanceRadius
                 * math.random(70,130) / 100   -- 0.7-1.3×

```
 Use `clearance` inside `isGoodSpacing`.

D. Creature population target  
   • Keep current ~70 initial creatures; after clustering some chunks will
     hold 1-3 spawners so total may rise to 100-120.  
   • Let QA play-test; if the world feels empty set
     `CreatureSpawnConfig.SpawnTypes.<type>.MinSpawns / MaxSpawns`
     slightly higher instead of forcing more spawners.

E. Config clean-up  
   • Remove the now-unused `NoiseSettings`, `SpawnAreaRules`,
     `BiomeThresholds` sections (or comment them out).

Implementation order
--------------------
1. Edit `SpawnerPlacing.lua`  
   • Set flag, adjust probabilities, bump `MaxSpawnersPerChunk`, add jitter & variable clearance.  
2. No code changes needed in `CreatureSpawner.lua`; it will simply see the new spawner mix.  
3. Play-test, watch server console:  
   `[SpawnerPlacement] Spawners placed: N` should increase ~3× current.  
   Validate creature count with `workspace.SpawnedCreatures` child count.  
4. If total creatures exceed 120 and cause perf issues, lower
   `MaxSpawnersPerChunk` back to 2.

This keeps the system simple (pure random with designer-controlled ratios) while giving the terrain a more organic feel.