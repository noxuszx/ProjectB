# Backpack Gamepasses Plan and Specification

Status: Planning (no implementation yet)
Owners: You + future contributors
Scope: Lobby + Game place (ProjectB)

## Overview
We will add two gamepasses that modify the player’s backpack in the main game:
- Backpack Pro
  - Visual: Black and Red backpack
  - Capacity: +10 (total 20)
  - Price: 299 Robux
  - Tool name: "BackpackPro"
- Backpack Prestige
  - Visual: Gold and White plated backpack
  - Capacity: +20 (total 30)
  - Price: 499 Robux
  - Tool name: "BackpackPrestige"

The base backpack remains at 10 capacity and uses the Tool named "Backpack".

Important rules:
- Tools exist in ReplicatedStorage/Tools and are named exactly: Backpack, BackpackPro, BackpackPrestige.
- Players select which backpack to use via lobby wall ProximityPrompts.
- In the game place, the chosen backpack is automatically equipped on spawn (CharacterAdded) and other variants are removed.
- If both passes are owned, the "equipped" backpack should default to the most recently purchased one (buying implies equipping).
- Purchases happen only in the lobby place (not in the game place).
- Preference must be sticky across sessions using ProfileService.

## Ownership and Preference Logic

Terminology:
- Ownership: MarketplaceService gamepass ownership for Pro/Prestige.
- Preference: Which backpack variant the player wants to equip in the game place when spawning.

Rules:
1) If a player owns neither pass → Base backpack (Backpack, 10 capacity).
2) If a player owns exactly one pass → That variant becomes preferred when selected in lobby; if never explicitly selected, still allow defaulting to the owned one when no other is owned.
3) If a player owns both → Preferred variant is:
   - The most recently purchased pass, OR
   - The last explicitly selected at the lobby wall (ProximityPrompt) — selection updates preference.
4) If stored preference becomes invalid (e.g., refund) → Fallback to Pro if owned; otherwise Base.
5) Preference is sticky across sessions via ProfileService.
6) TeleportData conveys the immediate choice from the lobby when teleporting to the game (useful for same-session consistency), but ProfileService is the source of truth across sessions.

## Lobby Place Behavior

- Each backpack model has a Part in front with a ProximityPrompt.
- On prompt interaction:
  - If the player does not own the associated pass → PromptGamePassPurchase.
  - If the player owns it → Treat the prompt as "Equip" (set preference to that variant).
- Players can roam the lobby after selecting; the preference remains saved. When they eventually queue/teleport to the game place, the game place will equip that preference.
- If a player buys a pass (e.g., buys Pro, then later buys Prestige), the "latest purchased" rule applies. You may update the stored preference upon purchase completion so the newest becomes the preference automatically.

Implementation notes (lobby):
- Maintain a small LobbyBackpackController to:
  - Wire ProximityPrompts to MarketplaceService for purchase.
  - On ownership (either already owned or after purchase success), switch prompt text/action to "Equip" and on activation store preference via ProfileService in the lobby place.
  - Optionally show subtle feedback in lobby (e.g., BillboardGui "Equipped"). Do NOT equip the Tool in lobby; preference only.
- Teleport flow: When teleporting the party, include TeleportData.BackpackChoice = "Pro" | "Prestige" (if a choice was made this session).

## Game Place Behavior

On PlayerAdded:
- Resolve preference using the following order:
  1) TeleportData.BackpackChoice (if present)
  2) ProfileService stored preference (if present)
  3) Default: If both owned → the most recently purchased pass; else Pro if owned; else Base.
- Validate preference against current ownership and downgrade as needed (Prestige→Pro→Base).
- Compute capacity: Base=10, Pro=20, Prestige=30.
- Cache per-player: chosenVariant, capacity.

On CharacterAdded:
- Equip the chosen Tool in Character (not just in player.Backpack) so it’s actively usable.
- Remove other backpack variants from both Character and player.Backpack to avoid conflicts.
- Ensure backpack UI reflects the correct capacity (see Sync section).

Ownership updates mid-session:
- Purchases only happen in the lobby by design, so game place does not need to handle purchase prompts. Still keep the code resilient if ownership changes between respawns (e.g., if player rejoins after buying).

## Data Model and Services

We will add the following server-side pieces:

