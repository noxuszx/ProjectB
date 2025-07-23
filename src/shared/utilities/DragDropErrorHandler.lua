--[[
    DragDropErrorHandler.lua
    Comprehensive error handling and edge case management for drag-drop system
    Handles player death, object destruction, network issues, and other edge cases
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Import shared utilities and config
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local DragDropSystemConfig = require(ReplicatedStorage.Shared.config.DragDropSystemConfig)

local DragDropErrorHandler = {}

-- Error tracking
local errorLog = {}
local errorCallbacks = {}
local isInitialized = false

-- Connection tracking for cleanup
local connections = {}

-- Initialize the error handler
function DragDropErrorHandler.init()
    if isInitialized then
        warn("DragDropErrorHandler: Already initialized")
        return false
    end
    
    print("DragDropErrorHandler: Initializing error handling system...")
    
    -- Set up error monitoring
    setupErrorMonitoring()
    
    -- Set up automatic cleanup systems
    setupAutomaticCleanup()
    
    isInitialized = true
    print("DragDropErrorHandler: Error handling system initialized")
    
    return true
end

-- Set up error monitoring and logging
function setupErrorMonitoring()
    -- Monitor for destroyed objects that were being dragged
    connections.objectDestroyed = workspace.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            handleObjectDestroyed(descendant)
        end
    end)
    
    -- Monitor for player character changes (death/respawn)
    connections.playerAdded = Players.PlayerAdded:Connect(function(player)
        setupPlayerMonitoring(player)
    end)
    
    -- Set up monitoring for existing players
    for _, player in pairs(Players:GetPlayers()) do
        setupPlayerMonitoring(player)
    end
    
    print("DragDropErrorHandler: Error monitoring active")
end

-- Set up monitoring for a specific player
function setupPlayerMonitoring(player)
    -- Monitor character spawning/despawning
    local function onCharacterAdded(character)
        handlePlayerRespawn(player, character)
    end
    
    local function onCharacterRemoving(character)
        handlePlayerDeath(player, character)
    end
    
    -- Connect to character events
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    player.CharacterAdded:Connect(onCharacterAdded)
    player.CharacterRemoving:Connect(onCharacterRemoving)
    
    -- Monitor player leaving
    connections["player_" .. player.UserId] = Players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == player then
            handlePlayerLeaving(player)
        end
    end)
end

-- Set up automatic cleanup systems
function setupAutomaticCleanup()
    -- Periodic cleanup of orphaned states
    spawn(function()
        while isInitialized do
            wait(DragDropSystemConfig.PERFORMANCE.GARBAGE_COLLECTION_INTERVAL)
            performPeriodicCleanup()
        end
    end)
    
    -- Network timeout cleanup
    spawn(function()
        while isInitialized do
            wait(5) -- Check every 5 seconds
            cleanupNetworkTimeouts()
        end
    end)
    
    print("DragDropErrorHandler: Automatic cleanup systems active")
end

-- Handle object destruction during drag
function handleObjectDestroyed(object)
    if CollectionServiceTags.isDragInProgress(object) then
        logError("OBJECT_DESTROYED", "Object destroyed while being dragged: " .. object.Name, {
            objectName = object.Name,
            objectType = object.ClassName,
            timestamp = tick()
        })
        
        -- Clean up drag state
        CollectionServiceTags.setDragInProgress(object, false)
        CollectionServiceTags.clearPlayerOwnership(object)
        
        -- Notify error callbacks
        triggerErrorCallback("objectDestroyed", {
            object = object,
            reason = "Object was destroyed during drag operation"
        })
        
        if DragDropSystemConfig.DEBUG.LOG_ERRORS then
            print("DragDropErrorHandler: Cleaned up destroyed object:", object.Name)
        end
    end
end

