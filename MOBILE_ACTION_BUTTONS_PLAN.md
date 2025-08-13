# Mobile Action Buttons Implementation Plan (Enhanced)

## Problem Overview

The game currently has desktop keyboard shortcuts and hints for various actions (Drag, Store, Weld, Eat, Rotate, Axis), but mobile users have no way to access these features. Mobile players need touch-friendly action buttons that appear contextually when actions are available.

## Solution Overview

Create a centralized **Mobile Action Controller** that:
- Shows contextual action buttons only when actions are available
- Uses toggle-style buttons (like the Sprint button) for better mobile UX
- Reuses existing game logic and condition checking
- Provides consistent visual feedback across all action types
- Binds/unbinds actions to reclaim visual slots based on availability

## Reference Files

### Files to Study/Reference
- `src/client/ui/DesktopHints.client.lua` - Condition checking logic (`canDrag()`, `canStore()`, etc.)
- `src/client/SprintController.client.lua` - Mobile button implementation pattern
- `src/shared/modules/ContextActionUtility.lua` - Button creation and styling API
- `src/client/dragdrop/InteractableHandler.client.lua` - Drag/drop core logic
- `src/client/backpack/BackpackController.client.lua` - Store/retrieve logic (exports `_G.BackpackController`)
- `src/client/food/FoodConsumption.client.lua` - Eating logic module

### Files to Modify/Create
- **NEW**: `src/client/ui/MobileActionController.client.lua` - Main implementation
- **MODIFY (small API additions only, see below)**: `src/client/dragdrop/InteractableHandler.client.lua`
- `src/client/ui/DesktopHints.client.lua` already disables on mobile (leave as-is)

## Path Corrections vs Original Plan
- Food controller is `src/client/food/FoodConsumption.client.lua` (not `ui/FoodController.client.lua`).
- Backpack controller is `src/client/backpack/BackpackController.client.lua` (not `ui/BackpackController.client.lua`).

## Required Small API Additions (InteractableHandler)
To drive Weld/Rotate/Axis/Drag from mobile, expose tiny wrappers via `_G.InteractableHandler`.

Suggested additions (copy/paste into `src/client/dragdrop/InteractableHandler.client.lua` near the export table):

```lua
-- New exported helpers for mobile buttons
local function TryWeld()
    if currTargs then
        local oldWeld = currentWeld
        currentWeld, _ = WeldSystem.weldObject(currTargs, currentWeld)
        if currentWeld and not oldWeld then
            showWeldFeedback("Objects welded together!", 2)
            if hasAnchoredParts(currTargs) then
                showWeldFeedback("Welded to anchored object - dropping item", 2)
                DropItem(false)
            end
        elseif not currentWeld and oldWeld then
            showWeldFeedback("Objects unwelded!", 2)
        elseif not currentWeld then
            showWeldFeedback("No weldable objects nearby", 2)
        end
    end
end

local function RotateOnce()
    if carrying and currTargs then
        rotationCount[currentRotationAxis] = rotationCount[currentRotationAxis] + 1
    end
end

local function CycleAxis()
    if carrying and currTargs then
        currentRotationAxis = (currentRotationAxis % 3) + 1
    end
end

local function StartDrag()
    LeftClick()
end

local function StopDrag()
    if carrying then
        LeftUnClick() -- or DropItem(true/false) depending on desired behavior
    end
end

-- Extend export
_G.InteractableHandler = {
    GetCurrentTarget = GetCurrentTarget,
    IsCarrying = IsCarrying,
    TryWeld = TryWeld,
    RotateOnce = RotateOnce,
    CycleAxis = CycleAxis,
    StartDrag = StartDrag,
    StopDrag = StopDrag,
}
```

## Implementation Details

### Core Architecture

- Single controller with an action registry. Each action defines:
  - `actionName` (for ContextAction binding)
  - `canShow()` (availability predicate)
  - `onAction()` (invoked on button press)
  - `getText(state)` and `getColors(state)`

### Button States & Visual Design

- Drag:
  - Available: Title "DRAG", white (released) / gray (pressed)
  - While carrying: Title "DROP", red (released) / darker red (pressed)
