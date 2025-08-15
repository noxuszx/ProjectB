# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Project: ProjectB — a Roblox desert survival game built with Rojo and Aftman-managed tooling.

- Primary tools: Aftman, Rojo 7.5.1, Node + Prettier (with Lua plugin)
- Project file: default.project.json (defines full DataModel tree and Remotes)

Common commands (pwsh/bash)
- Setup tooling
  - Install Aftman tools (adds rojo to PATH):
    - aftman install
  - Install JS dev dependencies (Prettier + Lua plugin):
    - npm ci
- Build/sync with Roblox Studio (Rojo 7.5.1)
  - Build a place file from default.project.json:
    - rojo build default.project.json -o ProjectB.rbxlx
  - Live-sync to Roblox Studio (start Studio, then run):
    - rojo serve default.project.json
- Formatting (Prettier)
  - Format everything:
    - npm run format
  - Check formatting only:
    - npm run format:check
  - Format Lua files only:
    - npm run format:lua
- Testing
  - No test framework detected (e.g., TestEZ not present). There is currently no configured command to run tests or a single test.

High-level architecture and structure
- DataModel layout (from default.project.json)
  - ReplicatedStorage
    - Shared: configuration, utilities, shared modules, tutorial content
    - Items, Money, NPCs (PassiveCreatures, HostileCreatures)
    - Remotes: pre-declared RemoteEvents/BindableEvents for gameplay systems (Backpack, TimeSystem, Creature health, Player stats, Weapons/Projectiles, Economy, Death/Revival, Arena, Admin, etc.)
    - Tools
  - ServerScriptService → Server: all server-side logic (src/server)
  - StarterPlayer → StarterPlayerScripts → Client: all client-side logic (src/client)
  - Workspace/Lighting/SoundService: base world defaults
- Code organization
  - src/client: player input, UI, visual effects, client-only controllers (e.g., backpack UI, economy UI, drag/drop client, ragdoll effects, tutorial and HUD components)
  - src/server: authoritative game logic (AI, spawning, economy, player services, environment, terrain, events, weapons, admin)
  - src/shared: configuration (gameplay, AI, economy, time, terrain), reusable utilities, and shared modules (including ZonePlus support modules)
  - tools/: individual Tool scripts (client/server) that integrate with core systems
- Remotes and networking (important)
  - All RemoteEvents/BindableEvents are defined statically in default.project.json under ReplicatedStorage/Remotes (and subfolders). Code should reference them via WaitForChild; avoid creating remotes at runtime.
  - Key groups include:
    - Economy: SellItem, BuyItem, UpdateMoney, RefreshBuyZones, CollectCash
    - Backpack/inventory: BackpackEvent, BackpackChanged, Drop/Pickup Item
    - TimeSystem: PeriodChanged, SyncTime
    - Combat/FX: WeaponDamage, ProjectileVisual, UpdateCreatureHealth
    - Player stats: UpdatePlayerStats; Death flow: ShowUI, RequestRespawn, RevivalFeedback
    - Arena flow: StartTimer, Pause/Resume, Sync, Victory, PostGameChoice
- Core system patterns (from README/CLAUDE)
  - AI system (src/server/ai)
    - Central coordinator (AIManager) manages creature lifecycle and updates
    - Registry (AICreatureRegistry) tracks all creatures; pooling (CreaturePoolManager) reuses models to prevent spikes
    - Performance: LODPolicy/ParallelLODActor lower update rates for far entities and batch work within budgets
    - Behaviors are modular (Roaming, Chasing, Fleeing, Ranged variants) and composed per creature class type (Passive/Hostile/etc.)
  - Terrain and world
    - ChunkManager drives procedural chunk-based terrain; frame budgeting in shared FrameBudgetConfig
  - Economy and trading
    - Server-side EconomyService plus handlers for buy/sell zones and pooled cash meshes; UI highlights affordability on client
  - Inventory (Backpack)
    - LIFO stack, pooled items, RemoteEvents for store/retrieve; UI now references Studio-authored elements (no dynamic Instance.new for UI)
  - Drag/drop and building
    - Client drag/weld systems with server validation; extensive use of CollectionService tags for interactables
- Configuration-driven design
  - src/shared/config and src/shared/config/ai define gameplay parameters, spawn weights, LOD distances, UI timings, economy values, etc. Systems read from these tables; adjust here rather than hardcoding.

Conventions and important rules (from CLAUDE.md)
- Prefer Roblox built-in services first (Humanoid/Seats, UserInputService, network ownership)
- Use proven community frameworks second (e.g., ZonePlus, ProfileService, Roact)
- Only build custom solutions when neither exists
- Performance-first patterns: reuse via pooling, batch updates with budgets, cache player positions, avoid runtime creation of Remotes/UI
- Client/server separation: server owns game state/AI; client handles input, UI, and visuals

Operational notes for Warp
- This repo does not include Wally or Foreman configs; Aftman manages Rojo. Run aftman install before using rojo.
- UI: Several systems expect manually created Studio UI (e.g., StarterGui/BackpackGui with children). Do not attempt to "build UI" via scripts.
- Tags: Many features rely on CollectionService tags (BUY_ZONE, SELL_ZONE, STORABLE, DRAGGABLE, etc.). Logic assumes tags exist in place files.
- No tests are configured at this time; if adding tests (e.g., TestEZ), place suite and document commands here.