-- Handle player death/character removal
function handlePlayerDeath(player, character)
    if not player or not character then
        return
    end
    
    logError("PLAYER_DEATH", "Player character removed: " .. player.Name, {
        playerName = player.Name,
        userId = player.UserId,
        timestamp = tick()
    })
    
    -- Clean up any objects the player was dragging
    local cleanedCount = CollectionServiceTags.cleanupPlayerOwnership(player)
    
    if cleanedCount > 0 then
        -- Notify error callbacks
        triggerErrorCallback("playerDeath", {
            player = player,
            character = character,
            cleanedObjects = cleanedCount,
            reason = "Player character was removed (death/respawn)"
        })
        
        if DragDropSystemConfig.DEBUG.LOG_ERRORS then
            print("DragDropErrorHandler: Cleaned up", cleanedCount, "objects for dead player:", player.Name)
        end
    end
end

-- Handle player respawn
function handlePlayerRespawn(player, character)
    if not player or not character then
        return
    end
    
    -- Wait for character to fully load
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
    if not humanoidRootPart then
        logError("RESPAWN_FAILED", "Player respawn failed - no HumanoidRootPart: " .. player.Name, {
            playerName = player.Name,
            userId = player.UserId,
            timestamp = tick()
        })
        return
    end
    
    -- Notify callbacks about successful respawn
    triggerErrorCallback("playerRespawn", {
        player = player,
        character = character,
        reason = "Player successfully respawned"
    })
    
    if DragDropSystemConfig.DEBUG.LOG_ERRORS then
        print("DragDropErrorHandler: Player respawned successfully:", player.Name)
    end
end

-- Handle player leaving the game
function handlePlayerLeaving(player)
    if not player then
        return
    end
    
    logError("PLAYER_LEAVING", "Player left the game: " .. player.Name, {
        playerName = player.Name,
        userId = player.UserId,
        timestamp = tick()
    })
    
    -- Clean up all player data
    local cleanedCount = CollectionServiceTags.cleanupPlayerOwnership(player)
    
    -- Clean up connection
    local connectionKey = "player_" .. player.UserId
    if connections[connectionKey] then
        connections[connectionKey]:Disconnect()
        connections[connectionKey] = nil
    end
    
    -- Notify callbacks
    triggerErrorCallback("playerLeaving", {
        player = player,
        cleanedObjects = cleanedCount,
        reason = "Player left the game"
    })
    
    if DragDropSystemConfig.DEBUG.LOG_ERRORS then
        print("DragDropErrorHandler: Cleaned up data for leaving player:", player.Name)
    end
end

-- Perform periodic cleanup of orphaned states
function performPeriodicCleanup()
    local cleanupCount = 0
    
    -- Clean up orphaned drag states
    local draggedObjects = CollectionServiceTags.getAllDraggedObjects()
    for _, object in pairs(draggedObjects) do
        if not object or not object.Parent then
            CollectionServiceTags.setDragInProgress(object, false)
            cleanupCount = cleanupCount + 1
        else
            -- Check if the object's owner still exists
            local hasValidOwner = false
            for _, player in pairs(Players:GetPlayers()) do
                if CollectionServiceTags.isPlayerOwned(object, player) then
                    hasValidOwner = true
                    break
                end
            end
            
            if not hasValidOwner and CollectionServiceTags.hasTag(object, CollectionServiceTags.PLAYER_OWNED) then
                CollectionServiceTags.clearPlayerOwnership(object)
                CollectionServiceTags.setDragInProgress(object, false)
                cleanupCount = cleanupCount + 1
            end
        end
    end
    
    if cleanupCount > 0 then
        logError("PERIODIC_CLEANUP", "Cleaned up orphaned states", {
            cleanedCount = cleanupCount,
            timestamp = tick()
        })
        
        if DragDropSystemConfig.DEBUG.LOG_ERRORS then
            print("DragDropErrorHandler: Periodic cleanup removed", cleanupCount, "orphaned states")
        end
    end
end

-- Clean up network timeouts and stale requests
function cleanupNetworkTimeouts()
    -- This would integrate with the network manager to clean up timed-out requests
    -- For now, just trigger the callback to let other systems handle it
    triggerErrorCallback("networkTimeout", {
        reason = "Periodic network timeout cleanup",
        timestamp = tick()
    })
end

