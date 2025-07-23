--[[
    DragDropSystemInit.lua
    Initialization system for the enhanced drag-drop system
    Integrates with the existing ChunkInit.server.lua pattern
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Import shared utilities and config
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local DragDropSystemConfig = require(ReplicatedStorage.Shared.config.DragDropSystemConfig)
local DragDropErrorHandler = require(ReplicatedStorage.Shared.utilities.DragDropErrorHandler)
local DragDropPerformanceManager = require(ReplicatedStorage.Shared.utilities.DragDropPerformanceManager)

local DragDropSystemInit = {}

-- Track initialization state
local isInitialized = false
local initializationStartTime = 0

-- Player cleanup connections
local playerConnections = {}

-- Initialize the drag-drop system
function DragDropSystemInit.init()
    if isInitialized then
        warn("DragDropSystemInit: System already initialized")
        return false
    end
    
    initializationStartTime = tick()
    print("DragDropSystemInit: Starting enhanced drag-drop system initialization...")
    
    -- Validate configuration
    local configIssues = DragDropSystemConfig.validateConfig()
    if #configIssues > 0 then
        warn("DragDropSystemInit: Configuration issues detected:")
        for _, issue in pairs(configIssues) do
            warn("  - " .. issue)
        end
    end
    
    -- Initialize CollectionService tags
    CollectionServiceTags.initializeDefaultTags()
    
    -- Tag items from the Items folder
    CollectionServiceTags.tagItemsFolder()
    
    -- Set up player management
    setupPlayerManagement()
    
    -- Set up cleanup systems
    setupCleanupSystems()
    
    -- Create remote events for client-server communication
    createRemoteEvents()
    
    -- Initialize server-side validation service
    initializeValidationService()

    -- Initialize error handling system
    initializeErrorHandler()

    -- Initialize performance optimization system
    initializePerformanceManager()

    isInitialized = true
    local initTime = math.floor((tick() - initializationStartTime) * 1000) / 1000
    print("DragDropSystemInit: System initialized successfully in " .. initTime .. " seconds")

    return true
end

-- Set up player management (join/leave handling)
function setupPlayerManagement()
    -- Handle existing players
    for _, player in pairs(Players:GetPlayers()) do
        setupPlayerData(player)
    end
    
    -- Handle new players
    playerConnections.playerAdded = Players.PlayerAdded:Connect(setupPlayerData)
    
    -- Handle leaving players
    playerConnections.playerRemoving = Players.PlayerRemoving:Connect(cleanupPlayerData)
    
    print("DragDropSystemInit: Player management system active")
end

-- Set up data for a new player
function setupPlayerData(player)
    print("DragDropSystemInit: Setting up drag-drop data for player:", player.Name)
    
    -- Initialize player-specific data if needed
    -- This could include drag limits, permissions, etc.
    
    -- Clean up any existing drag states for this player (in case of rejoin)
    CollectionServiceTags.cleanupPlayerOwnership(player)
end

-- Clean up data for a leaving player
function cleanupPlayerData(player)
    print("DragDropSystemInit: Cleaning up drag-drop data for player:", player.Name)
    
    -- Clean up ownership and drag states
    CollectionServiceTags.cleanupPlayerOwnership(player)
    
    -- Additional cleanup can be added here
end

-- Set up periodic cleanup systems
function setupCleanupSystems()
    -- Periodic cleanup of orphaned drag states
    local cleanupInterval = DragDropSystemConfig.PERFORMANCE.GARBAGE_COLLECTION_INTERVAL
    
    spawn(function()
        while true do
            wait(cleanupInterval)
            
            if DragDropSystemConfig.DEBUG.LOG_PERFORMANCE_METRICS then
                print("DragDropSystemInit: Running periodic cleanup...")
            end
            
            -- Clean up any orphaned drag states
            local cleanedCount = CollectionServiceTags.cleanupAllDragStates()
            
            if cleanedCount > 0 then
                print("DragDropSystemInit: Cleaned up " .. cleanedCount .. " orphaned drag states")
            end
        end
    end)
    
    print("DragDropSystemInit: Cleanup systems active")
end

-- Create remote events for client-server communication
function createRemoteEvents()
    local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEventsFolder then
        remoteEventsFolder = Instance.new("Folder")
        remoteEventsFolder.Name = "RemoteEvents"
        remoteEventsFolder.Parent = ReplicatedStorage
    end
    
    -- Create drag-drop specific remote events
    local remoteEvents = DragDropSystemConfig.REMOTE_EVENTS
    
    for eventName, eventId in pairs(remoteEvents) do
        local existingEvent = remoteEventsFolder:FindFirstChild(eventId)
        if not existingEvent then
            local remoteEvent = Instance.new("RemoteEvent")
            remoteEvent.Name = eventId
            remoteEvent.Parent = remoteEventsFolder
            print("DragDropSystemInit: Created RemoteEvent:", eventId)
        end
    end
    
    print("DragDropSystemInit: Remote events initialized")
end

-- Initialize server-side validation service
function initializeValidationService()
    if not DragDropSystemConfig.isFeatureEnabled("serverValidation") then
        print("DragDropSystemInit: Server validation disabled in config")
        return
    end

    -- Import and initialize the validation service
    local DragValidationService = require(script.Parent.DragValidationService)
    local success = DragValidationService.init()

    if success then
        print("DragDropSystemInit: Server validation service initialized successfully")
    else
        warn("DragDropSystemInit: Failed to initialize server validation service")
    end
end

-- Initialize error handling system
function initializeErrorHandler()
    local success = DragDropErrorHandler.init()

    if success then
        print("DragDropSystemInit: Error handling system initialized successfully")

        -- Set up error callbacks for system integration
        DragDropErrorHandler.onError("playerDeath", function(data)
            print("DragDropSystemInit: Handled player death cleanup for", data.player.Name)
        end)

        DragDropErrorHandler.onError("objectDestroyed", function(data)
            print("DragDropSystemInit: Handled object destruction cleanup for", data.object.Name)
        end)

        DragDropErrorHandler.onError("emergencyRecovery", function(data)
            warn("DragDropSystemInit: Emergency recovery executed - cleaned", data.cleanedDrags, "drags")
        end)
    else
        warn("DragDropSystemInit: Failed to initialize error handling system")
    end
end

-- Initialize performance optimization system
function initializePerformanceManager()
    local success = DragDropPerformanceManager.init()

    if success then
        print("DragDropSystemInit: Performance optimization system initialized successfully")

        -- Set up performance monitoring callbacks
        if DragDropSystemConfig.DEBUG.ENABLE_PROFILING then
            DragDropPerformanceManager.scheduleCallback("STATE_CLEANUP", function()
                local stats = DragDropPerformanceManager.optimizePerformance()
                if DragDropSystemConfig.DEBUG.LOG_PERFORMANCE_METRICS then
                    print("DragDropSystemInit: Performance optimization completed")
                end
            end)
        end
    else
        warn("DragDropSystemInit: Failed to initialize performance optimization system")
    end
end

-- Get system status information
function DragDropSystemInit.getStatus()
    return {
        initialized = isInitialized,
        initTime = initializationStartTime,
        playerCount = #Players:GetPlayers(),
        draggedObjectsCount = #CollectionServiceTags.getAllDraggedObjects(),
        configValid = #DragDropSystemConfig.validateConfig() == 0
    }
end

-- Shutdown the system (useful for testing/debugging)
function DragDropSystemInit.shutdown()
    if not isInitialized then
        warn("DragDropSystemInit: System not initialized")
        return false
    end
    
    print("DragDropSystemInit: Shutting down drag-drop system...")
    
    -- Disconnect player connections
    for _, connection in pairs(playerConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    playerConnections = {}
    
    -- Clean up all drag states
    CollectionServiceTags.cleanupAllDragStates()
    
    -- Clean up all player ownership
    for _, player in pairs(Players:GetPlayers()) do
        CollectionServiceTags.cleanupPlayerOwnership(player)
    end
    
    isInitialized = false
    print("DragDropSystemInit: System shutdown complete")
    
    return true
end

-- Debug function to print system information
function DragDropSystemInit.printDebugInfo()
    local status = DragDropSystemInit.getStatus()
    
    print("=== DragDropSystemInit Debug Info ===")
    print("Initialized:", status.initialized)
    print("Init Time:", status.initTime)
    print("Player Count:", status.playerCount)
    print("Dragged Objects:", status.draggedObjectsCount)
    print("Config Valid:", status.configValid)
    print("System Version:", DragDropSystemConfig.SYSTEM_VERSION)
    print("Server Validation:", DragDropSystemConfig.isFeatureEnabled("serverValidation"))
    print("Client Prediction:", DragDropSystemConfig.isFeatureEnabled("clientPrediction"))
    print("=====================================")
end

-- Integration function for ChunkInit.server.lua
function DragDropSystemInit.integrateWithChunkInit()
    print("DragDropSystemInit: Integrating with existing chunk initialization...")
    
    -- Wait for terrain system to be ready
    local maxWaitTime = 10
    local waitTime = 0
    local waitInterval = 0.5
    
    while not workspace:FindFirstChild("Chunks") and waitTime < maxWaitTime do
        wait(waitInterval)
        waitTime = waitTime + waitInterval
    end
    
    if workspace:FindFirstChild("Chunks") then
        print("DragDropSystemInit: Terrain system detected, proceeding with integration")
        return DragDropSystemInit.init()
    else
        warn("DragDropSystemInit: Terrain system not found, initializing anyway")
        return DragDropSystemInit.init()
    end
end

return DragDropSystemInit
