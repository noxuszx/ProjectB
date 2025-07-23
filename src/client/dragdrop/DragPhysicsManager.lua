--[[
    DragPhysicsManager.lua
    Physics-based dragging system using AlignPosition/AlignOrientation
    Provides smooth, responsive dragging with proper constraint management
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Import shared utilities and config
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local DragDropSystemConfig = require(ReplicatedStorage.Shared.config.DragDropSystemConfig)

local DragPhysicsManager = {}

-- Physics state tracking
local activeConstraints = {}  -- [object] = {alignPosition, alignOrientation, attachment}
local dragTargets = {}        -- [object] = {targetPosition, targetCFrame}
local physicsConnections = {} -- Heartbeat connections for physics updates
local isInitialized = false

-- Player and camera references
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Initialize the physics manager
function DragPhysicsManager.init()
    if isInitialized then
        warn("DragPhysicsManager: Already initialized")
        return false
    end
    
    print("DragPhysicsManager: Initializing physics-based dragging system...")
    
    -- Set up physics update loop
    setupPhysicsLoop()
    
    isInitialized = true
    print("DragPhysicsManager: Physics manager initialized successfully")
    
    return true
end

-- Set up the main physics update loop
function setupPhysicsLoop()
    physicsConnections.heartbeat = RunService.Heartbeat:Connect(function()
        updateDragPhysics()
    end)
end

-- Start dragging an object with physics constraints
function DragPhysicsManager.startDrag(object, startPosition)
    if not isInitialized then
        warn("DragPhysicsManager: Not initialized")
        return false
    end
    
    if not object or not object.Parent then
        warn("DragPhysicsManager: Invalid object")
        return false
    end
    
    -- Check if object is already being dragged
    if activeConstraints[object] then
        if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
            print("DragPhysicsManager: Object already being dragged:", object.Name)
        end
        return false
    end
    
    -- Get object type for specific settings
    local objectType = CollectionServiceTags.getObjectType(object)
    local settings = DragDropSystemConfig.getObjectSettings(objectType)
    
    -- Create physics constraints
    local success = createDragConstraints(object, settings)
    if not success then
        warn("DragPhysicsManager: Failed to create drag constraints for", object.Name)
        return false
    end
    
    -- Set initial target position
    local initialTarget = startPosition or calculateDragPosition(object)
    dragTargets[object] = {
        targetPosition = initialTarget,
        targetCFrame = CFrame.new(initialTarget, initialTarget + camera.CFrame.LookVector)
    }
    
    -- Disable collision with player during drag
    if DragDropSystemConfig.DISABLE_COLLISION_WHILE_DRAGGING then
        setPlayerCollision(object, false)
    end
    
    if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
        print("DragPhysicsManager: Started dragging", object.Name, "with", objectType, "settings")
    end
    
    return true
end

-- Stop dragging an object and clean up constraints
function DragPhysicsManager.stopDrag(object, finalPosition)
    if not object or not activeConstraints[object] then
        return false
    end
    
    -- Clean up physics constraints
    cleanupConstraints(object)
    
    -- Re-enable collision with player
    if DragDropSystemConfig.DISABLE_COLLISION_WHILE_DRAGGING then
        setPlayerCollision(object, true)
    end
    
    -- Set final position if provided
    if finalPosition then
        object.Position = finalPosition
    end
    
    -- Remove from tracking
    dragTargets[object] = nil
    
    if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
        print("DragPhysicsManager: Stopped dragging", object.Name)
    end
    
    return true
end

-- Update drag target position (called by input system)
function DragPhysicsManager.updateDragTarget(object, newPosition, newCFrame)
    if not dragTargets[object] then
        return false
    end
    
    dragTargets[object].targetPosition = newPosition
    if newCFrame then
        dragTargets[object].targetCFrame = newCFrame
    end
    
    return true
end

-- Create physics constraints for dragging
function createDragConstraints(object, settings)
    -- Create attachment point
    local attachment = Instance.new("Attachment")
    attachment.Name = "DragAttachment"
    attachment.Parent = object
    
    -- Create AlignPosition constraint
    local alignPosition = Instance.new("AlignPosition")
    alignPosition.Name = "DragAlignPosition"
    alignPosition.Attachment0 = attachment
    alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
    alignPosition.ApplyAtCenterOfMass = DragDropSystemConfig.ALIGN_POSITION_SETTINGS.ApplyAtCenterOfMass
    alignPosition.MaxForce = settings.maxForce or DragDropSystemConfig.ALIGN_POSITION_SETTINGS.MaxForce
    alignPosition.MaxVelocity = settings.maxVelocity or DragDropSystemConfig.ALIGN_POSITION_SETTINGS.MaxVelocity
    alignPosition.Responsiveness = settings.responsiveness or DragDropSystemConfig.ALIGN_POSITION_SETTINGS.Responsiveness
    alignPosition.RigidityEnabled = DragDropSystemConfig.ALIGN_POSITION_SETTINGS.RigidityEnabled
    alignPosition.Parent = object
    
    -- Create AlignOrientation constraint (optional, for rotation control)
    local alignOrientation = nil
    if DragDropSystemConfig.USE_ALIGN_ORIENTATION then
        alignOrientation = Instance.new("AlignOrientation")
        alignOrientation.Name = "DragAlignOrientation"
        alignOrientation.Attachment0 = attachment
        alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOrientation.MaxTorque = DragDropSystemConfig.ALIGN_ORIENTATION_SETTINGS.MaxTorque
        alignOrientation.MaxAngularVelocity = DragDropSystemConfig.ALIGN_ORIENTATION_SETTINGS.MaxAngularVelocity
        alignOrientation.Responsiveness = DragDropSystemConfig.ALIGN_ORIENTATION_SETTINGS.Responsiveness
        alignOrientation.RigidityEnabled = DragDropSystemConfig.ALIGN_ORIENTATION_SETTINGS.RigidityEnabled
        alignOrientation.Parent = object
    end
    
    -- Store constraints for cleanup
    activeConstraints[object] = {
        alignPosition = alignPosition,
        alignOrientation = alignOrientation,
        attachment = attachment
    }
    
    return true
end

-- Main physics update loop
function updateDragPhysics()
    for object, target in pairs(dragTargets) do
        local constraints = activeConstraints[object]
        if constraints and constraints.alignPosition then
            -- Update AlignPosition target
            constraints.alignPosition.Position = target.targetPosition
            
            -- Update AlignOrientation target if enabled
            if constraints.alignOrientation and target.targetCFrame then
                constraints.alignOrientation.CFrame = target.targetCFrame
            end
        else
            -- Clean up orphaned targets
            dragTargets[object] = nil
        end
    end
end

-- Calculate drag position based on camera and mouse
function calculateDragPosition(object)
    local mouse = player:GetMouse()
    local camera = Workspace.CurrentCamera
    
    -- Cast ray from camera through mouse position
    local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local rayDirection = unitRay.Direction * DragDropSystemConfig.MAX_DRAG_DISTANCE
    
    -- Calculate position at drag height offset
    local dragHeight = DragDropSystemConfig.DRAG_HEIGHT_OFFSET
    local targetPosition = unitRay.Origin + rayDirection
    
    -- Adjust height based on terrain or other objects
    local raycast = Workspace:Raycast(unitRay.Origin, rayDirection)
    if raycast then
        targetPosition = raycast.Position + Vector3.new(0, dragHeight, 0)
    else
        -- Use default height if no collision
        targetPosition = targetPosition + Vector3.new(0, dragHeight, 0)
    end
    
    return targetPosition
end

-- Set collision between object and player
function setPlayerCollision(object, enabled)
    local character = player.Character
    if not character then
        return
    end
    
    -- Create or remove NoCollisionConstraint
    local constraintName = "DragNoCollision_" .. player.UserId
    
    if enabled then
        -- Remove no-collision constraint
        local existingConstraint = object:FindFirstChild(constraintName)
        if existingConstraint then
            existingConstraint:Destroy()
        end
    else
        -- Create no-collision constraint with player
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            local noCollision = Instance.new("NoCollisionConstraint")
            noCollision.Name = constraintName
            noCollision.Part0 = object
            noCollision.Part1 = humanoidRootPart
            noCollision.Parent = object
        end
    end
end

-- Clean up physics constraints for an object
function cleanupConstraints(object)
    local constraints = activeConstraints[object]
    if not constraints then
        return
    end
    
    -- Destroy all constraint objects
    if constraints.alignPosition then
        constraints.alignPosition:Destroy()
    end
    
    if constraints.alignOrientation then
        constraints.alignOrientation:Destroy()
    end
    
    if constraints.attachment then
        constraints.attachment:Destroy()
    end
    
    -- Remove from tracking
    activeConstraints[object] = nil
end

-- Get all currently dragged objects
function DragPhysicsManager.getDraggedObjects()
    local objects = {}
    for object, _ in pairs(activeConstraints) do
        table.insert(objects, object)
    end
    return objects
end

-- Check if an object is being dragged
function DragPhysicsManager.isDragging(object)
    return activeConstraints[object] ~= nil
end

-- Get physics status for debugging
function DragPhysicsManager.getStatus()
    local draggedCount = 0
    local constraintCount = 0
    
    for object, constraints in pairs(activeConstraints) do
        draggedCount = draggedCount + 1
        if constraints.alignPosition then constraintCount = constraintCount + 1 end
        if constraints.alignOrientation then constraintCount = constraintCount + 1 end
        if constraints.attachment then constraintCount = constraintCount + 1 end
    end
    
    return {
        initialized = isInitialized,
        draggedObjects = draggedCount,
        activeConstraints = constraintCount,
        targetCount = #dragTargets
    }
end

-- Emergency cleanup (useful for debugging)
function DragPhysicsManager.cleanupAll()
    -- Clean up all active constraints
    for object, _ in pairs(activeConstraints) do
        cleanupConstraints(object)
        
        -- Re-enable collision
        if DragDropSystemConfig.DISABLE_COLLISION_WHILE_DRAGGING then
            setPlayerCollision(object, true)
        end
    end
    
    -- Clear tracking tables
    activeConstraints = {}
    dragTargets = {}
    
    print("DragPhysicsManager: Emergency cleanup complete")
end

-- Shutdown the physics manager
function DragPhysicsManager.shutdown()
    if not isInitialized then
        return
    end
    
    -- Clean up all active drags
    DragPhysicsManager.cleanupAll()
    
    -- Disconnect physics connections
    for _, connection in pairs(physicsConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    physicsConnections = {}
    
    isInitialized = false
    print("DragPhysicsManager: Shutdown complete")
end

-- Adjust physics settings for specific object type
function DragPhysicsManager.adjustPhysicsSettings(object, objectType)
    local constraints = activeConstraints[object]
    if not constraints or not constraints.alignPosition then
        return false
    end
    
    local settings = DragDropSystemConfig.getObjectSettings(objectType)
    
    -- Update AlignPosition settings
    constraints.alignPosition.MaxForce = settings.maxForce or constraints.alignPosition.MaxForce
    constraints.alignPosition.MaxVelocity = settings.maxVelocity or constraints.alignPosition.MaxVelocity
    constraints.alignPosition.Responsiveness = settings.responsiveness or constraints.alignPosition.Responsiveness
    
    if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
        print("DragPhysicsManager: Adjusted physics settings for", object.Name, "to", objectType)
    end
    
    return true
end

return DragPhysicsManager
