-- src/client/ui/DesktopHints.client.lua
-- Wires existing interaction systems to your desktop hint GUI.
-- Assumes PlayerGui/DesktopGui/HintFrame with Frames: Store, Weld, Eat, Drag, Sprint, Rotate, Axis

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local DragDropConfig = require(ReplicatedStorage.Shared.config.DragDropConfig)

-- Wait for global accessors provided by existing systems
repeat task.wait(0.05) until _G.InteractableHandler
repeat task.wait(0.05) until _G.BackpackController

local InteractableHandler = _G.InteractableHandler
local BackpackController = _G.BackpackController

-- Locate Desktop GUI and hint frames (resilient across respawns)
local desktopGui : ScreenGui? = nil
local hintFrame : Frame? = nil
local frames = {
    Store  = nil,
    Weld   = nil,
    Eat    = nil,
    Drag   = nil,
    Sprint = nil,
    Rotate = nil,
    Axis   = nil,
}

local ancestryConns = {}
local function disconnectAncestryConns()
    for _, c in ipairs(ancestryConns) do
        if c then c:Disconnect() end
    end
    table.clear(ancestryConns)
end

local function bindGuiElements()
    if not playerGui or not playerGui.Parent then
        playerGui = player:WaitForChild("PlayerGui")
    end

    desktopGui = playerGui:FindFirstChild("DesktopGui")
    if not desktopGui then
        -- Not fatal; will retry on next resolve
        return false
    end

    hintFrame = desktopGui:FindFirstChild("HintFrame")
    if not hintFrame then
        return false
    end

    frames.Store  = hintFrame:FindFirstChild("Store")
    frames.Weld   = hintFrame:FindFirstChild("Weld")
    frames.Eat    = hintFrame:FindFirstChild("Eat")
    frames.Drag   = hintFrame:FindFirstChild("Drag")
    frames.Sprint = hintFrame:FindFirstChild("Sprint")
    frames.Rotate = hintFrame:FindFirstChild("Rotate")
    frames.Axis   = hintFrame:FindFirstChild("Axis")

    -- Watch for GUI being destroyed/replaced
    disconnectAncestryConns()
    table.insert(ancestryConns, desktopGui.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            -- DesktopGui removed, will rebind on next update tick
            desktopGui = nil
            hintFrame = nil
        end
    end))
    table.insert(ancestryConns, hintFrame.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            hintFrame = nil
        end
    end))

    return true
end

-- Helper to safely set visibility
local function setVisible(guiObject, isVisible)
    if guiObject then
        guiObject.Visible = isVisible == true
    end
end

-- FoodConsumption used an internal sack-check; reproduce minimal logic here to avoid require chain
local function isSackEquipped()
    local char = player.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false end
    local name = string.lower(tool.Name)
    return name == "sack" or name == "backpack" or string.find(name, "sack") or string.find(name, "backpack")
end

-- Can eat: nearest CONSUMABLE within FoodConsumption distance
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

-- Can drag: current crosshair target is draggable and not currently carrying
local function canDrag()
    if InteractableHandler.IsCarrying and InteractableHandler.IsCarrying() then return false end
    local target = InteractableHandler.GetCurrentTarget and InteractableHandler.GetCurrentTarget()
    if not target then return false end
    return CollectionServiceTags.isDraggable(target)
end

-- Can store: target is storable, backpack equipped (Backpack folder on character), and not carrying
local function backpackEquipped()
    local char = player.Character
    return char and char:FindFirstChild("Backpack") ~= nil
end

local function canStore()
    if not backpackEquipped() then return false end
    if InteractableHandler.IsCarrying and InteractableHandler.IsCarrying() then return false end
    local target = InteractableHandler.GetCurrentTarget and InteractableHandler.GetCurrentTarget()
    if not target then return false end
    return CollectionServiceTags.hasTag(target, CollectionServiceTags.STORABLE)
end

-- Can weld: when carrying and there exists at least one touching weldable BasePart
local function hasAnchoredParts(object)
    local partToCheck
    if not object then return false end
    if object:IsA("BasePart") then
        partToCheck = object
    elseif object.PrimaryPart then
        partToCheck = object.PrimaryPart
    else
        for _, d in ipairs(object:GetDescendants()) do
            if d:IsA("BasePart") then partToCheck = d break end
        end
    end
    if partToCheck and partToCheck.AssemblyRootPart then
        return partToCheck.AssemblyRootPart.Anchored
    end
    return false
end

local function canWeld()
    if not (InteractableHandler.IsCarrying and InteractableHandler.IsCarrying()) then return false end
    local target = InteractableHandler.GetCurrentTarget and InteractableHandler.GetCurrentTarget()
    if not target or hasAnchoredParts(target) then return false end
    -- Use GetTouchingParts on a representative BasePart to infer weld opportunities
    local part
    if target:IsA("BasePart") then
        part = target
    elseif target.PrimaryPart then
        part = target.PrimaryPart
    else
        for _, d in ipairs(target:GetDescendants()) do
            if d:IsA("BasePart") then part = d break end
        end
    end
    if not part then return false end
    for _, touching in ipairs(part:GetTouchingParts()) do
        if touching and touching:IsDescendantOf(workspace) and touching ~= part then
            if CollectionServiceTags.isWeldable(touching) then
                return true
            end
        end
    end
    return false
end

-- Rotate/Axis: visible whenever carrying
local function isCarrying()
    return InteractableHandler.IsCarrying and InteractableHandler.IsCarrying()
end

-- Sprint: show when humanoid exists (desktop only GUI is shown so keyboard assumed)
local function canSprint()
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil
end

-- Track previous state to avoid redundant property sets
local prev = {
    Store=false, Weld=false, Eat=false, Drag=false, Sprint=false, Rotate=false, Axis=false
}

local function update()
    local state = {
        Store  = canStore(),
        Weld   = canWeld(),
        Eat    = canEat(),
        Drag   = canDrag(),
        Sprint = canSprint(),
        Rotate = isCarrying(),
        Axis   = isCarrying(),
    }

    for key, val in pairs(state) do
        if prev[key] ~= val then
            setVisible(frames[key], val)
            prev[key] = val
        end
    end
end

-- Initialize and reset helpers
local function hideAll()
    for name, frame in pairs(frames) do
        setVisible(frame, false)
        prev[name] = false
    end
end

-- First bind attempt
bindGuiElements()
hideAll()

-- Re-hide on respawn to avoid default GUI showing everything
local function onCharacterAdded()
    hideAll()
    -- Rebind GUI references shortly after spawn as some GUIs are recreated lazily
    task.defer(function()
        bindGuiElements()
    end)
end
if player.Character then onCharacterAdded() end
player.CharacterAdded:Connect(onCharacterAdded)

-- Heartbeat loop to keep hints responsive without overwhelming frame budget
local accumulator = 0
local UPDATE_INTERVAL = 0.05 -- 20 Hz, fast and light
RS.Heartbeat:Connect(function(dt)
    accumulator += dt
    if accumulator >= UPDATE_INTERVAL then
        accumulator = 0
        -- Rebind if GUI got recreated
        if not desktopGui or not hintFrame then
            bindGuiElements()
        end
        update()
    end
end)

