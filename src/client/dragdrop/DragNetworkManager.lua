--[[
    DragNetworkManager.lua
    Client-side network manager for drag-drop system
    Handles communication with server validation service
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Import shared utilities and config
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local DragDropSystemConfig = require(ReplicatedStorage.Shared.config.DragDropSystemConfig)

local DragNetworkManager = {}

-- Network state
local remoteEvents = {}
local pendingRequests = {}  -- Track pending server requests
local networkQueue = {}     -- Queue for batching network updates
local lastNetworkUpdate = 0
local isInitialized = false

-- Player reference
local player = Players.LocalPlayer

-- Initialize the network manager
function DragNetworkManager.init()
    if isInitialized then
        warn("DragNetworkManager: Already initialized")
        return false
    end
    
    print("DragNetworkManager: Initializing client-side network manager...")
    
    -- Wait for remote events to be created by server
    setupRemoteEvents()
    
    -- Set up network update loop
    setupNetworkLoop()
    
    isInitialized = true
    print("DragNetworkManager: Network manager initialized successfully")
    
    return true
end

-- Set up remote event connections
function setupRemoteEvents()
    local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    if not remoteEventsFolder then
        warn("DragNetworkManager: RemoteEvents folder not found")
        return
    end
    
    -- Get all drag-drop remote events
    local eventNames = DragDropSystemConfig.REMOTE_EVENTS
    
    for eventKey, eventName in pairs(eventNames) do
        local remoteEvent = remoteEventsFolder:WaitForChild(eventName, 5)
        if remoteEvent then
            remoteEvents[eventKey] = remoteEvent
            
            -- Set up event handlers for server responses
            if eventKey == "DRAG_VALIDATION_RESULT" then
                remoteEvent.OnClientEvent:Connect(handleValidationResult)
            elseif eventKey == "DRAG_STATE_SYNC" then
                remoteEvent.OnClientEvent:Connect(handleDragStateSync)
            elseif eventKey == "DRAG_POSITION_UPDATE" then
                remoteEvent.OnClientEvent:Connect(handlePositionUpdate)
            end
        else
            warn("DragNetworkManager: Failed to find RemoteEvent:", eventName)
        end
    end
    
    print("DragNetworkManager: Remote events configured")
end

-- Set up network update loop for batching
function setupNetworkLoop()
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        -- Process network queue at configured rate
        if currentTime - lastNetworkUpdate >= DragDropSystemConfig.UPDATE_RATES.NETWORK_POSITION then
            processNetworkQueue()
            lastNetworkUpdate = currentTime
        end
    end)
end

-- Request drag start from server
function DragNetworkManager.requestStartDrag(object, startPosition)
    if not isInitialized or not remoteEvents.REQUEST_START_DRAG then
        warn("DragNetworkManager: Not initialized or missing remote event")
        return false
    end
    
    -- Check if we already have a pending request for this object
    local requestId = generateRequestId(object, "startDrag")
    if pendingRequests[requestId] then
        if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
            print("DragNetworkManager: Drag start request already pending for", object.Name)
        end
        return false
    end
    
    -- Send request to server
    remoteEvents.REQUEST_START_DRAG:FireServer(object, startPosition)
    
    -- Track pending request
    pendingRequests[requestId] = {
        object = object,
        action = "startDrag",
        timestamp = tick(),
        timeout = DragDropSystemConfig.VALIDATION_TIMEOUT
    }
    
    if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
        print("DragNetworkManager: Sent drag start request for", object.Name)
    end
    
    return true
end

-- Request drag stop from server
function DragNetworkManager.requestStopDrag(object, finalPosition)
    if not isInitialized or not remoteEvents.REQUEST_STOP_DRAG then
        warn("DragNetworkManager: Not initialized or missing remote event")
        return false
    end
    
    -- Check if we have a pending request
    local requestId = generateRequestId(object, "stopDrag")
    if pendingRequests[requestId] then
        if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
            print("DragNetworkManager: Drag stop request already pending for", object.Name)
        end
        return false
    end
    
    -- Send request to server
    remoteEvents.REQUEST_STOP_DRAG:FireServer(object, finalPosition)
    
    -- Track pending request
    pendingRequests[requestId] = {
        object = object,
        action = "stopDrag",
        timestamp = tick(),
        timeout = DragDropSystemConfig.VALIDATION_TIMEOUT
    }
    
    if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
        print("DragNetworkManager: Sent drag stop request for", object.Name)
    end
    
    return true
end

-- Queue position update for batching
function DragNetworkManager.queuePositionUpdate(object, position)
    if not isInitialized then
        return false
    end
    
    -- Add to queue (overwrite existing entry for same object to avoid spam)
    networkQueue[object] = {
        position = position,
        timestamp = tick()
    }
    
    return true
end

-- Process the network queue and send batched updates
function processNetworkQueue()
    if not remoteEvents.DRAG_POSITION_UPDATE then
        return
    end
    
    local currentTime = tick()
    
    for object, updateData in pairs(networkQueue) do
        -- Check if update is still relevant (not too old)
        if currentTime - updateData.timestamp <= 0.5 then
            remoteEvents.DRAG_POSITION_UPDATE:FireServer(object, updateData.position)
            
            if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
                print("DragNetworkManager: Sent position update for", object.Name)
            end
        end
        
        -- Remove from queue
        networkQueue[object] = nil
    end
end

-- Handle validation result from server
function handleValidationResult(action, success, reason, data)
    if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
        print("DragNetworkManager: Received validation result:", action, success, reason)
    end
    
    -- Find and remove pending request
    local requestId = nil
    for id, request in pairs(pendingRequests) do
        if request.action == action then
            requestId = id
            break
        end
    end
    
    if requestId then
        local request = pendingRequests[requestId]
        pendingRequests[requestId] = nil
        
        -- Notify the drag controller about the result
        if DragNetworkManager.onValidationResult then
            DragNetworkManager.onValidationResult(request.object, action, success, reason, data)
        end
    end
end

-- Handle drag state synchronization from server
function handleDragStateSync(object, state, position)
    if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
        print("DragNetworkManager: Received drag state sync:", object.Name, state)
    end
    
    -- Update local state based on server authority
    if state == "started" then
        CollectionServiceTags.setDragInProgress(object, true)
    elseif state == "stopped" then
        CollectionServiceTags.setDragInProgress(object, false)
        if position then
            object.Position = position
        end
    end
    
    -- Notify drag controller about state change
    if DragNetworkManager.onDragStateSync then
        DragNetworkManager.onDragStateSync(object, state, position)
    end
end

-- Handle position updates from server (for other players' drags)
function handlePositionUpdate(object, position)
    if not object or not position then
        return
    end
    
    -- Only update if we're not dragging this object ourselves
    if not CollectionServiceTags.isDragInProgress(object) or 
       not CollectionServiceTags.isPlayerOwned(object, player) then
        
        -- Smooth interpolation could be added here for better visual experience
        object.Position = position
        
        if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
            print("DragNetworkManager: Updated position for", object.Name, "from server")
        end
    end
end

-- Check for timed out requests
function DragNetworkManager.checkTimeouts()
    local currentTime = tick()
    local timedOutRequests = {}
    
    for requestId, request in pairs(pendingRequests) do
        if currentTime - request.timestamp > request.timeout then
            table.insert(timedOutRequests, requestId)
        end
    end
    
    -- Handle timed out requests
    for _, requestId in pairs(timedOutRequests) do
        local request = pendingRequests[requestId]
        pendingRequests[requestId] = nil
        
        warn("DragNetworkManager: Request timed out:", request.action, "for", request.object.Name)
        
        -- Notify drag controller about timeout
        if DragNetworkManager.onValidationResult then
            DragNetworkManager.onValidationResult(request.object, request.action, false, "Request timed out")
        end
    end
    
    return #timedOutRequests
end

-- Get network status
function DragNetworkManager.getStatus()
    return {
        initialized = isInitialized,
        pendingRequests = #pendingRequests,
        queuedUpdates = #networkQueue,
        remoteEventsConnected = #remoteEvents
    }
end

-- Utility functions
function generateRequestId(object, action)
    return tostring(object) .. "_" .. action .. "_" .. tick()
end

-- Check if server validation is enabled
function DragNetworkManager.isServerValidationEnabled()
    return DragDropSystemConfig.isFeatureEnabled("serverValidation")
end

-- Check if client prediction is enabled
function DragNetworkManager.isClientPredictionEnabled()
    return DragDropSystemConfig.isFeatureEnabled("clientPrediction")
end

-- Cleanup function
function DragNetworkManager.cleanup()
    -- Clear pending requests
    pendingRequests = {}
    
    -- Clear network queue
    networkQueue = {}
    
    -- Reset callbacks
    DragNetworkManager.onValidationResult = nil
    DragNetworkManager.onDragStateSync = nil
    
    print("DragNetworkManager: Cleanup complete")
end

-- Callback functions (to be set by drag controller)
DragNetworkManager.onValidationResult = nil  -- function(object, action, success, reason, data)
DragNetworkManager.onDragStateSync = nil     -- function(object, state, position)

return DragNetworkManager
