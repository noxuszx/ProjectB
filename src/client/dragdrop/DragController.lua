--[[
    DragController.lua
    Main drag-drop controller that coordinates input, physics, and network systems
    Implements the "Dead Rails" style single-click drag, single-click drop system
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Import system components
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local DragDropSystemConfig = require(ReplicatedStorage.Shared.config.DragDropSystemConfig)
local DragPhysicsManager = require(script.Parent.DragPhysicsManager)
local DragNetworkManager = require(script.Parent.DragNetworkManager)

-- Import existing weld system for integration
local WeldSystem = require(script.Parent.WeldSystem)

local DragController = {}

-- Controller state
local isInitialized = false
local currentDraggedObject = nil
local dragState = "idle"  -- "idle", "requesting", "dragging", "dropping"
local lastClickTime = 0
local dragStartPosition = nil

-- Input connections
local inputConnections = {}

-- Player references
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Initialize the drag controller
function DragController.init()
    if isInitialized then
        warn("DragController: Already initialized")
        return false
    end
    
    print("DragController: Initializing main drag controller...")
    
    -- Initialize subsystems
    local physicsSuccess = DragPhysicsManager.init()
    local networkSuccess = DragNetworkManager.init()
    
    if not physicsSuccess or not networkSuccess then
        warn("DragController: Failed to initialize subsystems")
        return false
    end
    
    -- Set up network callbacks
    setupNetworkCallbacks()
    
    -- Set up input handling
    setupInputHandling()
    
    -- Set up update loop
    setupUpdateLoop()
    
    isInitialized = true
    print("DragController: Main drag controller initialized successfully")
    
    return true
end

-- Set up network event callbacks
function setupNetworkCallbacks()
    -- Handle validation results from server
    DragNetworkManager.onValidationResult = function(object, action, success, reason, data)
        handleValidationResult(object, action, success, reason, data)
    end
    
    -- Handle drag state synchronization from server
    DragNetworkManager.onDragStateSync = function(object, state, position)
        handleDragStateSync(object, state, position)
    end
end

-- Set up input handling for mouse clicks
function setupInputHandling()
    -- Handle mouse button clicks
    inputConnections.mouseButton1 = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            handleMouseClick()
        end
    end)

    -- Handle weld key (Z) integration
    inputConnections.weldKey = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.KeyCode == DragDropSystemConfig.INTEGRATION.WELD_KEY then
            handleWeldKey()
        end
    end)
    
    -- Handle mouse movement for drag updates
    inputConnections.mouseMove = mouse.Move:Connect(function()
        if dragState == "dragging" and currentDraggedObject then
            updateDragPosition()
        end
    end)
end

-- Set up main update loop
function setupUpdateLoop()
    inputConnections.heartbeat = RunService.Heartbeat:Connect(function()
        -- Check for network timeouts
        DragNetworkManager.checkTimeouts()
        
        -- Update drag physics if needed
        if dragState == "dragging" and currentDraggedObject then
            updateDragPosition()
        end
    end)
end

-- Handle mouse click events
function handleMouseClick()
    local currentTime = tick()

    -- Prevent rapid clicking
    if currentTime - lastClickTime < 0.1 then
        return
    end
    lastClickTime = currentTime

    if dragState == "idle" then
        -- Try to start dragging
        attemptStartDrag()
    elseif dragState == "dragging" then
        -- Try to stop dragging
        attemptStopDrag()
    end
end

-- Handle weld key press (Z key integration)
function handleWeldKey()
    if not DragDropSystemConfig.INTEGRATION.WELD_SYSTEM_ENABLED then
        return
    end

    if dragState == "dragging" and currentDraggedObject then
        -- Weld the currently dragged object
        local weld = WeldSystem.weldObject(currentDraggedObject, nil)

        if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
            if weld then
                print("DragController: Welded dragged object:", currentDraggedObject.Name)
            else
                print("DragController: Failed to weld dragged object:", currentDraggedObject.Name)
            end
        end
    else
        -- Use existing weld system behavior for non-dragged objects
        WeldSystem.weldObject(nil, nil)
    end
