# Economy System Roadmap

This document outlines the phased roadmap for implementing the new economy system that integrates with the existing drag/drop and highlighting frameworks in ProjectB.

---

## Phase 0 – Project Preparation

| Task | Owner | Notes |
|------|-------|-------|
| Create `feature/economy-system` Git branch | Engineering | Keep work isolated until final merge |
| Stub **CollectionService** tags in Studio (`SELLABLE_LOW`, `SELLABLE_MID`, `SELLABLE_HIGH`, `SELL_ZONE`, `BUY_ZONE`) | Design | Tags enable early integration testing |
| Add empty `EconomyConfig.lua`, `EconomyService.lua` and placeholder UI file | Engineering | Scaffolding for upcoming phases |
| Register new RemoteEvent namespaces in `default.project.json` | Engineering | `Remotes/Economy/{SellItem,BuyItem,UpdateMoney,RefreshBuyZones}` |
| Update `PlayerStatsConfig.lua` to include `Money` (Number) | Engineering | Session-scoped—no data persistence yet |

---

## Phase 1 – Core Configuration & Shared Types

Goal: Centralise all economy constants in a single shared module.

- [ ] Implement `src/shared/config/EconomyConfig.lua`
  - Sellable tier definitions (`SELLABLE_*`, coin values)
  - Buyable item table with cost, prefab reference, and spawn weights
  - Zone & UI tunables (touch cooldown, colors, animation speeds)
- [ ] Add unit tests for config integrity (LuaUnit) – ensure coin values > 0 and weights sum correctly.

Deliverable: `EconomyConfig.lua` fully populated and test-passing.

---

## Phase 2 – Server-Side Sell System

Goal: Players can convert tagged items into money via sell zones.

- [ ] Implement `src/server/handlers/SellZoneHandler.server.lua`
  - Listen for `.Touched` on parts with `SELL_ZONE` tag
  - Verify touching instance has `SELLABLE_*` tag
  - Debounce per-instance to avoid double sales
  - Award coins based on tag → value map (from config)
  - Destroy model *or* return to pool (reuse CreaturePoolManager utility)
  - Fire `UpdateMoney` RemoteEvent to owning client
- [ ] Integrate with existing drag/drop ownership checks
- [ ] Unit/integration test: selling 10 items rapidly (< 1 s) awards correct total and no duplicates.

Deliverable: Reliable, exploit-safe sell flow running on server.

---

## Phase 3 – Money UI (Client)

Goal: Real-time money display that reacts smoothly to changes.

- [ ] Create `src/client/ui/EconomyUI.client.lua`
  - UI is No background just fredokaone text with a text "$" and right next to it is the number of current money.
  - Listen to `UpdateMoney` RemoteEvent
- [ ] Position UI relative to existing inventory counter (top-right)
- [ ] UX test with money spam to ensure no frame drops

Deliverable: Polished money HUD element on client.

---

## Phase 4 – Buy Zone System & Highlighting

Goal: Allow players to spend money on randomised buy zones with clear afford-state indication.

### Server
- [ ] Implement `src/server/handlers/BuyZoneHandler.server.lua`
  - Manage buy zone state & respawn logic using `EconomyConfig.BuyableItems`
  - Validate funds on purchase, deduct, and spawn prefab on zone
  - Send `RefreshBuyZones` to all clients on state change

### Client
- [ ] Extend existing highlight manager
  - Green fill if `player.Money >= BuyCost`, red otherwise
  - Subscribe to `RefreshBuyZones` + `Money` changes
- [ ] Add proximity prompt logic for buy action -> fires `BuyItem` RemoteEvent

Deliverable: Fully interactive shop pads with affordability feedback.

---

## Phase 5 – Optimisation & Polish

- [ ] Batch multiple `UpdateMoney` events into a single message per Heartbeat when selling many items
- [ ] Pool highlight objects to reduce allocation churn
- [ ] Add server-side rate limits on `BuyItem` RemoteEvent (e.g., 3/s per player)
- [ ] Memory profiling with 200 active buy zones & 300 sell events/min
- [ ] Code review for security (remote exploits, replication sanity)

Deliverable: Stable, performant economy under load.

---

## Phase 6 – QA & Play-Testing

- [ ] Automated test suite (PlaytestService) covering sell/buy edge cases
- [ ] Multiplayer session with 10 testers – observe performance and UX
- [ ] Tune coin values & item costs based on feedback
- [ ] Finalise documentation in `EconomySystemPlan.md` & update README

Deliverable: Feature-complete economy ready for merge into `main`.

---

## Phase 7 – Production Rollout

- [ ] Merge PRs into `main`
- [ ] Tag release `vX.Y.0-economy`
- [ ] Build `.rbxlx` via Rojo & publish to internal testing place
- [ ] Monitor metrics (server ms/frame, RemoteEvent bandwidth)
- [ ] Hotfix any critical issues, then publish to live game.

---

### Total Estimated Timeline: **2–3 engineering days + 1 day QA** (assuming reuse of existing systems).

> "Measure twice, cut once."  – Follow the roadmap, keep code self-contained, and leverage Roblox & community frameworks first.