1) Gamepass constants (shared or server config)
- GamePass IDs (placeholder until created):
  - GAMEPASS_PRO_ID = <TBD>
  - GAMEPASS_PRESTIGE_ID = <TBD>

2) BackpackPreference storage via ProfileService
- Profile key: profile.Data.BackpackPreference = "Base" | "Pro" | "Prestige"
- Optional metadata: profile.Data.BackpackPreferenceUpdatedAt = os.time()
- Optional: profile.Data.LastPurchasedBackpack = "Pro" | "Prestige" with timestamp to help apply the "latest purchased" default.

3) Gamepass/Preference Service (server)
- Responsibilities:
  - On PlayerAdded: fetch profile; read preference fields; read TeleportData; check ownership via MarketplaceService:UserOwnsGamePassAsync.
  - Resolve final preference using rules above (including latest purchased when relevant).
  - Store updated preference back to profile if changed (e.g., TeleportData indicated a different choice).
  - Provide getters: getChosenVariant(player) → "Base"|"Pro"|"Prestige"; getCapacity(player) → 10/20/30.

4) Equip Service (server)
- Responsibilities:
  - On CharacterAdded: equip chosen backpack Tool and remove others.
  - Uses existing ToolGrantService to clone from ReplicatedStorage/Tools.
  - Ensures the Tool is parented to Character (equipped), not just player.Backpack.
  - Hard-remove other backpack variants from Character and player.Backpack to avoid duplicates.

5) BackpackService refactor (server)
- Change from module-level MAX_SLOTS to per-player capacity.
  - playerBackpacks[player.UserId] = { maxSlots = 10, ... }
  - On PlayerAdded (or after preference resolved), set maxSlots to 10/20/30.
  - Replace uses of MAX_SLOTS with backpack.maxSlots in canStore/getBackpackStats.
- Keep pooling and LIFO semantics unchanged.

6) Networking and UI sync
- Continue using ReplicatedStorage.Remotes.BackpackEvent and BackpackChanged.
- Extend "Sync" payload to include capacity (maxSlots) so the client UI can display currentCount/maxCapacity.
- Client: update any places where code assumes a fixed 10 capacity to respect synced maxSlots.
  - Example: BackpackUI counter shows `${count}/${maxSlots}`.
  - Ensure input logic (F key store/retrieve) remains unchanged.

## Interaction with Existing Systems

- ToolGrantService (src/server/services/ToolGrantService.lua)
  - Will be used to grant the chosen Tool.
  - After grant, move Tool to Character (Equip Service) and delete other backpack variants.

- InteractableHandler and BackpackController (client)
  - These currently check for character:FindFirstChild("Backpack") to confirm a backpack is equipped.
  - Update detection to treat any of {"Backpack", "BackpackPro", "BackpackPrestige"} as a valid equipped backpack.

- Economy system
  - No changes needed; backpack capacity affects only item storage count.

## Detailed Flows

1) Lobby selection (owned case)
- Player interacts with ProximityPrompt in front of BackpackPro.
- System sees ownership → set profile.Data.BackpackPreference = "Pro"; optionally set TeleportData.BackpackChoice = "Pro".
- The prompt shows as "Equip" and confirms selection.

2) Lobby purchase
- Player interacts with ProximityPrompt for a pass they don’t own.
- PromptGamePassPurchase is shown.
- On success (PromptGamePassPurchaseFinished), update:
  - Ownership cache.
  - profile.Data.LastPurchasedBackpack = that variant (with timestamp) and optionally set BackpackPreference to the purchased variant (buying implies equip).
  - Prompt now switches to "Equip" mode for that variant.

3) Game join
- PlayerAdded:
  - Read TeleportData.BackpackChoice if present.
  - Load profile; read BackpackPreference and LastPurchasedBackpack timestamps.
  - Check ownership of Pro/Prestige.
  - Resolve preference using rules; compute capacity; store any changes back to profile.
  - Set per-player capacity in BackpackService.
- CharacterAdded:
  - Equip chosen Tool in Character.
  - Remove other variants from Character and player.Backpack.
  - Trigger Backpack Sync so UI shows count/max.

## Data Structures

