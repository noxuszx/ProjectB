# Tutorial System Overview

This document outlines the goal, flow, architecture, notes, and next steps for the in-game tutorial system.

## Goal
Build a lightweight, data-driven tutorial that teaches players core mechanics using concise UI prompts and dynamic in-world highlighting. Steps should auto-advance when the player performs the intended action, leveraging existing tags and events where possible.

## High-level Flow
1) Drag basics
   - Text: "You can drag items and weld them anywhere."
   - Highlight: nearest DRAGGABLE item.
   - Complete: on first successful drag (preferred: DragDrop.DragEnded event; fallback: short timeout).

2) Cook raw food
   - Text: "You can drag raw food into campfires to cook it."
   - Highlight: nearest COOKING_SURFACE (campfire).
   - Complete: when a cooked item is produced (preferred: Food.Cooked RemoteEvent; fallback: detect appearance of a CONSUMABLE nearby).

3) Eat cooked food
   - Text: "Eat the cooked food."
   - Highlight: nearest CONSUMABLE item (or the produced food if tracked).
   - Complete: on Hunger increase (preferred: UpdatePlayerStats RemoteEvent; fallback: short timeout after interaction).

4) Sell at trading post
   - Text: "You can sell items in village trading posts."
   - Highlight: nearest SELL_ZONE (and optionally the structure/model for extra clarity).
   - Complete: first money increase (listening to Remotes.Economy.UpdateMoney).

5) Buy from shop
   - Text: "You can buy items from shops."
   - Highlight: nearest BUY_ZONE/shop.
   - Complete: first money decrease (listening to Remotes.Economy.UpdateMoney). End of tutorial.

## Architecture
- Data-driven steps (shared)
  - File: src/shared/tutorial/TutorialSteps.lua
  - Each step includes: id, text, targetSelector(player) to find nearest target by tag.

- Client TutorialController
  - File: src/client/tutorial/TutorialController.client.lua
  - Orchestrates step lifecycle: sets UI text, attaches/detaches highlights, subscribes to completion signals, advances steps.
  - UI: Uses existing PlayerGui.TutorialGui/TutorialFrame/TutorialText if present; otherwise creates a minimal fallback bar.

- Client HighlightManager
  - File: src/client/tutorial/HighlightManager.lua
  - Attaches/detaches a Highlight instance to the current target (Model or BasePart). Defaults to a gold-ish fill.

## Integration with Existing Systems
- Tags used
  - DRAGGABLE, COOKING_SURFACE, CONSUMABLE, SELL_ZONE, BUY_ZONE (from CollectionServiceTags).

- Events/signals leveraged
  - DragDrop.DragEnded (optional remote) for drag completion.
  - Food.Cooked (optional remote) when cooking completes.
  - Remotes.Economy.UpdateMoney to detect sell/buy via balance change.
  - UpdatePlayerStats (optional remote) to detect Hunger increase.

## Notes
- Highlights are created dynamically on the client (no pre-placed Highlight instances required). For large structures, an optional Attachment (e.g., TutorialAnchor) can be added to guide Billboard/arrow placement later.
- The controller uses fallbacks/timeouts where a dedicated event is not yet available to keep the tutorial moving.
- All highlights and connections are cleaned up when advancing steps.
- Multiplayer-safe: highlighting is client-only.
- Persistence is not implemented yet; players will see the tutorial every session until we add a completion flag.

## Next Steps
- Reliability
  - Expose definitive events for steps:
    - DragDrop.DragEnded (RemoteEvent to the acting player)
    - Food.Cooked (RemoteEvent to the acting player)
    - Confirm UpdatePlayerStats is client-facing; otherwise add a small remote for Hunger changes.

- UX polish
  - Improve UI styling (colors, fonts, animations). Add "Skip tutorial" action.
  - Optional camera nudge towards highlighted target for 1–2s on step start.
  - Optional Billboard/arrow when the target is off-screen or far away.

- Persistence
  - Set Player attribute (TutorialDone=true) on completion; skip on next session.
  - Provide a way to reset tutorial via settings.

- Safety/edge cases
  - Auto-advance if a step is already satisfied when it starts (e.g., player recently sold an item).
  - If a target doesn’t exist yet, keep scanning by tag and attach highlight when available (already partially handled).

## File Index
- src/shared/tutorial/TutorialSteps.lua
- src/client/tutorial/HighlightManager.lua
- src/client/tutorial/TutorialController.client.lua

