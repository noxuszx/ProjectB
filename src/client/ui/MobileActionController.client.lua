-- src/client/ui/MobileActionController.client.lua
-- Mobile touch buttons for drag/drop, backpack, food, welding, and rotation actions

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local IS_MOBILE = UserInputService.TouchEnabled

-- Debug configuration
local DEBUG_ENABLED = false

if DEBUG_ENABLED then
	print("[MobileActionController] === DEBUG START ===")
	print("[MobileActionController] TouchEnabled:", UserInputService.TouchEnabled)
	print("[MobileActionController] MouseEnabled:", UserInputService.MouseEnabled)
	print("[MobileActionController] KeyboardEnabled:", UserInputService.KeyboardEnabled)
	print("[MobileActionController] IS_MOBILE:", IS_MOBILE)
end

if not IS_MOBILE then 
    if DEBUG_ENABLED then print("[MobileActionController] Not mobile device - exiting") end
    return 
end

if DEBUG_ENABLED then print("[MobileActionController] Loading dependencies...") end

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
if DEBUG_ENABLED then print("[MobileActionController] CollectionServiceTags loaded") end

local ContextActionUtility = require(ReplicatedStorage.Shared.modules.ContextActionUtility)
if DEBUG_ENABLED then print("[MobileActionController] ContextActionUtility loaded") end

-- Wait for globals provided by other controllers
if DEBUG_ENABLED then print("[MobileActionController] Waiting for _G.InteractableHandler...") end
repeat task.wait(0.05) until _G.InteractableHandler
if DEBUG_ENABLED then print("[MobileActionController] _G.InteractableHandler found!") end

if DEBUG_ENABLED then print("[MobileActionController] Waiting for _G.BackpackController...") end
repeat task.wait(0.05) until _G.BackpackController
if DEBUG_ENABLED then print("[MobileActionController] _G.BackpackController found!") end

local IA = _G.InteractableHandler
local Backpack = _G.BackpackController

-- Get ConsumeFood RemoteEvent (same as FoodConsumption does)
if DEBUG_ENABLED then print("[MobileActionController] Getting ConsumeFood RemoteEvent...") end
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local consumeFoodRemote = remotesFolder:WaitForChild("ConsumeFood")
if DEBUG_ENABLED then print("[MobileActionController] ConsumeFood RemoteEvent found") end

if DEBUG_ENABLED then print("[MobileActionController] Initialized on mobile device") end

-- Condition checking functions (copied from DesktopHints)
local function isSackEquipped()
    local char = player.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false end
    local name = string.lower(tool.Name)
    return name == "sack" or name == "backpack" or string.find(name, "sack") or string.find(name, "backpack")
end

local EAT_DISTANCE = 10
local function canEat()
    if isSackEquipped() then return false end
    if not player.Character or not player.Character.PrimaryPart then return false end
    local playerPos = player.Character.PrimaryPart.Position
    local nearestDist = math.huge
    for _, consumable in ipairs(CollectionService:GetTagged(CollectionServiceTags.CONSUMABLE)) do
        if consumable:IsDescendantOf(workspace) and consumable.Parent then
            local pos
            if consumable:IsA("Model") and consumable.PrimaryPart then 
                pos = consumable.PrimaryPart.Position
            elseif consumable:IsA("BasePart") then 
                pos = consumable.Position 
            end
            if pos then
                local d = (pos - playerPos).Magnitude
                if d <= EAT_DISTANCE and d < nearestDist then 
                    nearestDist = d 
                end
            end
        end
    end
    return nearestDist < math.huge
end

local function canDrag()
    if IA.IsCarrying() then return false end
    local target = IA.GetCurrentTarget()
    if not target then return false end
    return CollectionServiceTags.isDraggable(target)
end

local function backpackEquipped()
    local char = player.Character
    return char and char:FindFirstChild("Backpack") ~= nil
end

local function canStore()
    if not backpackEquipped() then return false end
    if IA.IsCarrying() then return false end
    local target = IA.GetCurrentTarget()
    if not target then return false end
    return CollectionServiceTags.hasTag(target, CollectionServiceTags.STORABLE)
end

local function canWeld()
    return IA.IsCarrying()
end