ProfileService schema (portion):
```
profile.Data = {
  BackpackPreference = "Base" | "Pro" | "Prestige",
  BackpackPreferenceUpdatedAt = number?,
  LastPurchasedBackpack = "Pro" | "Prestige"?,
  LastPurchasedAt = number?,
}
```

TeleportData schema (optional, lobby → game for immediate handoff):
```
{
  BackpackChoice = "Pro" | "Prestige"
}
```

Server runtime cache (per player):
```
PlayerState = {
  chosenVariant = "Base" | "Pro" | "Prestige",
  capacity = 10 | 20 | 30
}
```

## Constants (to fill in later)
- GAMEPASS_PRO_ID = <TBD>
- GAMEPASS_PRESTIGE_ID = <TBD>
- CAPACITY_BASE = 10
- CAPACITY_PRO = 20
- CAPACITY_PRESTIGE = 30

## Edge Cases and Fallbacks
- Missing/failed ProfileService load: default using ownership (Prestige > Pro > Base). Do not block spawn; log warning.
- Stored preference without ownership: downgrade to Pro or Base, update profile.
- Player owns both and no preference stored: choose latest purchased (if timestamps available) or default to Prestige until they explicitly equip in lobby.
- Character respawn loops: always re-equip and cleanup other variants to maintain consistency.
- Late tool grant failures: retry once, otherwise fall back to Base and warn.

## Testing Plan

Scenarios:
1) No passes owned → Base tool, capacity 10, UI shows x/10.
2) Own Pro only, never selected in lobby → Default to Pro, capacity 20, tool equipped.
3) Own Prestige only → Default to Prestige, capacity 30.
4) Own both, last purchased Pro → Preference resolves to Pro unless TeleportData or lobby equip changed it; capacity 20.
5) Own both, last purchased Prestige → Preference resolves to Prestige; capacity 30.
6) Select Pro in lobby, roam, then teleport → Game equips Pro; capacity 20.
7) Refund Prestige after pref=Prestige → Downgrade to Pro (if owned) or Base; update profile.
8) ProfileService unavailable → Non-fatal fallback to ownership-based default.
9) Respawn → Re-equip correct tool and remove others; UI still shows correct capacity.

Validation:
- Use BackpackEvent "Sync" to verify UI count/max updates.
- Confirm Drag/Store/Retrieve flows work at higher capacities.
- Confirm ToolGrantService grants the correct tool and others are absent.

## Implementation Tasks (future)
- Add Gamepass/BackpackPreference service (server) integrating ProfileService and MarketplaceService.
- Refactor BackpackService to per-player maxSlots.
- Equip-on-spawn logic using ToolGrantService; cleanup other variants on CharacterAdded.
- Extend backpack Sync to include capacity; update client UI and any backpack-equip checks to recognize all three tool names.
- Lobby prompt handlers: purchase vs equip; update preference on purchase and on equip selection.

## Notes on Performance and Safety
- Keep all RemoteEvents pre-declared (follow project pattern). Do not create at runtime.
- Use ProfileService session-lock properly to avoid data contention.
- Minimize DataStore writes: only write when preference changes.
- MarketplaceService calls can be cached per session; avoid spamming ownership checks.
- Always validate server-side: never trust client ownership claims.

## Future Extensions
- Additional cosmetic variants (skins) with no capacity change.
- Temporary capacity boosters (consumables) layered on top of base/pro/prestige capacity.
- Analytics: log preference changes and capacity usage distribution.

---

## Next Session Action Items (short list)
- Verify Game resolver branch when Pro is selected (look for [BPS][DEBUG] resolveVariant: using TeleportData= Pro or using Profile pref= Pro)
- Ensure Queue.server.lua TeleportData (BackpackChoices) is synced and reaching Game (check player:GetJoinData())
- If resolver still falls back to Prestige, increase profile wait time or log the actual JoinData in Game for one player
- After verification, remove temporary debug logs (LobbyBackpackService, BackpackPreferenceService, BackpackVariantInit)
- QA across scenarios: owns none/Pro/Prestige/both; refunds/invalid prefs; multi-respawn; multi-user teleport

## Implementation TODO (current status)

---

Session Summary — 2025-08-18

Done today
- Scaffolds and configs
  - Added Game/Lobby GamepassConfig with IDs (Pro=1407472360, Prestige=1406690237)
  - Added ProfileSchema defaults
  - Created BackpackPreferenceService (Game) and LobbyBackpackService (Lobby)
