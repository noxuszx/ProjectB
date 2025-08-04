# RangedHostile NPCs Implementation Plan

Implementation plan for adding reliable, performant ranged enemies that fit the existing AI + weapon architecture.

## Phase 1 – Design

### 1. Creature Archetype
- **New class**: `RangedHostile.lua` extends `HostileCreature`
- **New config entry** per enemy (e.g. SkeletonArcher) in `AIConfig.CreatureTypes` with fields:
  - `Damage` - Projectile damage amount
  - `ProjectileSpeed` - Speed of projectile travel
  - `FireCooldown` - Time between shots
  - `OptimalRange` - Preferred distance to maintain (e.g. 35 studs)
  - `MaxRange` - Maximum shooting distance (e.g. 120 studs)

### 2. Behaviors
- **`RangedChasing`** – moves toward player until inside OptimalRange, keeps LOS, no touch damage
- **`RangedAttack`** – fires projectile, waits FireCooldown
- Both inherit from base `AIBehavior` so they plug into current behavior system

### 3. Projectile Implementation
- Re-use hitscan raycast pattern already in `Crossbow` and `WeaponTest.server.lua`
- Encapsulate in `ProjectileService` ModuleScript (server-side) for reuse by NPCs & players

### 4. Networking / Security
- Server-only projectile & damage; clients receive RemoteEvent for visuals (tracer, sound)

### 5. Performance Safeguards
- Respect AIManager's LOD: in Far LOD, skip aiming; Medium LOD: lower fire rate
- Pool projectile parts; Debris after lifetime

## Phase 2 – Code Scaffolding

### 1. Core Classes
- `src/server/ai/creatures/RangedHostile.lua`
  - Inherits `HostileCreature`, overrides `update()` to swap behaviors

### 2. Behavior Classes
- `src/server/ai/behaviors/RangedChasing.lua`
  - Stops at OptimalRange, keeps facing
- `src/server/ai/behaviors/RangedAttack.lua`
  - On `enter`, start cooldown timer
  - On `update`, if LOS and cooldown ≤0 then call `ProjectileService:fire(...)`

### 3. Services
- `src/server/services/ProjectileService.lua` (or under `shared/modules`)
  - `fire(origin, targetPos, config)` returns projectile instance
  - Does raycast, applies damage via `WeaponTest` remote

### 4. Configuration Updates
- Append new creature configs (e.g. SkeletonArcher) and optionally generic defaults in `AIConfig.lua`

### 5. Spawner Updates
- Add new creature types to `CreatureSpawning.lua` weights

## Phase 3 – Testing

### 1. Unit Testing
- Unit-test ProjectileService separately with test NPC & dummy humanoid targets

### 2. Performance Testing
- Spawn 50+ ranged NPCs, watch AIManager stats; confirm <5 ms frame budget
- Verify LOD throttling: Far → no shooting, Medium → half fire rate, Close → full fire rate

### 3. Stress Testing
- Stress-test pooled projectiles (1000 shots/min) for memory leaks

### 4. QA Checklist
- LOS checks working correctly
- No self-damage to NPCs
- Cooldown respected between shots
- Damage numbers match config values

## Phase 4 – Polish

### 1. Audio/Visual Effects
- Add sound & particle RemoteEvents (client-side only)

### 2. Animations
- Tweak animation sets for bow-draw / shoot

### 3. Balance
- Balance numbers in `AIConfig` after live profiling

## Phase 5 – Documentation

### Updates Required
- Update README with new ranged creature types
- Update AI architecture docs to describe new behaviors and configs

## Implementation Notes

This plan keeps code modular, config-driven, and aligned with existing:
- LOD & behavior framework
- Class-based inheritance system
- Performance optimization patterns
- Security model (server-authoritative)

**Benefits:**
- Simple, reliable, and industry-standard approach
- Reuses existing weapon/projectile patterns
- Integrates seamlessly with current AI architecture
- Performance-conscious from the start