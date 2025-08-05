# RangedHostile NPC Performance Optimization Guide

Optimization guide for fixing laggy movement, missing animations, and jerky rotation in RangedHostile NPCs.

## Current Issues Identified

1. **Laggy/stuttering movement** - NPCs move in a jerky, unsmooth fashion
2. **No animations playing** - Walk cycles and other animations don't execute
3. **Snap-turns/unsmooth rotation** - NPCs instantly teleport-rotate instead of smoothly turning

## Problem Analysis & Solutions

### 1. Laggy Movement Issues

#### Instant Turn and Flee
- **Issue**: NPCs instantly turn away and flee when players get too close.
- **Performance Concern**: This abrupt transition can be non-performant and lead to animation hitches.
- **Solution**: Allow a short delay or smoother transition for fleeing behavior. find a way for this to be performant.

#### A. Network Ownership Problems
- **Issue**: Client may own NPC physics simulation, causing server-client conflicts
- **Solution**: Force server ownership in spawner
```lua
-- In CreatureSpawner.spawnCreature()
creatureModel.PrimaryPart:SetNetworkOwner(nil)
```

#### B. MoveTo Thrashing
- **Issue**: Calling `Humanoid:MoveTo` every frame overwhelms pathfinding
- **Current**: `RangedChasing:update` calls `moveTowards` → `MoveTo` at 60 Hz
- **Solution**: Debounce MoveTo calls - only when goal changes >1 stud or humanoid stuck
```lua
-- Cache last MoveTo goal on behavior object
if not self.lastMoveGoal or (newGoal - self.lastMoveGoal).Magnitude > 1 then
    humanoid:MoveTo(newGoal)
    self.lastMoveGoal = newGoal
end
```

### 2. Snap-Turn Rotation Issues

#### Current Problem Code
```lua
-- This causes instant teleport-rotation at 60 Hz:
creature.model:SetPrimaryPartCFrame(CFrame.lookAt(...))
```

#### Solution A: Use Humanoid AutoRotate (Recommended)
```lua
-- Let Roblox handle smooth turning during movement
humanoid.AutoRotate = true
-- Just call MoveTo - rotation happens automatically
humanoid:MoveTo(goalPosition)
```

#### Solution B: Gradual CFrame Interpolation (For Stationary)
```lua
local function smoothFace(model, targetPos, turnRate, deltaTime)
    local root = model.PrimaryPart
    local desired = (targetPos - root.Position).Unit
    desired = Vector3.new(desired.X, 0, desired.Z) -- Y-axis only
    local current = root.CFrame.LookVector
    local alpha = math.clamp(turnRate * deltaTime, 0, 1)
    local newDir = current:Lerp(desired, alpha).Unit
    local newCf = CFrame.lookAt(root.Position, root.Position + newDir)
    root.CFrame = newCf
end

-- Call at ~15 Hz when in RangedAttack behavior
if self.lastTurnUpdate + 0.067 < currentTime then -- ~15 FPS
    smoothFace(creature.model, targetPosition, 2.0, deltaTime)
    self.lastTurnUpdate = currentTime
end
```

#### Solution C: LOD-Based Rotation Skipping
```lua
-- Skip rotation entirely when far from players
if creature.lodLevel == "Far" then
    return -- Don't waste CPU on distant NPCs
end
```

## Implementation Priority

### High Priority (Fix First)
1. **Network Ownership**: Add `SetNetworkOwner(nil)` to spawner
2. **MoveTo Debouncing**: Cache last MoveTo goal in behaviors
3. **Use AutoRotate**: Enable `humanoid.AutoRotate = true`

### Medium Priority
4. **Weapon Part Optimization**: Set CanCollide=false, Massless=true
5. **Animation Debug**: Add loading verification prints
6. **Smooth Face Function**: For stationary aiming

### Low Priority
7. **LOD-Based Skipping**: Skip updates when far from players
8. **Client-Side Animations**: Move animation system to LocalScript

## Code Changes Required

### Files to Modify:
1. `src/server/ai/CreatureSpawner.lua` - Add network ownership
2. `src/server/ai/behaviors/RangedChasing.lua` - Debounce MoveTo, enable AutoRotate
3. `src/server/ai/behaviors/RangedAttack.lua` - Replace snap-turn with smooth face
4. `src/server/ai/creatures/RangedHostile.lua` - Animation debug, weapon optimization

### Testing Checklist After Implementation:
- [ ] NPCs move smoothly without stuttering
- [ ] NPCs turn smoothly toward targets
- [ ] Performance remains acceptable with 10+ NPCs
- [ ] Projectiles still fire from weapon muzzle correctly
- [ ] No network ownership conflicts in multiplayer

## Performance Monitoring

### Metrics to Watch:
- Server FPS with multiple NPCs active
- Network data usage (should be lower after fixes)
- Animation track memory usage
- Pathfinding service load

### Debug Commands:
```lua
-- Enable to monitor behavior changes:
AIConfig.Debug.LogBehaviorChanges = true

-- Check network ownership:
print("Owner:", creature.model.PrimaryPart:GetNetworkOwner())

-- Monitor MoveTo frequency:
print("MoveTo calls per second:", moveToCallCount / elapsed)
```

This optimization approach addresses root causes rather than symptoms, ensuring smooth, performant ranged NPCs that integrate well with the existing AI architecture.
