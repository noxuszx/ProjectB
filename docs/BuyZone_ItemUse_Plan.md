# Buy-Zone Item Use Plan (Tools, Ammo, Objects)

Goal: Add post-purchase functionality for spawned buy-zone items without spawning Tool instances directly. Use ProximityPrompts + attributes and server-side handlers to grant tools, add ammo, or leave objects as-is.

Overview
- Keep buy flow: BuyPrompt handles cost and leaves purchased model in world.
- Add UsePrompt for items that can be “used” (Tool or Ammo). Objects remain unchanged (draggable/storable).
- Centralize prompt handling in a single server handler (ItemUseHandler).
- Add two small services for tool granting and ammo management.
- Drive behavior via EconomyConfig (Type, GiveToolName, AmmoType, AmmoAmount).

Config changes (EconomyConfig)
- Extend each BuyableItems entry with a Type and optional fields:
  - Type: "Tool" | "Ammo" | "Object"
  - For Type="Tool": GiveToolName = "Crossbow" (matches template in ReplicatedStorage.Tools)
  - For Type="Ammo": AmmoType = "CrossbowBolt", AmmoAmount = 5
  - For Type="Object": no extras

Example additions:
```lua
BuyableItems = {
  { ItemName = "Crossbow", Cost = 100, SpawnWeight = 0.4, Category = "Weapons", Type = "Tool", GiveToolName = "Crossbow" },
  { ItemName = "Bolts",    Cost = 10,  SpawnWeight = 0.6, Category = "Ammo",    Type = "Ammo", AmmoType = "CrossbowBolt", AmmoAmount = 5 },
  { ItemName = "Bandage",  Cost = 5,   SpawnWeight = 0.6, Category = "Object",  Type = "Object" },
}
```

Runtime flow
1) Spawn: BuyZoneHandler spawns the model/BasePart above the BUY_ZONE and adds BuyPrompt (already implemented).
2) Purchase: Player triggers BuyPrompt → EconomyService deducts money → BuyPrompt destroyed → item remains in world.
3) Post-purchase "Use" (new): If config Type requires action (Tool/Ammo), attach a UsePrompt to the spawned item with attributes that describe the action.
4) ItemUseHandler listens for UsePrompt triggers and routes to ToolGrantService or AmmoService.

Server components
- ItemUseHandler.server.lua (new)
  - Listens: ProximityPromptService.PromptTriggered
  - Filters: prompt.Name == "UsePrompt"
  - Reads attributes:
    - UseType: "GrantTool" | "AddAmmo"
    - ToolTemplate (string), or AmmoType (string), AmmoAmount (number)
  - Calls service functions, then removes/pools the world item.

- ToolGrantService.lua (new)
  - grantTool(player, toolName):
    - Clone ReplicatedStorage.Tools[toolName]
    - Parent to player.Backpack (and optionally StarterGear)
    - Optionally auto-equip if humanoid exists

- AmmoService.lua (new)
  - addAmmo(player, ammoType, amount): increments per-player count
  - getAmmo, consumeAmmo: helpers for later weapon integration

BuyZoneHandler changes (minimal)
- After successful purchase:
  - Lookup item config by ItemName (already available on BuyPrompt attributes)
  - If Type == "Tool":
    - Attach UsePrompt (HoldDuration=0) with attributes:
      - UseType = "GrantTool"
      - ToolTemplate = GiveToolName
      - ItemName = ItemName
  - If Type == "Ammo":
    - Attach UsePrompt with attributes:
      - UseType = "AddAmmo"
      - AmmoType = AmmoType
      - AmmoAmount = AmmoAmount
  - If Type == "Object": do nothing extra

UsePrompt creation snippet
```lua
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "UsePrompt"
prompt.ActionText = actionText -- e.g., "Equip Crossbow" or "Collect Bolts (+5)"
prompt.ObjectText = objectText -- e.g., "Tool" or "Ammo"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 8
prompt.RequiresLineOfSight = false
-- Attributes
autoSet(prompt, "UseType", useType)
autoSet(prompt, "ToolTemplate", toolName)
autoSet(prompt, "AmmoType", ammoType)
autoSet(prompt, "AmmoAmount", ammoAmount)
-- Parent to a BasePart (same logic as BuyPrompt host)
prompt.Parent = mainPart
```

ItemUseHandler routing snippet
```lua
if prompt.Name ~= "UsePrompt" then return end
local useType = prompt:GetAttribute("UseType")
if useType == "GrantTool" then
  local toolName = prompt:GetAttribute("ToolTemplate")
  ToolGrantService.grantTool(player, toolName)
elseif useType == "AddAmmo" then
  local ammoType = prompt:GetAttribute("AmmoType")
  local amount = tonumber(prompt:GetAttribute("AmmoAmount")) or 0
  AmmoService.addAmmo(player, ammoType, amount)
end
-- Remove or pool the item pickup
local hostPart = prompt.Parent
if hostPart then hostPart:Destroy() end
```

Data and UX notes
- Tools in ReplicatedStorage.Tools: ensure names match GiveToolName.
- UsePrompt is quick (HoldDuration = 0) to feel like a pickup.
- Objects keep existing tags and are draggable/storable with no UsePrompt.
- Optional: add small SFX/FX via RemoteEvent on grant/ammo add.

Edge cases and guards
- Missing templates: warn and ignore use.
- Player missing Backpack/Humanoid: still parent tool to Backpack; skip auto-equip.
- Double-trigger: disable prompt immediately on trigger or use a short debounce; server is authoritative.

Suggested file layout
- src/server/economy/BuyZoneHandler.server.lua (small additions post-purchase)
- src/server/items/ItemUseHandler.server.lua (new)
- src/server/services/ToolGrantService.lua (new)
- src/server/services/AmmoService.lua (new)

Phase rollout
1) Config + ItemUseHandler + services + BuyZoneHandler UsePrompt attach
2) Crossbow firing reads from AmmoService and decrements ammo
3) UI shows ammo count per equipped tool (future)

Test checklist
- Buy Crossbow (Tool): BuyPrompt works, UsePrompt appears, equipping grants Tool to Backpack.
- Buy Bolts (Ammo): UsePrompt appears, adds ammo; world pickup removed.
- Buy Bandage (Object): no UsePrompt; item draggable/storable.
- Rapid interactions: no errors; prompts not hijacked by other handlers (CashCollectionHandler already scoped).

