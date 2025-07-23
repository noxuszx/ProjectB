--[[
    DragDropSystemConfig.lua
    Enhanced configuration for the professional drag-drop system
    This extends the existing DragDropConfig.lua with additional settings
]]--

local DragDropSystemConfig = {}

-- Import existing config for compatibility
local DragDropConfig = require(script.Parent.DragDropConfig)

-- Inherit all existing settings
for key, value in pairs(DragDropConfig) do
    DragDropSystemConfig[key] = value
end

-- Enhanced System Settings
DragDropSystemConfig.SYSTEM_VERSION = "2.0"
DragDropSystemConfig.DEBUG_MODE = false

-- Server Authority Settings
DragDropSystemConfig.SERVER_VALIDATION_ENABLED = true
DragDropSystemConfig.CLIENT_PREDICTION_ENABLED = true
DragDropSystemConfig.POSITION_VALIDATION_TOLERANCE = 5.0  -- studs
DragDropSystemConfig.MAX_DRAG_REQUESTS_PER_SECOND = 30    -- Increased for normal gameplay
DragDropSystemConfig.VALIDATION_TIMEOUT = 2.0  -- seconds

-- Physics Enhancement Settings
DragDropSystemConfig.USE_ALIGN_POSITION = true
DragDropSystemConfig.USE_BODY_POSITION_FALLBACK = false

-- AlignPosition settings (preferred method)
DragDropSystemConfig.ALIGN_POSITION_SETTINGS = {
    MaxForce = math.huge,
    MaxVelocity = 50,
    Responsiveness = 15,
    RigidityEnabled = false,
    ApplyAtCenterOfMass = true
}

-- AlignOrientation settings
DragDropSystemConfig.ALIGN_ORIENTATION_SETTINGS = {
    MaxTorque = math.huge,
    MaxAngularVelocity = 20,
    Responsiveness = 10,
    RigidityEnabled = false
}

-- Object Type Specific Settings
DragDropSystemConfig.OBJECT_TYPE_SETTINGS = {
    normal = {
        maxForce = 10000,
        responsiveness = 15,
        maxVelocity = 30
    },
    heavy = {
        maxForce = 25000,
        responsiveness = 8,
        maxVelocity = 15,
        requiresMultipleClicks = false,
        dragSpeedMultiplier = 0.7
    },
    fragile = {
        maxForce = 5000,
        responsiveness = 20,
        maxVelocity = 20,
        gentleDropping = true,
        breakOnHighImpact = false  -- For future implementation
    }
}

-- Network Communication Settings
DragDropSystemConfig.REMOTE_EVENTS = {
    REQUEST_START_DRAG = "RequestStartDrag",
    REQUEST_STOP_DRAG = "RequestStopDrag",
    DRAG_POSITION_UPDATE = "DragPositionUpdate",
    DRAG_VALIDATION_RESULT = "DragValidationResult",
    DRAG_STATE_SYNC = "DragStateSync"
}

-- Update Rate Management
DragDropSystemConfig.UPDATE_RATES = {
    CLIENT_PHYSICS = 1/60,      -- 60fps for smooth local physics
    CLIENT_VISUAL = 1/30,       -- 30fps for visual effects
    NETWORK_POSITION = 1/20,    -- 20fps for network updates
    SERVER_VALIDATION = 1/15,   -- 15fps for server validation
    STATE_CLEANUP = 1/5         -- 5fps for cleanup operations
}

-- Distance and Range Settings
DragDropSystemConfig.DISTANCE_LIMITS = {
    MAX_DRAG_INITIATION_DISTANCE = 15,  -- Max distance to start drag
    MAX_DRAG_MAINTAIN_DISTANCE = 25,    -- Max distance to maintain drag
    MIN_DROP_HEIGHT = 0.5,              -- Minimum height above ground
    MAX_DROP_HEIGHT = 50,               -- Maximum drop height
    WELD_DETECTION_RADIUS = 5           -- Radius for weld target detection
}

-- Visual Feedback Settings
DragDropSystemConfig.VISUAL_SETTINGS = {
    HOVER_HIGHLIGHT_COLOR = Color3.fromRGB(0, 255, 255),
    DRAG_HIGHLIGHT_COLOR = Color3.fromRGB(255, 255, 0),
    ERROR_HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 0),
    HIGHLIGHT_TRANSPARENCY = 0.7,
    SHOW_DRAG_TRAIL = true,
    TRAIL_LIFETIME = 2.0,
    SHOW_DROP_PREVIEW = true
}