-- Log an error with details
function logError(errorType, message, details)
    local errorEntry = {
        type = errorType,
        message = message,
        details = details or {},
        timestamp = tick(),
        id = #errorLog + 1
    }
    
    table.insert(errorLog, errorEntry)
    
    -- Keep error log size manageable
    if #errorLog > 100 then
        table.remove(errorLog, 1)
    end
    
    -- Print error if logging is enabled
    if DragDropSystemConfig.ERROR_HANDLING.LOG_ERRORS then
        print("DragDropErrorHandler [" .. errorType .. "]: " .. message)
    end
end

-- Trigger error callbacks
function triggerErrorCallback(eventType, data)
    if errorCallbacks[eventType] then
        for _, callback in pairs(errorCallbacks[eventType]) do
            local success, err = pcall(callback, data)
            if not success then
                warn("DragDropErrorHandler: Error in callback for", eventType, ":", err)
            end
        end
    end
end

-- Register error callback
function DragDropErrorHandler.onError(eventType, callback)
    if not errorCallbacks[eventType] then
        errorCallbacks[eventType] = {}
    end
    
    table.insert(errorCallbacks[eventType], callback)
    
    return function()
        -- Return unregister function
        for i, cb in pairs(errorCallbacks[eventType]) do
            if cb == callback then
                table.remove(errorCallbacks[eventType], i)
                break
            end
        end
    end
end

-- Get error statistics
function DragDropErrorHandler.getErrorStats()
    local stats = {
        totalErrors = #errorLog,
        errorsByType = {},
        recentErrors = {}
    }
    
    -- Count errors by type
    for _, error in pairs(errorLog) do
        stats.errorsByType[error.type] = (stats.errorsByType[error.type] or 0) + 1
    end
    
    -- Get recent errors (last 10)
    local recentCount = math.min(10, #errorLog)
    for i = #errorLog - recentCount + 1, #errorLog do
        if errorLog[i] then
            table.insert(stats.recentErrors, errorLog[i])
        end
    end
    
    return stats
end

-- Get full error log
function DragDropErrorHandler.getErrorLog()
    return errorLog
end

-- Clear error log
function DragDropErrorHandler.clearErrorLog()
    errorLog = {}
    print("DragDropErrorHandler: Error log cleared")
end

-- Emergency recovery function
function DragDropErrorHandler.emergencyRecovery()
    print("DragDropErrorHandler: Executing emergency recovery...")
    
    -- Clean up all drag states
    local cleanedDrags = CollectionServiceTags.cleanupAllDragStates()
    
    -- Clean up all player ownership
    local cleanedOwnership = 0
    for _, player in pairs(Players:GetPlayers()) do
        cleanedOwnership = cleanedOwnership + CollectionServiceTags.cleanupPlayerOwnership(player)
    end
    
    -- Log recovery
    logError("EMERGENCY_RECOVERY", "Emergency recovery executed", {
        cleanedDrags = cleanedDrags,
        cleanedOwnership = cleanedOwnership,
        timestamp = tick()
    })
    
    -- Notify callbacks
    triggerErrorCallback("emergencyRecovery", {
        cleanedDrags = cleanedDrags,
        cleanedOwnership = cleanedOwnership,
        reason = "Emergency recovery executed"
    })
    
    print("DragDropErrorHandler: Emergency recovery complete - cleaned", cleanedDrags, "drags and", cleanedOwnership, "ownership records")
    
    return {
        cleanedDrags = cleanedDrags,
        cleanedOwnership = cleanedOwnership
    }
end

-- Shutdown the error handler
function DragDropErrorHandler.shutdown()
    if not isInitialized then
        return
    end
    
    -- Disconnect all connections
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
    
    -- Clear callbacks
    errorCallbacks = {}
    
    isInitialized = false
    print("DragDropErrorHandler: Shutdown complete")
end

-- Get handler status
function DragDropErrorHandler.getStatus()
    return {
        initialized = isInitialized,
        totalErrors = #errorLog,
        activeConnections = #connections,
        registeredCallbacks = #errorCallbacks
    }
end

return DragDropErrorHandler
