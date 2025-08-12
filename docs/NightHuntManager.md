# Night Hunt Mechanic: Night-only Mummy Spawns Around Players

This guide describes how to add a simple, reliable, industry-standard “Night Hunt” system that:
- Spawns only Mummies around each player during NIGHT.
- Spawns one Mummy every 3 seconds per player at a 100-stud radius.
- Forces immediate aggro toward that player (per-instance overrides).
- Enforces per-player and global caps, and respects the existing AI budget.
- Cleans up all live Night Hunt Mummies at sunrise (Phase 1: destroy). Optionally pools them (Phase 2) to reuse next night.

Use this as a checklist and reference while coding. It avoids editing global AI behavior and integrates cleanly with your existing systems.

---

## 1) Goals and Constraints

- Gameplay
  - Pressure players at night with periodic, targeted Mummy spawns.
  - Maintain consistent challenge without swarming or hitching.
- Simplicity & Reliability
  - A single server-side manager that starts on NIGHT and stops on DAWN/SUNRISE.
  - No changes to global AIConfig values; use per-instance overrides for special behavior.
- Performance
  - Respect AIManager’s global creature limits.
  - Enforce per-player and global caps for Night Hunt spawns.
  - Phase 1: destroy on sunrise for minimal changes; Phase 2: add pooling to reduce churn.

---

## 2) Files to Add

- docs/NightHuntManager.md (this document)
- src/shared/config/ai/NightHuntConfig.lua (new)
- src/server/ai/NightHuntManager.lua (new)

No changes to DayNightCycle are strictly required (we’ll poll period once per second). You may later add a server-side PeriodChanged signal for event-driven transitions.

---

## 3) Configuration (NightHuntConfig.lua)

Create a new config to keep tuning centralized and safe:

- IntervalSeconds: 3
- Radius: 100
- PerPlayerCap: 8 (recommended; tune as desired)
- GlobalCap: 50 (tune according to AI budget)
- DetectionRangeOverride: 100 (ensures immediate aggro from the ring)
- UsePooling: false (Phase 1). Set to true after Phase 2 is implemented.
- MaxGroundRaycast: 30 (studs)
- MaxPlacementAttempts: 4 (tries per spawn tick to find valid ground)
- MinPlayerClearance: 10 (studs, don’t drop on player)
- DespawnOnSunrise: "Destroy" | "Pool"

File: src/shared/config/ai/NightHuntConfig.lua

Example content (values only; implement the file during coding):
- Returns a table with the fields above.

Notes
- Keeping this separate avoids changing AIConfig or other systems.
- Values are safe defaults; adjust to taste.

---

## 4) Manager Design (NightHuntManager.lua)

Responsibilities
- Watch current period and start/stop Night Hunt loops.
- Maintain per-player state and spawned controllers.
- Enforce caps and interact with AIManager creature budget.
- Clean up on sunrise, player leave, or errors.

Internal State
- active: boolean (true if NIGHT)
- perPlayer:
  - key: player.UserId
  - value: { loopConn/Task, spawned = { aiController, ... } }
- totalActiveNightHunt: integer (derived from all spawned lists)

Public API
- NightHuntManager.init()
- NightHuntManager.start()
- NightHuntManager.stop()
- NightHuntManager.getDebugInfo() -> { active, totals, perPlayerCounts }

Lifecycle
1) init():
   - Bind Players.PlayerAdded/Removing for setup/cleanup.
   - Start a 1-second monitor loop that checks DayNightCycle.getCurrentPeriod().
   - If period == NIGHT and not active: start(); if transitions to DAWN/SUNRISE and active: stop().
   - On init, if already NIGHT: start immediately.
2) start():
   - active = true.
   - For each current player, create a per-player spawn loop (3s cadence).
3) stop():
   - active = false.
   - Stop all per-player loops.
   - Cleanup all live Night Hunt Mummies (see Cleanup Strategy below).

Per-Player Spawn Loop (every 3 seconds)
- Preconditions:
  - NightHuntManager.active is true.
  - Player character exists and has PrimaryPart.
  - AIManager:getCreatureCount() < AIConfig.Settings.MaxCreatures.
  - totalActiveNightHunt < NightHuntConfig.GlobalCap.
  - perPlayerSpawnedCount < NightHuntConfig.PerPlayerCap.
- Placement:
  - Choose random angle in [0, 2π) and compute target position at Radius.
  - Set testY to characterY + SpawnHeight (or a safe constant like +20) and raycast downward up to MaxGroundRaycast.
  - Ensure:
    - We hit ground; 
    - Distance to player >= MinPlayerClearance;
    - No immediate obstacles (optional: check a small sphere/cylinder clearance if needed).
  - Try up to MaxPlacementAttempts; if all fail, skip this tick.
- Spawn:
  - CreatureSpawner.spawnCreature("Mummy", position, { activationMode = "Event" }).
  - If nil, skip.
- Per-instance overrides & aggro:
  - aiController.detectionRange = NightHuntConfig.DetectionRangeOverride.
  - aiController:setBehavior(ChasingBehavior.new(player)) to immediately pursue the player.
  - Tag the model/controller: add attribute Model:SetAttribute("NightHunt", true) or a CollectionService tag (e.g., NIGHT_HUNT).
  - Track controller in perPlayer[userId].spawned.
- Housekeeping:
  - Connect model.AncestryChanged or humanoid.Died to remove from tracking.

Cleanup Strategy
- On stop() (sunrise) or player leave:
  - Iterate tracked controllers for player (or all if sunrise):
    - If NightHuntConfig.UsePooling and pooling is implemented for Mummy (Phase 2):
      - CreaturePoolManager.poolCreature(model, "Mummy").
    - Else:
      - If model exists and Parent, destroy immediately.
  - Clear perPlayer[userId].spawned.

