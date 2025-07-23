--[[
    DragValidationService.lua
    Server-side validation service for drag-drop operations
    Prevents exploits while maintaining responsive client experience
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Import shared utilities and config
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local DragDropSystemConfig = require(ReplicatedStorage.Shared.config.DragDropSystemConfig)

local DragValidationService = {}

-- Validation state tracking
local playerDragStates = {}  -- [player.UserId] = {draggedObjects = {}, lastRequestTime = 0, requestCount = 0}
local validationQueue = {}   -- Queue for processing validation requests
local isServiceRunning = false

-- Rate limiting data
local rateLimitData = {}     -- [player.UserId] = {requests = {}, lastCleanup = 0}

-- Initialize the validation service
function DragValidationService.init()
    if isServiceRunning then
        warn("DragValidationService: Service already running")
        return false
    end
    
    print("DragValidationService: Initializing server-side validation...")
    
    -- Set up remote event handlers
    setupRemoteEventHandlers()
    
    -- Start validation processing loop
    startValidationLoop()
    
    -- Set up player cleanup
    setupPlayerCleanup()
    
    isServiceRunning = true
    print("DragValidationService: Service initialized successfully")
    
    return true
end

-- Set up remote event handlers for client communication
function setupRemoteEventHandlers()
    local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
    
    -- Handle drag start requests
    local requestStartDrag = remoteEventsFolder:WaitForChild("RequestStartDrag")
    requestStartDrag.OnServerEvent:Connect(handleStartDragRequest)
    
    -- Handle drag stop requests
    local requestStopDrag = remoteEventsFolder:WaitForChild("RequestStopDrag")
    requestStopDrag.OnServerEvent:Connect(handleStopDragRequest)
    
    -- Handle position updates
    local dragPositionUpdate = remoteEventsFolder:WaitForChild("DragPositionUpdate")
    dragPositionUpdate.OnServerEvent:Connect(handlePositionUpdate)
    
    print("DragValidationService: Remote event handlers configured")
end

-- Handle drag start request from client
function handleStartDragRequest(player, object, startPosition)
    if not isValidPlayer(player) then
        return
    end
    
    -- Rate limiting check
    if not checkRateLimit(player, "startDrag") then
        sendValidationResult(player, "startDrag", false, "Rate limit exceeded")
        return
    end
    
    -- Validate the drag request
    local isValid, reason = validateDragStart(player, object, startPosition)
    
    if isValid then
        -- Update server state
        addPlayerDragState(player, object)
        
        -- Mark object as being dragged
        CollectionServiceTags.setDragInProgress(object, true)
        CollectionServiceTags.setPlayerOwnership(object, player)
        
        -- Send confirmation to client
        sendValidationResult(player, "startDrag", true, "Drag approved")
        
        -- Notify other clients about the drag state
        broadcastDragState(player, object, "started")
        
        if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
            print("DragValidationService: Approved drag start for", player.Name, "on", object.Name)
        end
    else
        sendValidationResult(player, "startDrag", false, reason)
        
        if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
            print("DragValidationService: Denied drag start for", player.Name, ":", reason)
        end
    end
end

-- Handle drag stop request from client
function handleStopDragRequest(player, object, finalPosition)
    if not isValidPlayer(player) then
        return
    end
    
    -- Rate limiting check
    if not checkRateLimit(player, "stopDrag") then
        sendValidationResult(player, "stopDrag", false, "Rate limit exceeded")
        return
    end
    
    -- Validate the drag stop
    local isValid, reason = validateDragStop(player, object, finalPosition)
    
    if isValid then
        -- Update server state
        removePlayerDragState(player, object)
        
        -- Clear drag state
        CollectionServiceTags.setDragInProgress(object, false)
        
        -- Validate and set final position
        local validatedPosition = validateFinalPosition(object, finalPosition)
        if validatedPosition then
            object.Position = validatedPosition
        end
        
        -- Send confirmation to client
        sendValidationResult(player, "stopDrag", true, "Drop approved", validatedPosition)
        
        -- Notify other clients
        broadcastDragState(player, object, "stopped", validatedPosition)
        
        if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
            print("DragValidationService: Approved drag stop for", player.Name, "on", object.Name)
        end
    else
        sendValidationResult(player, "stopDrag", false, reason)
        
        if DragDropSystemConfig.DEBUG.LOG_NETWORK_TRAFFIC then
            print("DragValidationService: Denied drag stop for", player.Name, ":", reason)
        end
    end
end

-- Handle position updates during drag
function handlePositionUpdate(player, object, position)
    if not isValidPlayer(player) then
        return
    end
    
    -- Rate limiting check (more lenient for position updates)
    if not checkRateLimit(player, "positionUpdate") then
        return  -- Silently ignore excessive position updates
    end
    
    -- Validate position update
    if validatePositionUpdate(player, object, position) then
        -- Update authoritative position (with some tolerance for client prediction)
        local validatedPosition = validatePosition(object, position)
        if validatedPosition then
            -- Broadcast to other clients (not back to sender)
            broadcastPositionUpdate(player, object, validatedPosition)
        end
    end
end

-- Validate drag start request
function validateDragStart(player, object, startPosition)
    -- Check if object exists and is valid
    if not object or not object.Parent then
        return false, "Object does not exist"
    end
    
    -- Check if object is draggable
    if not CollectionServiceTags.isDraggable(object) then
        return false, "Object is not draggable"
    end
    
    -- Check if object is already being dragged
    if CollectionServiceTags.isDragInProgress(object) then
        return false, "Object is already being dragged"
    end
    
    -- Check player drag limits
    local playerState = getPlayerDragState(player)
    if #playerState.draggedObjects >= DragDropSystemConfig.SECURITY.MAX_CONCURRENT_DRAGS_PER_PLAYER then
        return false, "Maximum concurrent drags exceeded"
    end
    
    -- Check distance from player
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local distance = (character.HumanoidRootPart.Position - object.Position).Magnitude
        if distance > DragDropSystemConfig.DISTANCE_LIMITS.MAX_DRAG_INITIATION_DISTANCE then
            return false, "Object too far away"
        end
    end
    
    -- Check mass limits
    if DragDropSystemConfig.SECURITY.ENABLE_MASS_LIMITS then
        local mass = object.Mass
        if mass < DragDropSystemConfig.SECURITY.MIN_DRAG_MASS or mass > DragDropSystemConfig.SECURITY.MAX_DRAG_MASS then
            return false, "Object mass outside allowed range"
        end
    end
    
    -- Check ownership if enabled
    if DragDropSystemConfig.SECURITY.ENABLE_OWNERSHIP_SYSTEM then
        if CollectionServiceTags.hasTag(object, CollectionServiceTags.PLAYER_OWNED) then
            if not CollectionServiceTags.isPlayerOwned(object, player) then
                return false, "Object owned by another player"
            end
        end
    end
    
    return true, "Valid drag start"
end

-- Validate drag stop request
function validateDragStop(player, object, finalPosition)
    -- Check if player is actually dragging this object
    local playerState = getPlayerDragState(player)
    local isDragging = false
    
    for _, draggedObject in pairs(playerState.draggedObjects) do
        if draggedObject == object then
            isDragging = true
            break
        end
    end
    
    if not isDragging then
        return false, "Player is not dragging this object"
    end
    
    -- Check if drop location is valid
    if finalPosition then
        local dropZoneValid = validateDropZone(object, finalPosition)
        if not dropZoneValid then
            return false, "Invalid drop location"
        end
    end
    
    return true, "Valid drag stop"
end

-- Validate position during drag
function validatePositionUpdate(player, object, position)
    -- Check if player is dragging this object
    local playerState = getPlayerDragState(player)
    for _, draggedObject in pairs(playerState.draggedObjects) do
        if draggedObject == object then
            -- Check distance limits
            local character = player.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local distance = (character.HumanoidRootPart.Position - position).Magnitude
                if distance > DragDropSystemConfig.DISTANCE_LIMITS.MAX_DRAG_MAINTAIN_DISTANCE then
                    return false
                end
            end
            return true
        end
    end
    
    return false
end

-- Validate final position and return corrected position if needed
function validateFinalPosition(object, requestedPosition)
    if not requestedPosition then
        return object.Position  -- Keep current position
    end
    
    -- Check height limits
    if requestedPosition.Y < DragDropSystemConfig.DISTANCE_LIMITS.MIN_DROP_HEIGHT then
        requestedPosition = Vector3.new(requestedPosition.X, DragDropSystemConfig.DISTANCE_LIMITS.MIN_DROP_HEIGHT, requestedPosition.Z)
    elseif requestedPosition.Y > DragDropSystemConfig.DISTANCE_LIMITS.MAX_DROP_HEIGHT then
        requestedPosition = Vector3.new(requestedPosition.X, DragDropSystemConfig.DISTANCE_LIMITS.MAX_DROP_HEIGHT, requestedPosition.Z)
    end
    
    -- Additional validation can be added here (terrain collision, etc.)
    
    return requestedPosition
end

-- Validate position with tolerance for client prediction
function validatePosition(object, clientPosition)
    local currentPosition = object.Position
    local distance = (currentPosition - clientPosition).Magnitude
    
    -- Allow some tolerance for client prediction
    if distance <= DragDropSystemConfig.POSITION_VALIDATION_TOLERANCE then
        return clientPosition
    else
        -- Return server-authoritative position
        return currentPosition
    end
end

-- Validate drop zone
function validateDropZone(object, position)
    -- Cast ray downward to find surface
    local raycast = Workspace:Raycast(position, Vector3.new(0, -100, 0))
    
    if raycast and raycast.Instance then
        return CollectionServiceTags.isValidDropZone(raycast.Instance)
    end
    
    return true  -- Allow drop if no surface found (will fall naturally)
end

-- Rate limiting system
function checkRateLimit(player, actionType)
    if not DragDropSystemConfig.SECURITY.ENABLE_RATE_LIMITING then
        return true
    end
    
    local userId = player.UserId
    local currentTime = tick()
    
    -- Initialize rate limit data for player
    if not rateLimitData[userId] then
        rateLimitData[userId] = {requests = {}, lastCleanup = currentTime}
    end
    
    local playerData = rateLimitData[userId]
    
    -- Clean up old requests (older than 1 second)
    if currentTime - playerData.lastCleanup > 1 then
        local newRequests = {}
        for _, requestTime in pairs(playerData.requests) do
            if currentTime - requestTime <= 1 then
                table.insert(newRequests, requestTime)
            end
        end
        playerData.requests = newRequests
        playerData.lastCleanup = currentTime
    end
    
    -- Check rate limit with different limits for different actions
    local maxRequests = DragDropSystemConfig.MAX_DRAG_REQUESTS_PER_SECOND
    if actionType == "positionUpdate" then
        maxRequests = maxRequests * 5  -- Allow many more position updates (150/sec)
    elseif actionType == "startDrag" or actionType == "stopDrag" then
        maxRequests = math.min(maxRequests, 20)  -- Reasonable limit for drag start/stop (20/sec)
    end
    
    if #playerData.requests >= maxRequests then
        return false
    end
    
    -- Add current request
    table.insert(playerData.requests, currentTime)
    return true
end

-- Player state management
function getPlayerDragState(player)
    local userId = player.UserId
    if not playerDragStates[userId] then
        playerDragStates[userId] = {
            draggedObjects = {},
            lastRequestTime = 0,
            requestCount = 0
        }
    end
    return playerDragStates[userId]
end

function addPlayerDragState(player, object)
    local playerState = getPlayerDragState(player)
    table.insert(playerState.draggedObjects, object)
end

function removePlayerDragState(player, object)
    local playerState = getPlayerDragState(player)
    for i, draggedObject in pairs(playerState.draggedObjects) do
        if draggedObject == object then
            table.remove(playerState.draggedObjects, i)
            break
        end
    end
end

-- Communication functions
function sendValidationResult(player, action, success, reason, data)
    local validationResult = ReplicatedStorage.RemoteEvents:FindFirstChild("DragValidationResult")
    if validationResult then
        validationResult:FireClient(player, action, success, reason, data)
    end
end

function broadcastDragState(excludePlayer, object, state, position)
    local dragStateSync = ReplicatedStorage.RemoteEvents:FindFirstChild("DragStateSync")
    if dragStateSync then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= excludePlayer then
                dragStateSync:FireClient(player, object, state, position)
            end
        end
    end
end

function broadcastPositionUpdate(excludePlayer, object, position)
    local dragPositionUpdate = ReplicatedStorage.RemoteEvents:FindFirstChild("DragPositionUpdate")
    if dragPositionUpdate then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= excludePlayer then
                dragPositionUpdate:FireClient(player, object, position)
            end
        end
    end
end

-- Utility functions
function isValidPlayer(player)
    return player and player.Parent and Players:FindFirstChild(player.Name)
end

-- Start validation processing loop
function startValidationLoop()
    spawn(function()
        while isServiceRunning do
            -- Process validation queue if needed
            -- This can be expanded for more complex validation scenarios
            
            wait(1 / DragDropSystemConfig.UPDATE_RATES.SERVER_VALIDATION)
        end
    end)
end

-- Set up player cleanup
function setupPlayerCleanup()
    Players.PlayerRemoving:Connect(function(player)
        local userId = player.UserId
        
        -- Clean up player drag states
        if playerDragStates[userId] then
            for _, object in pairs(playerDragStates[userId].draggedObjects) do
                CollectionServiceTags.setDragInProgress(object, false)
                CollectionServiceTags.clearPlayerOwnership(object)
            end
            playerDragStates[userId] = nil
        end
        
        -- Clean up rate limit data
        if rateLimitData[userId] then
            rateLimitData[userId] = nil
        end
        
        print("DragValidationService: Cleaned up data for", player.Name)
    end)
end

-- Get service status
function DragValidationService.getStatus()
    local totalDraggedObjects = 0
    local playerCount = 0
    
    for _, playerState in pairs(playerDragStates) do
        totalDraggedObjects = totalDraggedObjects + #playerState.draggedObjects
        playerCount = playerCount + 1
    end
    
    return {
        isRunning = isServiceRunning,
        activePlayers = playerCount,
        totalDraggedObjects = totalDraggedObjects,
        queueSize = #validationQueue
    }
end

-- Shutdown service
function DragValidationService.shutdown()
    isServiceRunning = false
    
    -- Clean up all drag states
    for userId, playerState in pairs(playerDragStates) do
        for _, object in pairs(playerState.draggedObjects) do
            CollectionServiceTags.setDragInProgress(object, false)
            CollectionServiceTags.clearPlayerOwnership(object)
        end
    end
    
    playerDragStates = {}
    rateLimitData = {}
    validationQueue = {}
    
    print("DragValidationService: Service shutdown complete")
end

return DragValidationService