local function isCarrying()
    return IA.IsCarrying()
end

local function canRetrieve()
    local contents = Backpack.getBackpackContents()
    local hasContents = contents and #contents > 0
    return hasContents
end

-- Heal (Bandage/Medkit) helpers
local function getEquippedTool()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Tool")
end

local function getEquippedHealType()
    local tool = getEquippedTool()
    if not tool then return nil end
    local name = string.lower(tool.Name)
    if name == "bandage" or name == "medkit" then
        return name -- "bandage" or "medkit"
    end
    return nil
end

local function canUseHeal()
    local healType = getEquippedHealType()
    if not healType then return false end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.Health > 0 and hum.Health < hum.MaxHealth
end

local function activateHeal()
    local tool = getEquippedTool()
    if tool and tool.Activate then
        tool:Activate()
    end
end

local function getHealVisuals()
    local healType = getEquippedHealType()
    if healType == "medkit" then
        return "Medkit", {
            released = Color3.fromRGB(120, 255, 120), -- green
            pressed  = Color3.fromRGB(90, 200, 90),   -- darker green
        }
    else -- default to bandage visuals
        return "Bandage", {
            released = Color3.fromRGB(100, 200, 255), -- light blue
            pressed  = Color3.fromRGB(70, 150, 200),  -- darker blue
        }
    end
end

local function attemptFoodConsumption()
    if DEBUG_ENABLED then print("[MobileActionController] attemptFoodConsumption called") end
    if not player.Character or not player.Character.PrimaryPart then return end
    
    local playerPos = player.Character.PrimaryPart.Position
    local nearestFood = nil
    local nearestDist = math.huge
    
    for _, consumable in ipairs(CollectionService:GetTagged(CollectionServiceTags.CONSUMABLE)) do
        if consumable:IsDescendantOf(workspace) and consumable.Parent then
            local pos
            if consumable:IsA("Model") and consumable.PrimaryPart then 
                pos = consumable.PrimaryPart.Position
            elseif consumable:IsA("BasePart") then 
                pos = consumable.Position 
            end
            if pos then
                local d = (pos - playerPos).Magnitude
                if d <= EAT_DISTANCE and d < nearestDist then 
                    nearestDist = d
                    nearestFood = consumable
                end
            end
        end
    end
    
    if nearestFood then
        if DEBUG_ENABLED then print("[MobileActionController] Found food to consume:", nearestFood.Name) end
        consumeFoodRemote:FireServer(nearestFood)
    else
        if DEBUG_ENABLED then print("[MobileActionController] No food found within range") end
    end
end

-- Visual helper for drag button (changes appearance based on carrying state)
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

-- ACTIONS registry in priority order (1=highest priority for slot assignment)
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
        key = "Heal",
        actionName = "MobileHealUse",
        canShow = canUseHeal,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then
                activateHeal()
            end
        end,
        visuals = function()
            return getHealVisuals()
        end,
    },
    {
        key = "Store",
        actionName = "MobileStore",
        canShow = canStore,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then Backpack.storeCurrentObject() end
        end,
        visuals = function() return "Store", {released=Color3.new(1,1,1), pressed=Color3.fromRGB(125,125,125)} end,
    },
    {
        key = "Retrieve",
        actionName = "MobileRetrieve",
        canShow = canRetrieve,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then 
                if DEBUG_ENABLED then print("[MobileActionController] Retrieve button pressed - calling Backpack.retrieveTopObject()") end
                Backpack.retrieveTopObject() 
            end
        end,
        visuals = function() return "Unstore", {released=Color3.fromRGB(100,255,100), pressed=Color3.fromRGB(80,200,80)} end,
    },
    {
        key = "Weld",
        actionName = "MobileWeld",
        canShow = canWeld,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then IA.TryWeld() end
        end,
        visuals = function() return "Weld", {released=Color3.new(1,1,1), pressed=Color3.fromRGB(125,125,125)} end,
    },
    {
        key = "Eat",
        actionName = "MobileEat",
        canShow = canEat,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then attemptFoodConsumption() end
        end,
        visuals = function() return "Eat", {released=Color3.new(1,1,1), pressed=Color3.fromRGB(125,125,125)} end,
    },
    {
        key = "Rotate",
        actionName = "MobileRotate",
        canShow = isCarrying,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then IA.RotateOnce() end
        end,
        visuals = function() return "Rotate", {released=Color3.fromRGB(255,170,0), pressed=Color3.fromRGB(180,120,0)} end,
    },
    {
        key = "Axis",
        actionName = "MobileAxis",
        canShow = isCarrying,
        onAction = function(_, inputState)
            if inputState == Enum.UserInputState.Begin then IA.CycleAxis() end
        end,
        visuals = function() return "Axis", {released=Color3.fromRGB(0,170,255), pressed=Color3.fromRGB(0,120,180)} end,
    },
}
local cache = {}