- Per-player capacity and sync
  - Refactored BackpackService to use per-player maxSlots with setter
  - Included capacity in BackpackEvent Sync; UI now shows count/max
- Equip-on-spawn and persistence
  - Added BackpackVariantInit.server.lua to resolve variant and equip on spawn
  - Equip service purges base/other variants, grants correct tool, equips to Character
  - Synced Player.StarterGear with selected variant so respawns keep it
- Lobby integration
  - Wired ProximityPrompts (Pro/Prestige) to purchase/equip flow
  - Added ProfileService bootstrap (Lobby + Game) and _G.ProfileAccessor
  - Added TeleportData handoff via Queue.server.lua to send group BackpackChoices
- Robustness and debugging
  - Normalized tool names (BackPackPro, BackpackPrestige) and case-insensitive purge
  - Added extensive debug logs in Lobby and Game for ownership, save, TeleportData, resolveVariant, and equip

Observations
- Prestige equips correctly end-to-end
- Pro selection saved in Lobby and TeleportData wired; need to confirm Game resolveVariant logs use TeleportData/Profile pref for Pro (vs fallback to Prestige)

Next
- Verify in Game logs which branch resolveVariant uses when Pro is selected
  - Expect: "using TeleportData= Pro" or "using Profile pref= Pro"
  - If neither, increase wait for profile readiness or inspect GetJoinData/TeleportData contents live
- Ensure Queue.server.lua change (group TeleportData BackpackChoices) is live and synced
- Fine-tune equip timing if any race remains (small delay or retry)
- Clean up temporary debug logs after verification
- QA: test scenarios (owns none/Pro/Prestige/both), refunds/invalid prefs, multi-respawn behavior, multi-user party teleport

Completed
- [x] Create detailed design/spec document (this file)
- [x] Add per-place scaffolds for gamepasses
  - [x] Game: src/shared/config/GamepassConfig.lua (with placeholder IDs)
  - [x] Lobby: src/shared/config/GamepassConfig.lua (with placeholder IDs)
- [x] Add ProfileService schema defaults
  - [x] Game: src/shared/profile/ProfileSchema.lua
  - [x] Lobby: src/shared/profile/ProfileSchema.lua
- [x] Add Game service scaffolds
  - [x] BackpackPreferenceService.lua (resolve variant + equip)
- [x] Add Lobby service scaffold
  - [x] LobbyBackpackService.lua (purchase/equip prompts, TeleportData prep)
- [x] Update default.project.json mappings
  - [x] Game: map Shared/config and Shared/profile; ensure ServerScriptService/Data
  - [x] Lobby: map Shared/config and Shared/profile; add ServerScriptService/Data
- [x] Add wiring checklists to Game and Lobby READMEs

Next up
- [ ] Refactor BackpackService to support per-player capacity (maxSlots)
  - [ ] Replace module-level MAX_SLOTS with per-player value
  - [ ] Provide setter to apply capacity after variant resolution
- [ ] Sync capacity to clients
  - [ ] Extend BackpackEvent "Sync" payload to include maxSlots
  - [ ] Update BackpackUI to display count/max from sync
  - [ ] Ensure backpack-equipped checks accept Backpack/BackpackPro/BackpackPrestige
- [ ] Wire Game join/spawn logic
  - [ ] PlayerAdded: resolve variant (TeleportData + Profile + ownership) and compute capacity
  - [ ] Apply per-player capacity in BackpackService
  - [ ] CharacterAdded: equip chosen variant and remove others
- [ ] Wire Lobby ProximityPrompts
  - [ ] Connect prompts to LobbyBackpackService.handleBackpackPrompt for Pro/Prestige
  - [ ] Use getPromptText to show Buy vs Equip dynamically
  - [ ] On party teleport, include TeleportData from prepareTeleportData
- [ ] Integrate ProfileService bootstrap in both places
  - [ ] Expose _G.ProfileAccessor with getProfileData/updateProfileData
  - [ ] Handle load errors gracefully and fall back to ownership
- [ ] Fill real Gamepass IDs in GamepassConfig.IDS (both places)
- [ ] Execute test plan across scenarios (none/pro/prestige/both, refunds, respawns)

