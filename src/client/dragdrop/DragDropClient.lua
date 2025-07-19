--[[
    DragDropClient.lua
    Client-side drag and drop handling
]]--

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragDropConfig = require(ReplicatedStorage.Shared.config.DragDropConfig)

local DragDropClient = {}
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Drag state
local isDragging = false
local draggedObject = nil
local dragConstraint = nil
local dragConnection = nil
local highlightObject = nil

-- Network events (will be created by server)
local remoteEvents = {}

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

local function isDraggableObject(object)
    if not object or not object.Parent then return false end
    
    local parent = object.Parent
    
    -- Exclude environment objects (these should stay anchored)
    if parent and (parent.Name == "SpawnedVegetation" or 
                  parent.Name == "SpawnedRocks" or 
                  parent.Name == "SpawnedStructures" or
                  parent.Name == "Chunks") then
        print("Ignoring environment object:", object.Name, "in", parent.Name)
        return false
    end
    
    -- Only allow UNANCHORED parts for dragging
    if object:IsA("Part") and not object.Anchored and parent == workspace then
        print("Found draggable unanchored part:", object.Name)
        return true
    end
    
    print("Object not draggable - either anchored or not in workspace")
    return false
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
    
    isDragging = true
    draggedObject = object
    
    highlightObject = createHighlight(object)
    
    dragConstraint = Instance.new("BodyPosition")
    dragConstraint.MaxForce = Vector3.new(200000, 200000, 200000)  -- Maximum force for instant response
    dragConstraint.Position = object.Position
    dragConstraint.D = 1000  -- Lower damping for faster movement
    dragConstraint.P = 100000  -- Maximum power for near-instant response
    dragConstraint.Parent = object
    
    -- Start drag update loop
    dragConnection = RunService.Heartbeat:Connect(function()
        if draggedObject and dragConstraint then
            local targetPos = getMouseWorldPosition()
            dragConstraint.Position = targetPos
        end
    end)
    
    print("Started dragging:", object.Name)
end

local function stopDrag()
    if not isDragging then return end
    
    print("DEBUG: Stopping drag")
    
    -- Clean up constraint
    if dragConstraint then
        dragConstraint:Destroy()
        dragConstraint = nil
    end
    
    -- Stop update loop
    if dragConnection then
        dragConnection:Disconnect()
        dragConnection = nil
    end
    
    -- Remove highlight
    removeHighlight()
    
    if draggedObject then
        print("Stopped dragging:", draggedObject.Name)
    end
    
    -- Reset state
    isDragging = false
    draggedObject = nil
end

-- Input handling
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

function DragDropClient.init()
    print("Initializing drag and drop client...")
    
    -- Debug: Check if we can find spawned objects
    task.wait(2) -- Wait for models to spawn
    
    local workspace = game.Workspace
    print("SpawnedVegetation folder exists:", workspace:FindFirstChild("SpawnedVegetation") ~= nil)
    print("SpawnedRocks folder exists:", workspace:FindFirstChild("SpawnedRocks") ~= nil)
    print("SpawnedStructures folder exists:", workspace:FindFirstChild("SpawnedStructures") ~= nil)
    
    -- Connect input events
    mouse.Button1Down:Connect(onMouseButton1Down)
    mouse.Button1Up:Connect(onMouseButton1Up)
    
    print("Drag and drop client ready!")
end

return DragDropClient































