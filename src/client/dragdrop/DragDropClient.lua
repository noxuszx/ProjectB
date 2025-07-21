--[[
    DragDropClient.lua
    Client-side drag and drop handling
]]--

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragDropConfig = require(ReplicatedStorage.Shared.config.DragDropConfig)
local WeldSystem = require(script.Parent.WeldSystem)

local DragDropClient = {}
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Drag state
local isDragging = false
local draggedObject = nil
local dragConstraint = nil
local dragBodyPositions = nil
local dragConnection = nil
local highlightObject = nil

local remoteEvents = {}

local currentRotation = CFrame.new()
local rotationStep = math.rad(15)
local selectedAxis = "Y"
local axisOrder = {"Y", "X", "Z"}
local isWelded = false
local currentWeld = nil

local function cycleAxis()
    if not isDragging then return end
    
    local currentIndex = 1
    for i, axis in ipairs(axisOrder) do
        if axis == selectedAxis then
            currentIndex = i
            break
        end
    end
    
    local nextIndex = (currentIndex % #axisOrder) + 1
    selectedAxis = axisOrder[nextIndex]
    
    print("Rotation axis changed to:", selectedAxis)
end

local function rotateObject(direction)
    if not draggedObject then return end
    
    local angle = rotationStep * direction
    local rotationCFrame
    
    if selectedAxis == "Y" then
        rotationCFrame = CFrame.Angles(0, angle, 0)
    elseif selectedAxis == "X" then
        rotationCFrame = CFrame.Angles(angle, 0, 0)
    elseif selectedAxis == "Z" then
        rotationCFrame = CFrame.Angles(0, 0, angle)
    end
    
    currentRotation = currentRotation * rotationCFrame
    
    local currentPos = draggedObject.Position
    draggedObject.CFrame = CFrame.new(currentPos) * currentRotation
    
    print("Rotated", direction > 0 and "clockwise" or "counterclockwise", "on", selectedAxis, "axis")
end

local function createHighlight(object)
    local highlight = Instance.new("SelectionBox")
    highlight.Adornee = object
    highlight.Color3 = DragDropConfig.HIGHLIGHT_COLOR
    highlight.Transparency = DragDropConfig.HIGHLIGHT_TRANSPARENCY
    highlight.LineThickness = 0.2
    highlight.Parent = object
    return highlight
end

local function removeHighlight()
    if highlightObject then
        highlightObject:Destroy()
        highlightObject = nil
    end
end

-- Cache for draggable object validation - CLEAR CACHE
local draggableCache = {}
local cacheSize = 0
local MAX_CACHE_SIZE = 100

local function isDraggableObject(object)
    if not object or not object.Parent then return false end
    
    -- Check cache first using object reference as key
    if draggableCache[object] ~= nil then
        return draggableCache[object]
    end
    
    local parent = object.Parent
    local result = false
    
    if parent and (parent.Name == "SpawnedVegetation" or 
                   parent.Name == "SpawnedRocks" or 
                   parent.Name == "SpawnedStructures" or
                   parent.Name == "Chunks") then
        result = false

    elseif object:IsA("Part") and not object.Anchored and parent == workspace then
        result = true
    else
        result = false
    end
    
    if cacheSize >= MAX_CACHE_SIZE then
        draggableCache = {}
        cacheSize = 0
    end
    
    draggableCache[object] = result
    cacheSize = cacheSize + 1
    
    return result
end

local function getMouseWorldPosition()
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return Vector3.new(0, 0, 0)
    end
    
    local playerPos = player.Character.HumanoidRootPart.Position
    local camera = workspace.CurrentCamera
    
    if camera.CameraType == Enum.CameraType.Custom and 
        (playerPos - camera.CFrame.Position).Magnitude < 2 then
        
        local lookDirection = camera.CFrame.LookVector
        local targetPosition = playerPos + lookDirection * 8
        targetPosition = targetPosition + Vector3.new(0, DragDropConfig.DRAG_HEIGHT_OFFSET, 0)
        
        return targetPosition
    else
        local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {draggedObject}
        
        local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
        
        local targetPosition
        if raycastResult then
            targetPosition = raycastResult.Position + Vector3.new(0, DragDropConfig.DRAG_HEIGHT_OFFSET, 0)
        else
            targetPosition = ray.Origin + ray.Direction * 20
        end
        
        local distance = (targetPosition - playerPos).Magnitude
        if distance > DragDropConfig.MAX_DRAG_DISTANCE then
            local direction = (targetPosition - playerPos).Unit
            targetPosition = playerPos + direction * DragDropConfig.MAX_DRAG_DISTANCE
        end
        
        return targetPosition
    end
end


local function startDrag(object)
    if isDragging or not isDraggableObject(object) then return end
    
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        print("Character not loaded yet")
        return
    end
    
    local distance = (object.Position - player.Character.HumanoidRootPart.Position).Magnitude
    if distance > DragDropConfig.MAX_DRAG_DISTANCE then return end
    
    -- Check if object is welded to non-draggable parts (like terrain/ground)
    for _, child in pairs(object:GetChildren()) do
        if child:IsA("WeldConstraint") and child.Name == "DragDropWeld" then
            local otherPart = child.Part0 == object and child.Part1 or child.Part0
            if otherPart and not isDraggableObject(otherPart) then
                print("Cannot drag - object is welded to", otherPart.Name, ". Press Z to unweld first.")
                return
            end
        end
    end
    
    isDragging = true
    draggedObject = object
    
    -- Get the full welded assembly
    local assembly = WeldSystem.getWeldedAssembly(object, isDraggableObject)
    
    currentRotation = CFrame.new()
    selectedAxis = "Y"
    isWelded = false
    currentWeld = nil
    
    highlightObject = createHighlight(object)
    
    -- Create BodyPosition for each part in the assembly
    local bodyPositions = {}
    local initialOffsets = {}
    
    for _, part in pairs(assembly) do
        local bodyPos = Instance.new("BodyPosition")
        bodyPos.MaxForce = Vector3.new(12000, 12000, 12000)
        bodyPos.Position = part.Position
        bodyPos.D = 1000
        bodyPos.P = 20000
        bodyPos.Parent = part
        
        bodyPositions[part] = bodyPos
        initialOffsets[part] = part.Position - object.Position
    end
    
    dragConstraint = bodyPositions[object]
    dragBodyPositions = bodyPositions
    
    dragConnection = RunService.Heartbeat:Connect(function()
        if draggedObject and dragConstraint then
            local targetPos = getMouseWorldPosition()
            
            for part, bodyPos in pairs(bodyPositions) do
                if part == draggedObject then
                    bodyPos.Position = targetPos
                else
                    bodyPos.Position = targetPos + initialOffsets[part]
                end
            end
        end
    end)
    
    print("Started dragging:", object.Name, "with", #assembly, "connected parts")
    print("Controls: R to cycle axis (" .. selectedAxis .. "), Q/E to rotate, Z to weld/unweld")
end

local function stopDrag()
    if not isDragging then return end
    
    print("DEBUG: Stopping drag")
    
    -- Clean up ALL BodyPosition constraints
    if dragBodyPositions then
        for _, bodyPos in pairs(dragBodyPositions) do
            if bodyPos then
                bodyPos:Destroy()
            end
        end
        dragBodyPositions = nil
    end
    
    if dragConnection then
        dragConnection:Disconnect()
        dragConnection = nil
    end
    
    removeHighlight()
    
    -- DON'T destroy welds here - let them persist!
    currentWeld = nil
    isWelded = false
    
    if draggedObject then
        print("Stopped dragging:", draggedObject.Name)
    end
    
    isDragging = false
    draggedObject = nil
    dragConstraint = nil
end

local function onMouseButton1Down()
    local target = mouse.Target
    print("=== CLICK DEBUG ===")
    print("Mouse clicked on:", target and target.Name or "nil")
    print("Target exists:", target ~= nil)
    
    if target then
        print("Target class:", target.ClassName)
        print("Target parent:", target.Parent and target.Parent.Name or "nil")
        print("Target anchored:", target.Anchored)
        
        local isDraggable = isDraggableObject(target)
        print("Is draggable result:", isDraggable)
        
        if isDraggable then
            print("ATTEMPTING TO START DRAG")
            startDrag(target)
        else
            print("NOT DRAGGABLE - skipping")
        end
    else
        print("No target found")
    end
    print("==================")
end

local function onMouseButton1Up()
    if isDragging then
        stopDrag()
    end
end

local function onKeyDown(key)
    if key.KeyCode == Enum.KeyCode.Z then
        -- Weld works both while dragging and hovering
        currentWeld, isWelded = WeldSystem.weldObject(draggedObject, currentWeld)
    elseif not isDragging then 
        return -- Other keys only work when dragging
    elseif key.KeyCode == Enum.KeyCode.R then
        cycleAxis()
    elseif key.KeyCode == Enum.KeyCode.Q then
        rotateObject(-1)
    elseif key.KeyCode == Enum.KeyCode.E then
        rotateObject(1)
    end
end

function DragDropClient.init()
    print("Initializing drag and drop client...")
    
    mouse.Button1Down:Connect(onMouseButton1Down)
    mouse.Button1Up:Connect(onMouseButton1Up)
    UserInputService.InputBegan:Connect(onKeyDown)
    
    -- Optimized hover detection - only runs when needed
    local lastHoverUpdate = 0
    local HOVER_UPDATE_RATE = 0.05 -- 20fps max for hover detection
    
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime - lastHoverUpdate >= HOVER_UPDATE_RATE then
            WeldSystem.updateHoveredObject(isDragging, isDraggableObject)
            lastHoverUpdate = currentTime
        end
    end)
    
    print("Drag and drop client ready!")
    print("Controls: Click to drag, Hover + Z to weld/unweld, R to cycle axis, Q/E to rotate")
end

return DragDropClient