- Store: Title "STORE", white/gray; only when backpack equipped AND target storable AND not carrying
- Weld: Title "WELD", white/gray; only when carrying AND weld opportunity nearby
- Eat: Title "EAT", white/gray; only when consumable nearby AND sack/backpack not equipped
- Rotate: Title "ROTATE", orange/gray; only when carrying
- Axis: Title "AXIS" (or current axis letter), blue/gray; only when carrying

### Availability/Condition Checking
Reuse DesktopHints logic directly (copy the functions or extract to a shared utility). Minimal version inside MobileActionController:

```lua
-- Inside MobileActionController: reusing DesktopHints patterns
local function isSackEquipped()
    local char = player.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false end
    local name = string.lower(tool.Name)
    return name == "sack" or name == "backpack" or string.find(name, "sack") or string.find(name, "backpack")
end

local function canEat()
    if isSackEquipped() then return false end
    if not player.Character or not player.Character.PrimaryPart then return false end
    local playerPos = player.Character.PrimaryPart.Position
    local nearestDist = math.huge
    for _, consumable in ipairs(CollectionService:GetTagged(CollectionServiceTags.CONSUMABLE)) do
        if consumable:IsDescendantOf(workspace) and consumable.Parent then
            local pos
            if consumable:IsA("Model") and consumable.PrimaryPart then pos = consumable.PrimaryPart.Position
            elseif consumable:IsA("BasePart") then pos = consumable.Position end
            if pos then
                local d = (pos - playerPos).Magnitude
                if d <= 10 and d < nearestDist then nearestDist = d end
            end
        end
    end
    return nearestDist < math.huge
end

local function canDrag()
    if _G.InteractableHandler.IsCarrying() then return false end
    local target = _G.InteractableHandler.GetCurrentTarget()
    if not target then return false end
    return CollectionServiceTags.isDraggable(target)
end

local function backpackEquipped()
    local char = player.Character
    return char and char:FindFirstChild("Backpack") ~= nil
end

local function canStore()
    if not backpackEquipped() then return false end
    if _G.InteractableHandler.IsCarrying() then return false end
    local target = _G.InteractableHandler.GetCurrentTarget()
    if not target then return false end
    return CollectionServiceTags.hasTag(target, CollectionServiceTags.STORABLE)
end

local function canWeld()
    -- Keep logic consistent with DesktopHints.canWeld()
    -- (Optionally factor out shared hasAnchoredParts + touching logic)
    -- For brevity here, rely on DesktopHints rules and InteractableHandler proximity.
    return _G.InteractableHandler.IsCarrying() -- plus proximity check if desired
end

local function isCarrying()
    return _G.InteractableHandler.IsCarrying()
end
```

### Button Binding, Priority, and Slots
- ContextActionUtility uses a fixed position list and assigns the next free slot when you bind.
- There are no named slots; to enforce visual priority, bind in this order whenever a button becomes available:
  1) Drag
  2) Store
  3) Weld
  4) Eat
  5) Rotate
  6) Axis
- When an action becomes unavailable, Unbind it to free its slot so higher-priority actions can occupy better positions.

### Update Loop & Performance
- Use a single 0.05s loop (RunService.Heartbeat accumulator) like DesktopHints.
- Maintain a small cache per action: `visible`, `title`, `releasedColor`, `pressedColor`.
- Only call ContextActionUtility setters when a value changed; this avoids extra work.

### Mobile Detection
- `local IS_MOBILE = UserInputService.TouchEnabled`
- Controller should be a no-op when not mobile (do not bind actions on desktop).

## MobileActionController Scaffold
Create `src/client/ui/MobileActionController.client.lua` with the following starter logic:

```lua
-- src/client/ui/MobileActionController.client.lua
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local IS_MOBILE = UserInputService.TouchEnabled
if not IS_MOBILE then return end

local CollectionService = game:GetService("CollectionService")
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local ContextActionUtility = require(ReplicatedStorage.Shared.modules.ContextActionUtility)

-- Wait for globals provided by other controllers
repeat task.wait(0.05) until _G.InteractableHandler
repeat task.wait(0.05) until _G.BackpackController

local IA = _G.InteractableHandler
local Backpack = _G.BackpackController

-- Optionally require food module for direct consume call
local FoodConsumption = require(ReplicatedStorage.Client.food.FoodConsumption)

-- Conditions (see section above for implementations)
-- Implement: isSackEquipped, canEat, canDrag, backpackEquipped, canStore, canWeld, isCarrying

local function getDragVisual()
    local dragging = isCarrying()
    local title = dragging and "DROP" or "DRAG"
    local colors = dragging and {
        released = Color3.fromRGB(255,100,100),
        pressed  = Color3.fromRGB(200,80,80),
    } or {
        released = Color3.fromRGB(255,255,255),
        pressed  = Color3.fromRGB(125,125,125),
    }
    return title, colors
end

local ACTIONS = {
    {
        key = "Drag",
        actionName = "MobileDrag",
        canShow = function() return canDrag() or isCarrying() end,
        onAction = function(actionName, inputState)
            if inputState == Enum.UserInputState.Begin then
                if isCarrying() then IA.StopDrag() else IA.StartDrag() end
            end
        end,
        visuals = function() return getDragVisual() end,
    },
    {
        key = "Store",
        actionName = "MobileStore",
        canShow = canStore,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then Backpack.storeCurrentObject() end
        end,
        visuals = function() return "STORE", {released=Color3.new(1,1,1), pressed=Color3.fromRGB(125,125,125)} end,
    },
    {
        key = "Weld",
        actionName = "MobileWeld",
        canShow = canWeld,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then IA.TryWeld() end
        end,
        visuals = function() return "WELD", {released=Color3.new(1,1,1), pressed=Color3.fromRGB(125,125,125)} end,
    },
    {
        key = "Eat",
        actionName = "MobileEat",
        canShow = canEat,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then FoodConsumption.attemptConsumption() end
        end,
        visuals = function() return "EAT", {released=Color3.new(1,1,1), pressed=Color3.fromRGB(125,125,125)} end,
    },
    {
        key = "Rotate",
        actionName = "MobileRotate",
        canShow = isCarrying,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then IA.RotateOnce() end
        end,
        visuals = function() return "ROTATE", {released=Color3.fromRGB(255,170,0), pressed=Color3.fromRGB(180,120,0)} end,
    },
    {
        key = "Axis",
        actionName = "MobileAxis",
        canShow = isCarrying,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then IA.CycleAxis() end
        end,
        visuals = function() return "AXIS", {released=Color3.fromRGB(0,170,255), pressed=Color3.fromRGB(0,120,180)} end,
    },
}

-- Optional: add Retrieve as a 7th action if desired
-- Only show when backpack equipped and contents available (requires server sync state)

local cache = {}
local function ensureBound(action)
    ContextActionUtility:BindAction(action.actionName, action.onAction, true)
    local title, colors = action.visuals()
    ContextActionUtility:SetTitle(action.actionName, title)
    ContextActionUtility:SetReleasedColor(action.actionName, colors.released)
    ContextActionUtility:SetPressedColor(action.actionName, colors.pressed)
end

local function ensureUnbound(action)
    ContextActionUtility:UnbindAction(action.actionName)
end

local function update()
    -- Rebind in priority order each tick based on availability
    for _, action in ipairs(ACTIONS) do
        local shouldShow = false
        local ok, result = pcall(action.canShow)
        if ok then shouldShow = result == true end

        if shouldShow then
            if not cache[action.key] then
                ensureBound(action)
                cache[action.key] = true
            end
            -- Update visuals only if changed
            local title, colors = action.visuals()
            if cache[action.key..":title"] ~= title then
                ContextActionUtility:SetTitle(action.actionName, title)
                cache[action.key..":title"] = title
            end
            local rKey, pKey = action.key..":rc", action.key..":pc"
            if cache[rKey] ~= tostring(colors.released) then
                ContextActionUtility:SetReleasedColor(action.actionName, colors.released)
                cache[rKey] = tostring(colors.released)
            end
            if cache[pKey] ~= tostring(colors.pressed) then
                ContextActionUtility:SetPressedColor(action.actionName, colors.pressed)
                cache[pKey] = tostring(colors.pressed)
            end
        else
            if cache[action.key] then
                ensureUnbound(action)
                cache[action.key] = nil
                cache[action.key..":title"] = nil
                cache[action.key..":rc"] = nil
                cache[action.key..":pc"] = nil
            end
        end
    end
end

local acc = 0
local INTERVAL = 0.05
RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc >= INTERVAL then
        acc = 0
        update()
    end
end)
```

## TODO Checklist

