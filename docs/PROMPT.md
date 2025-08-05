Refactor Plan: Incremental, Frame-Budgeted World Bootstrap
==========================================================

Goal  
Smooth initial server load so no single frame clones or processes too many instances. Each major system will operate in controllable batches (tunable per device tier).

--------------------------------------------------------------------
1. Shared Utilities
--------------------------------------------------------------------
Task 1.1  Create `utilities/FrameBatched.lua`

• Exports  
  – `run(list, perFrame, fn)` – generic helper described below  
  – `wrap(iterator, perFrame, fn)` – variant for on-the-fly generation

Implementation sketch
```lua
local RunService = game:GetService("RunService")

local function run(list, perFrame, fn)
    local i = 1
    while i <= #list do
        for n = 1, math.min(perFrame, #list - i + 1) do
            fn(list[i])
            i += 1
        end
        RunService.Heartbeat:Wait()
    end
end

local function wrap(iterator, perFrame, fn)
    local count = 0
    for value in iterator do
        fn(value)
        count += 1
        if count >= perFrame then
            RunService.Heartbeat:Wait()
            count = 0
        end
    end
end

return { run = run, wrap = wrap }
```
--------------------------------------------------------------------
2. VillageSpawner.lua
--------------------------------------------------------------------
Task 2.1  Add `villageConfig.BATCH_SIZE` (default = 1-2 structures per frame).

Task 2.2  Change `spawnVillages()`:

• Build list `villageJobs = {chunkPos1, chunkPos2, …}`  
• Replace `for … do spawnVillage()` loop with  
  local FrameBatched = require(ReplicatedStorage.Shared.utilities.FrameBatched)
  FrameBatched.run(villageJobs, villageConfig.BATCH_SIZE, function(pos)
      spawnVillage(models, pos)
  end)
• Remove internal `task.wait` inside `spawnVillage` (we no longer need micro-delays there).

--------------------------------------------------------------------
3. SpawnerPlacement.lua
--------------------------------------------------------------------
Task 3.1  Add `SpawnerPlacementConfig.PerFrame = 10` (number of chunks to scan each frame).

Task 3.2  In `run()` replace double-for loops with an iterator that yields chunk coordinates; feed into `FrameBatched.wrap(iterator, PerFrame, placeSpawnersForChunk)`.

--------------------------------------------------------------------
4. CustomModelSpawner.lua
--------------------------------------------------------------------
Task 4.1  Add `ModelSpawnerConfig.PER_FRAME = { Vegetation = 10, Rocks = 5, Structures = 1 }`

Task 4.2  Inside `spawnInChunk`:

• Accumulate candidates (`toSpawn`) per category.  
• Invoke `FrameBatched.run(toSpawn, PER_FRAME[category], spawnModel)`.

--------------------------------------------------------------------
5. CreatureSpawner.populateWorld()
--------------------------------------------------------------------
Task 5.1  Similar pattern—spawn `PER_FRAME_CREATURES` let’s say 3 per frame.

--------------------------------------------------------------------
6. ChunkInit.server.lua Sequencing
--------------------------------------------------------------------
Task 6.1  Remove fixed `task.wait(x)` calls after each heavy step.

Task 6.2  The revised order remains:
1. Terrain + chunks  
2. `VillageSpawner.spawnVillages()` (batched)  
3. `SpawnerPlacement.run()` (batched)  
4. `CustomModelSpawner.init()` (batched)  
5. Items → AI systems

Because each heavy call now yields every frame, the script can run them synchronously without long stalls—no extra waits needed except perhaps a final `wait(0.1)` before enabling AI.

--------------------------------------------------------------------
7. Configuration Defaults
--------------------------------------------------------------------
• `FrameBudgetConfig.lua` (new): central place that holds default per-frame numbers, with mobile multipliers (e.g., divide by 2 for low-end).

--------------------------------------------------------------------
8. Telemetry (optional but recommended)
--------------------------------------------------------------------
Task 8.1  Add simple FPS / job-queue length logging every 5 s so you can tune batch sizes.

--------------------------------------------------------------------
9. Testing Checklist
--------------------------------------------------------------------
1. Enable “Show Performance Stats” in Studio; verify server FPS stays ≥ 55.  
2. Measure time from server start to “All systems initialized” print; should be similar but smooth (no big frame spikes).  
3. Join on low-end mobile client; ensure streaming of instances feels gradual (no long “Requesting” black screen).  
4. Verify functional behaviour (villages present, spawners placed, props visible).  
5. Stress-test with render-distance ×2; tune batch sizes if FPS dips.

--------------------------------------------------------------------
10. Roll-out Strategy
--------------------------------------------------------------------
• Implement utility and refactor one system (villages) first → test.  
• Incrementally convert the other systems.  
• Expose batch sizes in config objects to tweak live without code edits.

Follow this plan and the initialisation load will be spread over several dozen frames instead of 1-2, eliminating hitch risks while preserving current content.