-- Custom positions for each action button (relative to jump button)
local BUTTON_POSITIONS = {
    Drag     = UDim2.new(0.728, 0, -0.545, 0),      -- drag moved down from -0.745 to -0.545
    Store    = UDim2.new(-1.472, 0, -0.312, 0),     -- store moved higher from 0.088 to -0.312 for more clearance
    Retrieve = UDim2.new(-1.522, 0, -0.8, 0),       -- retrieve moved higher from -0.5 to -0.8 for more clearance
    Weld     = UDim2.new(-0.522, 0, -0.062, 0),     -- weld moved down from -0.262 to -0.062
    Eat      = UDim2.new(-0.522, 0, 0.688, 0),      -- eat moved down from 0.488 to 0.688
    Rotate   = UDim2.new(-0.005, 0, -0.545, 0),     -- rotate moved down from -0.745 to -0.545
    Axis     = UDim2.new(0.728, 0, -1.2, 0),        -- axis moved down from -1.4 to -1.2
    Heal     = UDim2.new(-0.005, 0, 0.188, 0),      -- near rotate
}

local function ensureBound(action)
    local success, err = pcall(function()
        ContextActionUtility:BindAction(action.actionName, action.onAction, true)
        local title, colors = action.visuals()
        ContextActionUtility:SetTitle(action.actionName, title)
        ContextActionUtility:SetReleasedColor(action.actionName, colors.released)
        ContextActionUtility:SetPressedColor(action.actionName, colors.pressed)
        
        -- Override position with our custom position
        task.defer(function()
            local button = ContextActionUtility:GetButton(action.actionName)
            if button and BUTTON_POSITIONS[action.key] then
                button.Position = BUTTON_POSITIONS[action.key]
                if DEBUG_ENABLED then print("[MobileActionController] Set position for", action.key, "to", tostring(BUTTON_POSITIONS[action.key])) end
            end
        end)
    end)
    
    if not success then
        if DEBUG_ENABLED then print("[MobileActionController] ERROR binding", action.key, ":", err) end
    end
end

local function ensureUnbound(action)
    ContextActionUtility:UnbindAction(action.actionName)
end

local updateCount = 0
local function update()
    updateCount = updateCount + 1
    if updateCount % 100 == 1 then -- Print every 100 updates (~5 seconds)
        if DEBUG_ENABLED then print("[MobileActionController] Update cycle", updateCount) end
    end
    
    -- Rebind in priority order each tick based on availability
    for _, action in ipairs(ACTIONS) do
        local shouldShow = false
        local ok, result = pcall(action.canShow)
        if ok then 
            shouldShow = result == true 
        else
            if DEBUG_ENABLED then print("[MobileActionController] ERROR in", action.key, "canShow:", result) end
        end

        if updateCount % 100 == 1 then -- Debug every 100 updates
            if DEBUG_ENABLED then print("[MobileActionController]", action.key, "shouldShow:", shouldShow, "cached:", cache[action.key] ~= nil) end
        end

        if shouldShow then
            -- Bind if not already bound
            if not cache[action.key] then
                ensureBound(action)
                cache[action.key] = true
            end
            
            -- Update visuals only if changed (performance optimization)
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
            -- Unbind if currently bound
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

-- 0.05s update loop with accumulator for performance
local acc = 0
local INTERVAL = 0.05
RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc >= INTERVAL then
        acc = 0
        update()
    end
end)

if DEBUG_ENABLED then print("[MobileActionController] Update loop started") end

-- Mobile action buttons system is now active and ready