Preparation
- [ ] Confirm mobile UI dependency exists: TouchGui/TouchControlFrame/JumpButton present on mobile
- [ ] Verify ContextActionUtility requires correctly from ReplicatedStorage.Shared.modules
- [ ] Identify a safe place to require FoodConsumption (ReplicatedStorage.Client.food.FoodConsumption) and confirm module path in runtime data model

InteractableHandler API additions
- [ ] Add TryWeld() wrapper and weld feedback logic
- [ ] Add RotateOnce() to increment currentRotationAxis count
- [ ] Add CycleAxis() to change axis 1->2->3->1
- [ ] Add StartDrag() wrapper calling LeftClick()
- [ ] Add StopDrag() wrapper calling LeftUnClick() (or DropItem as desired)
- [ ] Extend _G.InteractableHandler export with new functions
- [ ] Sanity-test wrappers on desktop via temporary keybinds or command bar

MobileActionController creation
- [ ] Create src/client/ui/MobileActionController.client.lua
- [ ] Early-return when not UserInputService.TouchEnabled
- [ ] Wait for _G.InteractableHandler and _G.BackpackController to be available
- [ ] Require ContextActionUtility from ReplicatedStorage.Shared.modules
- [ ] Optionally require FoodConsumption and confirm it initializes safely

Conditions and availability
- [ ] Implement isSackEquipped() (mirror DesktopHints)
- [ ] Implement canEat() scan (mirror DesktopHints 10-stud radius and sack exclusion)
- [ ] Implement canDrag() using IA.GetCurrentTarget() and tags
- [ ] Implement backpackEquipped() (Backpack instance on character)
- [ ] Implement canStore() requiring backpack, not carrying, and STORABLE tag
- [ ] Implement canWeld() minimal check (carrying) or duplicate DesktopHints proximity logic
- [ ] Implement isCarrying() using IA.IsCarrying()

Action registry and binding
- [ ] Define ACTIONS in priority order: Drag, Store, Weld, Eat, Rotate, Axis
- [ ] For each action, implement onAction handler
  - [ ] Drag: toggle IA.StartDrag()/IA.StopDrag()
  - [ ] Store: Backpack.storeCurrentObject()
  - [ ] Weld: IA.TryWeld()
  - [ ] Eat: FoodConsumption.attemptConsumption()
  - [ ] Rotate: IA.RotateOnce()
  - [ ] Axis: IA.CycleAxis()
- [ ] Implement visuals() per action (titles and colors)
- [ ] Bind using ContextActionUtility:BindAction(createTouchButton = true)
- [ ] Unbind when unavailable to free up slots

Visuals and feedback
- [ ] DRAG/DROP title toggle and color swap (white/gray vs red/dark red)
- [ ] Set title/color only when changed (cache to avoid redundant setter calls)
- [ ] Consider rounding buttons via MakeButtonRound after creation if desired

Update loop and performance
- [ ] Implement 0.05s Heartbeat accumulator
- [ ] On each tick: evaluate availability, bind/unbind, then update visuals if changed
- [ ] Ensure no work is done on desktop (controller returns immediately)

Optional enhancements
- [ ] Add a MobileRetrieve action (if backpack contents state can be checked client-side)
- [ ] Factor shared canX logic into a small shared utility to avoid duplication with DesktopHints
- [ ] Telemetry/prints behind a Debug flag for troubleshooting

Integration and cleanup
- [ ] Confirm DesktopHints remains disabled on mobile (ScreenGui.Enabled = false)
- [ ] Ensure no duplicate bindings with existing systems (Sprint already uses its own action)
- [ ] Verify ContextActionUtility properly reassigns slots as actions appear/disappear

## Testing Checklist
- Buttons appear/disappear in sync with DesktopHints conditions.
- Colors/titles change only when state changes; no flicker.
- Actions correctly trigger: Drag toggle, Store, Weld, Eat, Rotate, Axis.
- ContextActionUtility re-assigns slots as actions bind/unbind.
- Desktop behavior unaffected (MobileActionController no-ops on desktop).

## Success Criteria
- ✅ Mobile players can access all desktop keyboard shortcuts via touch buttons
- ✅ Buttons appear/disappear based on action availability (same logic as desktop hints)
- ✅ Visual feedback clearly indicates button states (available, active, etc.)
- ✅ Performance remains smooth with multiple buttons active
- ✅ Consistent styling and positioning across all action buttons
- ✅ No interference with existing desktop keyboard shortcuts