end

-- Attempt to start dragging an object
function attemptStartDrag()
    local targetObject = getObjectUnderMouse()
    
    if not targetObject then
        if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
            print("DragController: No object under mouse")
        end
        return
    end
    
    -- Check if object is draggable
    if not CollectionServiceTags.isDraggable(targetObject) then
        if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
            print("DragController: Object not draggable:", targetObject.Name)
        end
        return
    end
    
    -- Check if object is already being dragged
    if CollectionServiceTags.isDragInProgress(targetObject) then
        if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
            print("DragController: Object already being dragged:", targetObject.Name)
        end
        return
    end
    
    -- Start drag process
    currentDraggedObject = targetObject
    dragState = "requesting"
    dragStartPosition = targetObject.Position
    
    if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
        print("DragController: Requesting drag start for:", targetObject.Name)
    end
    
    -- Request permission from server if validation is enabled
    if DragNetworkManager.isServerValidationEnabled() then
        local success = DragNetworkManager.requestStartDrag(targetObject, dragStartPosition)
        if not success then
            -- Reset state if request failed
            resetDragState()
        end
    else
        -- Start drag immediately if server validation is disabled
        startDragImmediate(targetObject)
    end
end

-- Attempt to stop dragging the current object
function attemptStopDrag()
    if not currentDraggedObject then
        return
    end
    
    local finalPosition = currentDraggedObject.Position
    dragState = "dropping"
    
    if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
        print("DragController: Requesting drag stop for:", currentDraggedObject.Name)
    end
    
    -- Request permission from server if validation is enabled
    if DragNetworkManager.isServerValidationEnabled() then
        local success = DragNetworkManager.requestStopDrag(currentDraggedObject, finalPosition)
        if not success then
            -- Continue dragging if request failed
            dragState = "dragging"
        end
    else
        -- Stop drag immediately if server validation is disabled
        stopDragImmediate(currentDraggedObject, finalPosition)
    end
end

-- Start dragging immediately (for client-only mode or after server approval)
function startDragImmediate(object)
    if not object then
        return false
    end
    
    -- Start physics-based dragging
    local physicsSuccess = DragPhysicsManager.startDrag(object, dragStartPosition)
    if not physicsSuccess then
        warn("DragController: Failed to start physics for:", object.Name)
        resetDragState()
        return false
    end
    
    -- Update object state
    CollectionServiceTags.setDragInProgress(object, true)
    
    -- Set ownership if system is enabled
    if DragDropSystemConfig.SECURITY.ENABLE_OWNERSHIP_SYSTEM then
        CollectionServiceTags.setPlayerOwnership(object, player)
    end
    
    -- Update controller state
    currentDraggedObject = object
    dragState = "dragging"
    
    if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
        print("DragController: Started dragging:", object.Name)
    end
    
    return true
end

-- Stop dragging immediately (for client-only mode or after server approval)
function stopDragImmediate(object, finalPosition)
    if not object then
        return false
    end
    
    -- Stop physics-based dragging
    DragPhysicsManager.stopDrag(object, finalPosition)
    
    -- Update object state
    CollectionServiceTags.setDragInProgress(object, false)
    
    -- Clear ownership if we own it
    if CollectionServiceTags.isPlayerOwned(object, player) then
        CollectionServiceTags.clearPlayerOwnership(object)
    end
    
    -- Reset controller state
    resetDragState()
    
    if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
        print("DragController: Stopped dragging:", object.Name)
    end
    
    return true
end

-- Update drag position based on mouse movement
function updateDragPosition()
    if not currentDraggedObject or dragState ~= "dragging" then
        return
    end
    
    -- Calculate new drag position
    local newPosition = calculateDragPosition()
    local newCFrame = calculateDragCFrame(newPosition)
    
    -- Update physics target
    DragPhysicsManager.updateDragTarget(currentDraggedObject, newPosition, newCFrame)
    
    -- Send position update to server (batched)
    if DragNetworkManager.isServerValidationEnabled() then
        DragNetworkManager.queuePositionUpdate(currentDraggedObject, newPosition)
    end