-- Security and Anti-Exploit Settings
DragDropSystemConfig.SECURITY = {
    ENABLE_OWNERSHIP_SYSTEM = true,
    ALLOW_CROSS_PLAYER_DRAGGING = false,
    MAX_CONCURRENT_DRAGS_PER_PLAYER = 3,
    ENABLE_MASS_LIMITS = true,
    MIN_DRAG_MASS = 0.1,
    MAX_DRAG_MASS = 1000,
    ENABLE_DISTANCE_CHECKS = true,
    ENABLE_RATE_LIMITING = false,  -- Temporarily disabled for testing
    LOG_SUSPICIOUS_ACTIVITY = true
}

-- Performance Optimization Settings
DragDropSystemConfig.PERFORMANCE = {
    ENABLE_SPATIAL_PARTITIONING = true,
    MAX_OBJECTS_PER_REGION = 100,
    ENABLE_OBJECT_POOLING = true,
    POOL_SIZE = 50,
    ENABLE_LOD_SYSTEM = false,  -- Level of Detail (future feature)
    GARBAGE_COLLECTION_INTERVAL = 30  -- seconds
}

-- Integration Settings
DragDropSystemConfig.INTEGRATION = {
    WELD_SYSTEM_ENABLED = true,
    WELD_KEY = Enum.KeyCode.Z,
    ITEM_SPAWNER_INTEGRATION = true,
    TERRAIN_COLLISION_ENABLED = true,
    CHUNK_BOUNDARY_RESPECT = true
}

-- Error Handling and Recovery
DragDropSystemConfig.ERROR_HANDLING = {
    AUTO_CLEANUP_ON_ERROR = true,
    RETRY_FAILED_OPERATIONS = true,
    MAX_RETRY_ATTEMPTS = 3,
    FALLBACK_TO_SIMPLE_PHYSICS = true,
    LOG_ERRORS = true,
    NOTIFY_PLAYERS_OF_ERRORS = false
}

-- Debug and Development Settings
DragDropSystemConfig.DEBUG = {
    SHOW_DEBUG_INFO = false,
    SHOW_PHYSICS_VISUALIZERS = false,
    LOG_NETWORK_TRAFFIC = false,
    LOG_PERFORMANCE_METRICS = false,
    ENABLE_PROFILING = false,
    DEBUG_PRINT_LEVEL = "WARN"  -- "DEBUG", "INFO", "WARN", "ERROR"
}

-- Validation Functions
function DragDropSystemConfig.validateConfig()
    local issues = {}
    
    -- Check critical settings
    if DragDropSystemConfig.MAX_DRAG_DISTANCE <= 0 then
        table.insert(issues, "MAX_DRAG_DISTANCE must be positive")
    end
    
    if DragDropSystemConfig.UPDATE_RATES.CLIENT_PHYSICS <= 0 then
        table.insert(issues, "CLIENT_PHYSICS update rate must be positive")
    end
    
    if DragDropSystemConfig.SECURITY.MAX_CONCURRENT_DRAGS_PER_PLAYER <= 0 then
        table.insert(issues, "MAX_CONCURRENT_DRAGS_PER_PLAYER must be positive")
    end
    
    -- Warn about potential performance issues
    if DragDropSystemConfig.UPDATE_RATES.CLIENT_PHYSICS > 1/30 then
        table.insert(issues, "WARNING: CLIENT_PHYSICS update rate may cause performance issues")
    end
    
    return issues
end

-- Get settings for specific object type
function DragDropSystemConfig.getObjectSettings(objectType)
    return DragDropSystemConfig.OBJECT_TYPE_SETTINGS[objectType] or DragDropSystemConfig.OBJECT_TYPE_SETTINGS.normal
end

-- Check if a feature is enabled
function DragDropSystemConfig.isFeatureEnabled(feature)
    local features = {
        serverValidation = DragDropSystemConfig.SERVER_VALIDATION_ENABLED,
        clientPrediction = DragDropSystemConfig.CLIENT_PREDICTION_ENABLED,
        ownershipSystem = DragDropSystemConfig.SECURITY.ENABLE_OWNERSHIP_SYSTEM,
        weldSystem = DragDropSystemConfig.INTEGRATION.WELD_SYSTEM_ENABLED,
        spatialPartitioning = DragDropSystemConfig.PERFORMANCE.ENABLE_SPATIAL_PARTITIONING
    }
    
    return features[feature] or false
end

return DragDropSystemConfig
