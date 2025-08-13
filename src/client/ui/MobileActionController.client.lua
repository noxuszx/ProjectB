-- src/client/ui/MobileActionController.client.lua
-- Mobile touch buttons for drag/drop, backpack, food, welding, and rotation actions

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local IS_MOBILE = UserInputService.TouchEnabled

print("[MobileActionController] === DEBUG START ===")
print("[MobileActionController] TouchEnabled:", UserInputService.TouchEnabled)
print("[MobileActionController] MouseEnabled:", UserInputService.MouseEnabled)
print("[MobileActionController] KeyboardEnabled:", UserInputService.KeyboardEnabled)
print("[MobileActionController] IS_MOBILE:", IS_MOBILE)

if not IS_MOBILE then 
    print("[MobileActionController] Not mobile device - exiting")
    return 
end

print("[MobileActionController] Loading dependencies...")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
print("[MobileActionController] CollectionServiceTags loaded")

local ContextActionUtility = require(ReplicatedStorage.Shared.modules.ContextActionUtility)
print("[MobileActionController] ContextActionUtility loaded")

-- Wait for globals provided by other controllers
print("[MobileActionController] Waiting for _G.InteractableHandler...")
repeat task.wait(0.05) until _G.InteractableHandler
print("[MobileActionController] _G.InteractableHandler found!")

print("[MobileActionController] Waiting for _G.BackpackController...")
repeat task.wait(0.05) until _G.BackpackController
print("[MobileActionController] _G.BackpackController found!")

local IA = _G.InteractableHandler
local Backpack = _G.BackpackController

-- Get ConsumeFood RemoteEvent (same as FoodConsumption does)
print("[MobileActionController] Getting ConsumeFood RemoteEvent...")
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local consumeFoodRemote = remotesFolder:WaitForChild("ConsumeFood")
print("[MobileActionController] ConsumeFood RemoteEvent found")

print("[MobileActionController] Initialized on mobile device")

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

local function attemptFoodConsumption()
    print("[MobileActionController] attemptFoodConsumption called")
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
        print("[MobileActionController] Found food to consume:", nearestFood.Name)
        consumeFoodRemote:FireServer(nearestFood)
    else
        print("[MobileActionController] No food found within range")
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
                print("[MobileActionController] Retrieve button pressed - calling Backpack.retrieveTopObject()")
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
    Store    = UDim2.new(-1.472, 0, 0.488, 0),       -- store (unchanged)
    Retrieve = UDim2.new(-1.522, 0, -0.3, 0),       -- unstore (unchanged)
    Weld     = UDim2.new(-0.522, 0, -0.062, 0),      -- weld moved down from -0.262 to -0.062
    Eat      = UDim2.new(-0.522, 0, 0.688, 0),       -- eat moved down from 0.488 to 0.688
    Rotate   = UDim2.new(-0.005, 0, -0.545, 0),      -- rotate moved down from -0.745 to -0.545
    Axis     = UDim2.new(0.728, 0, -1.2, 0),         -- axis moved down from -1.4 to -1.2
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
                print("[MobileActionController] Set position for", action.key, "to", tostring(BUTTON_POSITIONS[action.key]))
            end
        end)
    end)
    
    if not success then
        print("[MobileActionController] ERROR binding", action.key, ":", err)
    end
end

local function ensureUnbound(action)
    ContextActionUtility:UnbindAction(action.actionName)
end

local updateCount = 0
local function update()
    updateCount = updateCount + 1
    if updateCount % 100 == 1 then -- Print every 100 updates (~5 seconds)
        print("[MobileActionController] Update cycle", updateCount)
    end
    
    -- Rebind in priority order each tick based on availability
    for _, action in ipairs(ACTIONS) do
        local shouldShow = false
        local ok, result = pcall(action.canShow)
        if ok then 
            shouldShow = result == true 
        else
            print("[MobileActionController] ERROR in", action.key, "canShow:", result)
        end

        if updateCount % 100 == 1 then -- Debug every 100 updates
            print("[MobileActionController]", action.key, "shouldShow:", shouldShow, "cached:", cache[action.key] ~= nil)
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

print("[MobileActionController] Update loop started")

-- Mobile action buttons system is now active and ready