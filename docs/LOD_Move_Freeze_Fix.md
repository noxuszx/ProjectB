# Villager Freeze Bug – Root Cause & Fix

## 1. Symptom
* Villagers roam correctly when the player is close.
* As soon as the player walks far enough for the creature to enter **Far** LOD, villagers with debug string `Roaming:Moving` stop walking – they appear frozen, keeping the MoveTo target forever.
* Villagers in `Roaming:Idling` still behave normally.

## 2. Root Cause
| Layer | Where | What happens |
|-------|-------|--------------|
| LOD update | `AIManager.updateCreatureLOD()` | Sets `creature.lodLevel` + a low `lodUpdateRate` (e.g. 0.5 Hz) when distance > *Far* threshold.  Also sets `creature.lodNextUpdate` = now + 1/rate. |
| Frame loop | `AIManager.updateAllCreatures()` | A creature is queued for update **only if**<br>`lodUpdateRate >= 30` **OR** `currentTime >= lodNextUpdate`.  Far creatures therefore update once every 2–5 s. |
| Behaviour think | `Roaming:update()` | If called, picks a waypoint, calls `Humanoid:MoveTo()`, sets `state = "Moving"`. |
| Move follow-up | also in `Roaming:update()` | Checks `Humanoid.MoveToFinished`; if complete, switches `state` back to `Idling`. **This code is skipped whenever the behaviour `update()` is skipped.** |

Result: once a Far creature enters the Moving sub-state, the follow-up never runs until the next low-frequency think window, so the NPC appears stuck.

## 3. Fix Strategy
Split behaviour processing into two tiers:
1. **Think / Plan** – expensive path-finding & decision logic (keep gated by LOD).
2. **Movement follow-up** – cheap check that must run every frame (or at least Heartbeat) even for low LOD.

## 4. Implementation Steps
1. **Add per-frame follow-up hook to BaseCreature**
```lua
-- BaseCreature.lua (inside update())
if self.currentBehavior and self.currentBehavior.followUp then
    self.currentBehavior:followUp(self, deltaTime)
end
```
*Call this **before** the LOD-gated think.*

2. **Refactor behaviours**
*Example for Roaming.lua*
```lua
function Roaming:update(creature, dt)  -- expensive think
    if creature.state == "Idling" then
        self.idleTime -= dt
        if self.idleTime <= 0 then
            self:chooseWaypoint(creature)
        end
    end
end

function Roaming:followUp(creature, dt) -- cheap MoveTo completion
    if creature.state == "Moving" then
        local humanoid = creature.model:FindFirstChild("Humanoid")
        if humanoid and humanoid.MoveToFinished and humanoid.MoveToFinished == true then
            creature.state = "Idling"
            self.idleTime = math.random(2,5)
        end
    end
end
```
3. **Leave AIManager LOD gating unchanged** – only the **think** path is skipped when Far; `followUp` runs every Heartbeat.

## 5. Outcome
* Villagers continue to finish MoveTo waypoints and pick new ones even in Far LOD.
* Server still saves CPU because expensive path-finding is still throttled.
* Debug GUI now flips between `Roaming:Moving` and `Roaming:Idling` at any distance.