end

-- Calculate drag position based on mouse and camera
function calculateDragPosition()
    local camera = workspace.CurrentCamera
    local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    
    -- Calculate position at configured drag distance and height
    local dragDistance = DragDropSystemConfig.MAX_DRAG_DISTANCE
    local dragHeight = DragDropSystemConfig.DRAG_HEIGHT_OFFSET
    
    local targetPosition = unitRay.Origin + (unitRay.Direction * dragDistance)
    
    -- Adjust for terrain collision
    local raycast = workspace:Raycast(unitRay.Origin, unitRay.Direction * dragDistance)
    if raycast then
        targetPosition = raycast.Position + Vector3.new(0, dragHeight, 0)
    end
    
    return targetPosition
end

-- Calculate drag CFrame for orientation
function calculateDragCFrame(position)
    local camera = workspace.CurrentCamera
    local lookDirection = camera.CFrame.LookVector
    return CFrame.lookAt(position, position + lookDirection)
end

-- Get object under mouse cursor
function getObjectUnderMouse()
    local camera = workspace.CurrentCamera
    local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    
    -- Cast ray to find object
    local raycast = workspace:Raycast(unitRay.Origin, unitRay.Direction * DragDropSystemConfig.MAX_DRAG_DISTANCE)
    
    if raycast and raycast.Instance then
        return raycast.Instance
    end
    
    return nil
end

-- Handle validation result from server
function handleValidationResult(object, action, success, reason, data)
    if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
        print("DragController: Validation result:", action, success, reason)
    end
    
    if action == "startDrag" then
        if success then
            startDragImmediate(object)
        else
            -- Reset state if drag was denied
            resetDragState()
            if reason then
                warn("DragController: Drag denied:", reason)
            end
        end
    elseif action == "stopDrag" then
        if success then
            local finalPosition = data or object.Position
            stopDragImmediate(object, finalPosition)
        else
            -- Continue dragging if drop was denied
            dragState = "dragging"
            if reason then
                warn("DragController: Drop denied:", reason)
            end
        end
    end
end

-- Handle drag state synchronization from server
function handleDragStateSync(object, state, position)
    if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
        print("DragController: Drag state sync:", object.Name, state)
    end
    
    -- Update visual state for other players' drags
    if object ~= currentDraggedObject then
        if state == "started" then
            CollectionServiceTags.setDragInProgress(object, true)
        elseif state == "stopped" then
            CollectionServiceTags.setDragInProgress(object, false)
            if position then
                object.Position = position
            end
        end
    end
end

-- Reset drag controller state
function resetDragState()
    currentDraggedObject = nil
    dragState = "idle"
    dragStartPosition = nil
end

-- Get controller status
function DragController.getStatus()
    return {
        initialized = isInitialized,
        dragState = dragState,
        currentObject = currentDraggedObject and currentDraggedObject.Name or "none",
        physicsStatus = DragPhysicsManager.getStatus(),
        networkStatus = DragNetworkManager.getStatus()
    }
end

-- Emergency stop all drags
function DragController.emergencyStop()
    if currentDraggedObject then
        DragPhysicsManager.stopDrag(currentDraggedObject)
        CollectionServiceTags.setDragInProgress(currentDraggedObject, false)
        CollectionServiceTags.clearPlayerOwnership(currentDraggedObject)
    end
    
    resetDragState()
    DragPhysicsManager.cleanupAll()
    
    print("DragController: Emergency stop executed")
end

-- Shutdown the controller
function DragController.shutdown()
    if not isInitialized then
        return
    end
    
    -- Emergency stop any active drags
    DragController.emergencyStop()
    
    -- Disconnect input connections
    for _, connection in pairs(inputConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    inputConnections = {}
    
    -- Shutdown subsystems
    DragPhysicsManager.shutdown()
    DragNetworkManager.cleanup()
    
    isInitialized = false
    print("DragController: Shutdown complete")
end

return DragController
