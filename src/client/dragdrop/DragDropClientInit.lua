--[[
    DragDropClientInit.lua
    Enhanced client-side initialization for the professional drag-drop system
    Replaces the existing DragDropClient.lua with the new architecture
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Import system components
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local DragDropSystemConfig = require(ReplicatedStorage.Shared.config.DragDropSystemConfig)
local DragDropErrorHandler = require(ReplicatedStorage.Shared.utilities.DragDropErrorHandler)
local DragController = require(script.Parent.DragController)

local DragDropClientInit = {}

-- Initialization state
local isInitialized = false
local initializationStartTime = 0

-- Player reference
local player = Players.LocalPlayer

-- Initialize the enhanced drag-drop client system
function DragDropClientInit.init()
    if isInitialized then
        warn("DragDropClientInit: System already initialized")
        return false
    end
    
    initializationStartTime = tick()
    print("DragDropClientInit: Starting enhanced drag-drop client initialization...")
    
    -- Wait for character to spawn
    if not waitForCharacter() then
        warn("DragDropClientInit: Failed to wait for character")
        return false
    end
    
    -- Wait for server systems to be ready
    if not waitForServerSystems() then
        warn("DragDropClientInit: Server systems not ready")
        return false
    end
    
    -- Initialize error handling system
    local errorHandlerSuccess = DragDropErrorHandler.init()
    if not errorHandlerSuccess then
        warn("DragDropClientInit: Failed to initialize error handler")
    end

    -- Initialize the main drag controller
    local success = DragController.init()
    if not success then
        warn("DragDropClientInit: Failed to initialize drag controller")
        return false
    end

    -- Set up error handler callbacks
    if errorHandlerSuccess then
        setupErrorHandlerCallbacks()
    end

    -- Set up client-specific configurations
    setupClientConfiguration()
    
    -- Set up debug commands if enabled
    if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
        setupDebugCommands()
    end
    
    isInitialized = true
    local initTime = math.floor((tick() - initializationStartTime) * 1000) / 1000
    print("DragDropClientInit: Enhanced drag-drop client initialized successfully in " .. initTime .. " seconds")
    
    -- Print system status
    printSystemStatus()
    
    return true
end

-- Wait for player character to spawn
function waitForCharacter()
    local maxWaitTime = 10
    local waitTime = 0
    local waitInterval = 0.1
    
    while not player.Character and waitTime < maxWaitTime do
        wait(waitInterval)
        waitTime = waitTime + waitInterval
    end
    
    if player.Character then
        -- Wait for HumanoidRootPart
        local humanoidRootPart = player.Character:WaitForChild("HumanoidRootPart", 5)
        return humanoidRootPart ~= nil
    end
    
    return false
end

-- Wait for server systems to be ready
function waitForServerSystems()
    local maxWaitTime = 15
    local waitTime = 0
    local waitInterval = 0.5
    
    -- Wait for RemoteEvents folder if server validation is enabled
    if DragDropSystemConfig.isFeatureEnabled("serverValidation") then
        while not ReplicatedStorage:FindFirstChild("RemoteEvents") and waitTime < maxWaitTime do
            wait(waitInterval)
            waitTime = waitTime + waitInterval
        end
        
        if not ReplicatedStorage:FindFirstChild("RemoteEvents") then
            warn("DragDropClientInit: RemoteEvents folder not found - server validation may not work")
            return false
        end
        
        -- Wait for specific drag-drop remote events
        local remoteEventsFolder = ReplicatedStorage.RemoteEvents
        local requiredEvents = {
            "RequestStartDrag",
            "RequestStopDrag", 
            "DragValidationResult",
            "DragStateSync"
        }
        
        for _, eventName in pairs(requiredEvents) do
            local event = remoteEventsFolder:WaitForChild(eventName, 5)
            if not event then
                warn("DragDropClientInit: Required RemoteEvent not found:", eventName)
                return false
            end
        end
        
        print("DragDropClientInit: Server validation system detected and ready")
    end
    
    return true
end

-- Set up error handler callbacks
function setupErrorHandlerCallbacks()
    -- Handle player death/respawn
    DragDropErrorHandler.onError("playerDeath", function(data)
        if data.player == player then
            print("DragDropClientInit: Handling own player death - stopping any active drags")
            DragController.emergencyStop()
        end
    end)

    -- Handle object destruction
    DragDropErrorHandler.onError("objectDestroyed", function(data)
        print("DragDropClientInit: Object destroyed during drag:", data.object.Name)
        -- The drag controller should handle this automatically, but we can add additional cleanup here
    end)

    -- Handle network timeouts
    DragDropErrorHandler.onError("networkTimeout", function(data)
        -- Could implement retry logic or user notification here
        if DragDropSystemConfig.DEBUG.SHOW_DEBUG_INFO then
            print("DragDropClientInit: Network timeout detected")
        end
    end)

    print("DragDropClientInit: Error handler callbacks configured")
end

-- Set up client-specific configuration
function setupClientConfiguration()
    -- Set up platform-specific controls
    local UserInputService = game:GetService("UserInputService")
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        print("DragDropClientInit: Touch device detected - mobile optimizations could be added here")
        -- Future: Add touch-specific drag controls
    end

    -- Check for keyboard/mouse vs touch input
    if UserInputService.KeyboardEnabled then
        print("DragDropClientInit: Keyboard input detected - full desktop controls available")
    end

    if UserInputService.GamepadEnabled then
        print("DragDropClientInit: Gamepad detected - controller optimizations could be added here")
    end

    -- Alternative approach for performance detection without settings()
    -- We can use other indicators like screen size, device type, etc.
    local camera = workspace.CurrentCamera
    if camera then
        local screenSize = camera.ViewportSize
        local totalPixels = screenSize.X * screenSize.Y

        -- Rough performance estimation based on screen resolution
        if totalPixels < 1000000 then -- Less than ~1000x1000
            print("DragDropClientInit: Lower resolution detected - performance optimizations could be applied")
            -- Could adjust update rates, disable certain visual effects, etc.
        end
    end
end

-- Set up debug commands for testing
function setupDebugCommands()
    -- Use the existing player reference from module scope
    
    -- Add debug commands to player's chat
    player.Chatted:Connect(function(message)
        local command = message:lower()
        
        if command == "/dragstatus" then
            printSystemStatus()
        elseif command == "/dragstop" then
            DragController.emergencyStop()
            print("DEBUG: Emergency stop executed")
        elseif command == "/dragtest" then
            testDragSystem()
        elseif command:sub(1, 10) == "/dragdebug" then
            local level = command:sub(12) or "INFO"
            DragDropSystemConfig.DEBUG.DEBUG_PRINT_LEVEL = level:upper()
            print("DEBUG: Debug level set to", level:upper())
        end
    end)
    
    print("DragDropClientInit: Debug commands enabled (/dragstatus, /dragstop, /dragtest, /dragdebug)")
end

-- Print comprehensive system status
function printSystemStatus()
    print("=== Enhanced Drag-Drop System Status ===")
    
    local controllerStatus = DragController.getStatus()
    print("Controller Initialized:", controllerStatus.initialized)
    print("Drag State:", controllerStatus.dragState)
    print("Current Object:", controllerStatus.currentObject)
    
    print("Physics Status:")
    local physicsStatus = controllerStatus.physicsStatus
    print("  - Initialized:", physicsStatus.initialized)
    print("  - Dragged Objects:", physicsStatus.draggedObjects)
    print("  - Active Constraints:", physicsStatus.activeConstraints)
    
    print("Network Status:")
    local networkStatus = controllerStatus.networkStatus
    print("  - Initialized:", networkStatus.initialized)
    print("  - Pending Requests:", networkStatus.pendingRequests)
    print("  - Queued Updates:", networkStatus.queuedUpdates)
    print("  - Remote Events:", networkStatus.remoteEventsConnected)
    
    print("Configuration:")
    print("  - Server Validation:", DragDropSystemConfig.isFeatureEnabled("serverValidation"))
    print("  - Client Prediction:", DragDropSystemConfig.isFeatureEnabled("clientPrediction"))
    print("  - Weld System:", DragDropSystemConfig.isFeatureEnabled("weldSystem"))
    print("  - System Version:", DragDropSystemConfig.SYSTEM_VERSION)
    
    print("========================================")
end

-- Test the drag system with basic functionality
function testDragSystem()
    print("DEBUG: Running drag system test...")
    
    -- Test CollectionService tags
    local testPart = workspace:FindFirstChild("Baseplate")
    if testPart then
        print("  - Testing CollectionService tags...")
        print("    Draggable:", CollectionServiceTags.isDraggable(testPart))
        print("    Weldable:", CollectionServiceTags.isWeldable(testPart))
        print("    Drag in progress:", CollectionServiceTags.isDragInProgress(testPart))
    end
    
    -- Test configuration
    print("  - Testing configuration...")
    local configIssues = DragDropSystemConfig.validateConfig()
    if #configIssues == 0 then
        print("    Configuration: VALID")
    else
        print("    Configuration issues:", #configIssues)
        for _, issue in pairs(configIssues) do
            print("      -", issue)
        end
    end
    
    -- Test system status
    print("  - Testing system status...")
    local status = DragController.getStatus()
    print("    Controller ready:", status.initialized)
    print("    Physics ready:", status.physicsStatus.initialized)
    print("    Network ready:", status.networkStatus.initialized)
    
    print("DEBUG: Drag system test complete")
end

-- Get initialization status
function DragDropClientInit.getStatus()
    return {
        initialized = isInitialized,
        initTime = initializationStartTime,
        systemReady = isInitialized and DragController.getStatus().initialized
    }
end

-- Shutdown the client system
function DragDropClientInit.shutdown()
    if not isInitialized then
        warn("DragDropClientInit: System not initialized")
        return false
    end
    
    print("DragDropClientInit: Shutting down enhanced drag-drop client...")
    
    -- Shutdown the drag controller
    DragController.shutdown()
    
    isInitialized = false
    print("DragDropClientInit: Client shutdown complete")
    
    return true
end

-- Integration function for existing init.client.luau
function DragDropClientInit.integrateWithExistingClient()
    print("DragDropClientInit: Integrating with existing client initialization...")
    
    -- Wait a bit for other systems to initialize
    wait(1)
    
    return DragDropClientInit.init()
end

-- Compatibility function for legacy systems
function DragDropClientInit.getLegacyInterface()
    -- Return interface that matches old DragDropClient.lua for compatibility
    return {
        init = DragDropClientInit.init,
        getStatus = DragDropClientInit.getStatus,
        shutdown = DragDropClientInit.shutdown
    }
end

return DragDropClientInit