Edge Cases
- Server starts during NIGHT: monitor loop will detect NIGHT and start immediately.
- Player joins during NIGHT: per-player loop starts automatically.
- Player dies: loop keeps running and uses their current character when it respawns.
- Budget pressure: gracefully skip spawns when any cap hits.

---

## 5) Immediate Aggro Without Editing AI Classes

Existing classes do not expose setter methods, but they support:
- aiController.detectionRange = <number> (BaseCreature stores this and behaviors respect it).
- aiController:setBehavior(ChasingBehavior.new(player)) to force chasing state.

This keeps AIConfig as the baseline and applies one-off changes for Night Hunt instances only.

---

## 6) Phase 2: Optional Pooling for Mummy

Motivation
- Reduce instance creation/destruction across nights to avoid GC hitches.

Steps
1) Update CreaturePoolManager config to include Mummy:
   - Add to PoolConfig.PooledCreatures, MaxPopulation, RespawnDelay (e.g., MaxPopulation.Mummy = 40, RespawnDelay.Mummy = 12).
2) Implement respawn path for humanoids:
   - Implement respawnFromPool(creature, "Mummy"):
     - Reset all physics: Anchored=false, velocities=0, CanCollide=true.
     - Reset humanoid: Health=MaxHealth, WalkSpeed from AIConfig.
     - Ensure PrimaryPart, clear non-essential constraints if needed.
     - Parent to Workspace.
     - Create HostileCreature controller using the existing model (no clone) and position it.
   - Implement spawnNewCreature("Mummy") fallback via CreatureSpawner if pool empty (or keep as is).
3) NightHuntManager spawn flow prefers pooled models:
   - local pooled = CreaturePoolManager.getPooledCreature("Mummy")
   - If exists: respawnFromPool; else: spawn via CreatureSpawner.
4) Sunrise cleanup path pools live models instead of destroying when UsePooling = true.

Notes
- Keep Phase 1 shippable by using destroy-at-sunrise, then add pooling once gameplay is validated.

---

## 7) Testing Checklist

Functional
- Start the server during DAY → no Night Hunt spawns.
- When NIGHT begins → spawns start within 3 seconds.
- Spawns appear at ~100-stud ring around active players; immediate chase.
- Caps:
  - Per-player never exceeds PerPlayerCap concurrently.
  - Global never exceeds GlobalCap; spawns pause when at cap.
- At DAWN/SUNRISE → all live Night Hunt mummies are cleaned up.
- Death behavior: Mummies ragdoll and do not drop loot (as current BaseCreature’s ragdoll path).

Robustness
- Player joins during NIGHT → they start receiving spawns.
- Player leaves during NIGHT → their mummies are cleaned up without affecting others.
- AI budget pressure → spawns skip (no errors) when close to AIConfig.Settings.MaxCreatures.
- Placement edge cases: raycast failure causes skip for that tick; loop continues next tick.

Performance
- No noticeable stutters during periodic spawns at 3-second cadence across several players.
- Optional: enable AI debug stats to confirm budgets and LOD are respected.

---

## 8) Rollout Plan

- Phase 1 (MVP):
  - Add NightHuntConfig.lua and NightHuntManager.lua.
  - Wire NightHuntManager.init() from your server bootstrap (e.g., ChunkInit.server.lua after AIManager init).
  - Validate gameplay, caps, and cleanup.

- Phase 2 (Optimization):
  - Extend CreaturePoolManager for Mummy pooling and implement respawnFromPool.
  - Flip NightHuntConfig.UsePooling = true.
  - Profile across multiple night/day cycles for GC reductions.

---

## 9) Optional Improvements

- Event-driven period transitions:
  - Add a server Signal (BindableEvent) to DayNightCycle for PeriodChanged and emit alongside client RemoteEvent.
  - Subscribe in NightHuntManager to eliminate the 1-second poll.
- Dynamic difficulty:
  - Scale PerPlayerCap by player kill count or time survived.
- Spawn ring shaping:
  - Bias to the player’s forward arc; keep some behind for surprise.
- Attribute-driven observability:
  - Lighting:SetAttribute("NightHuntActive", active)
  - Lighting:SetAttribute("NightHuntTotal", totalActiveNightHunt)

---

## 10) Integration Pointers

- Bootstrap: add a single line where you initialize AI systems, e.g.:
  - local NightHuntManager = require(script.Parent.ai.NightHuntManager)
  - NightHuntManager.init()
- Use existing services/modules:
  - DayNightCycle.getCurrentPeriod()
  - CreatureSpawner.spawnCreature()
  - AIManager:getCreatureCount(), :registerCreature()
  - CollectionService for tagging NIGHT_HUNT (optional)

---

## 11) Troubleshooting

- No spawns at night
  - Verify NightHuntManager.init() is called.
  - Check DayNightCycle.getCurrentPeriod() returns "NIGHT" during testing (use prints or a debug command).
- Mummies don’t chase
  - Ensure aiController.detectionRange is set after spawn.
  - Call aiController:setBehavior(ChasingBehavior.new(player)).
  - Confirm player has Character/PrimaryPart.
- Hitting global caps too soon
  - Lower PerPlayerCap or GlobalCap, or raise AIConfig.Settings.MaxProceduralCreatures/MaxCreatures carefully.
- Despawn doesn’t clear all
  - Ensure tagging/attributes are applied on spawn, and cleanup iterates tracked controllers.

---

By following this guide, you’ll implement the Night Hunt mechanic with clear responsibilities, minimal coupling, and a straightforward upgrade path to pooling.

