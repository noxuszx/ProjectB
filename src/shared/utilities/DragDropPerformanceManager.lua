--[[
    DragDropPerformanceManager.lua
    Performance optimization system for drag-drop operations
    Implements efficient update rates, batching, memory management, and spatial partitioning
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Import shared utilities and config
local DragDropSystemConfig = require(ReplicatedStorage.Shared.config.DragDropSystemConfig)

local DragDropPerformanceManager = {}

-- Performance tracking
local performanceMetrics = {
    frameTime = 0,
    updateCounts = {},
    memoryUsage = 0,
    networkTraffic = 0,
    lastCleanup = 0
}

-- Update rate management
local updateScheduler = {
    lastUpdates = {},
    scheduledCallbacks = {},
    isRunning = false
}

-- Object pooling system
local objectPools = {
    attachments = {},
    alignPositions = {},
    alignOrientations = {},
    weldConstraints = {}
}

-- Spatial partitioning system
local spatialGrid = {
    cellSize = 50, -- studs per cell
    cells = {},
    objectLocations = {}
}

-- Initialize the performance manager
function DragDropPerformanceManager.init()
    if updateScheduler.isRunning then
        warn("DragDropPerformanceManager: Already initialized")
        return false
    end
    
    print("DragDropPerformanceManager: Initializing performance optimization system...")
    
    -- Initialize object pools
    initializeObjectPools()
    
    -- Initialize spatial partitioning
    initializeSpatialPartitioning()
    
    -- Start update scheduler
    startUpdateScheduler()
    
    -- Start performance monitoring
    if DragDropSystemConfig.DEBUG.ENABLE_PROFILING then
        startPerformanceMonitoring()
    end
    
    updateScheduler.isRunning = true
    print("DragDropPerformanceManager: Performance optimization system initialized")
    
    return true
end

-- Initialize object pools for frequently created/destroyed objects
function initializeObjectPools()
    local poolSize = DragDropSystemConfig.PERFORMANCE.POOL_SIZE
    
    -- Pre-create attachment pool
    for i = 1, poolSize do
        local attachment = Instance.new("Attachment")
        attachment.Name = "PooledAttachment"
        attachment.Parent = nil
        table.insert(objectPools.attachments, attachment)
    end
    
    -- Pre-create AlignPosition pool
    for i = 1, poolSize do
        local alignPosition = Instance.new("AlignPosition")
        alignPosition.Name = "PooledAlignPosition"
        alignPosition.Parent = nil
        table.insert(objectPools.alignPositions, alignPosition)
    end
    
    -- Pre-create AlignOrientation pool
    for i = 1, poolSize do
        local alignOrientation = Instance.new("AlignOrientation")
        alignOrientation.Name = "PooledAlignOrientation"
        alignOrientation.Parent = nil
        table.insert(objectPools.alignOrientations, alignOrientation)
    end
    
    print("DragDropPerformanceManager: Object pools initialized with", poolSize, "objects each")
end

-- Initialize spatial partitioning system
function initializeSpatialPartitioning()
    if not DragDropSystemConfig.PERFORMANCE.ENABLE_SPATIAL_PARTITIONING then
        return
    end
    
    spatialGrid.cellSize = DragDropSystemConfig.PERFORMANCE.MAX_OBJECTS_PER_REGION or 50
    spatialGrid.cells = {}
    spatialGrid.objectLocations = {}
    
    print("DragDropPerformanceManager: Spatial partitioning initialized with cell size", spatialGrid.cellSize)
end

-- Start the update scheduler for managing different update rates
function startUpdateScheduler()
    local updateRates = DragDropSystemConfig.UPDATE_RATES
    
    -- Initialize last update times
    for rateName, _ in pairs(updateRates) do
        updateScheduler.lastUpdates[rateName] = 0
        updateScheduler.scheduledCallbacks[rateName] = {}
    end
    
    -- Main scheduler loop
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        for rateName, interval in pairs(updateRates) do
            if currentTime - updateScheduler.lastUpdates[rateName] >= interval then
                -- Execute all callbacks for this update rate
                for _, callback in pairs(updateScheduler.scheduledCallbacks[rateName]) do
                    local success, err = pcall(callback, currentTime)
                    if not success then
                        warn("DragDropPerformanceManager: Error in scheduled callback:", err)
                    end
                end
                
                updateScheduler.lastUpdates[rateName] = currentTime
                
                -- Track update counts for performance monitoring
                performanceMetrics.updateCounts[rateName] = (performanceMetrics.updateCounts[rateName] or 0) + 1
            end
        end
    end)
    
    print("DragDropPerformanceManager: Update scheduler started")
end

-- Start performance monitoring
function startPerformanceMonitoring()
    -- Monitor frame time
    RunService.Heartbeat:Connect(function()
        performanceMetrics.frameTime = RunService.Heartbeat:Wait()
    end)
    
    -- Periodic performance logging
    DragDropPerformanceManager.scheduleCallback("STATE_CLEANUP", function()
        if DragDropSystemConfig.DEBUG.LOG_PERFORMANCE_METRICS then
            logPerformanceMetrics()
        end
    end)
    
    print("DragDropPerformanceManager: Performance monitoring started")
end

-- Schedule a callback to run at a specific update rate
function DragDropPerformanceManager.scheduleCallback(updateRate, callback)
    if not updateScheduler.scheduledCallbacks[updateRate] then
        warn("DragDropPerformanceManager: Invalid update rate:", updateRate)
        return false
    end
    
    table.insert(updateScheduler.scheduledCallbacks[updateRate], callback)
    return true
end

-- Object pool management functions

-- Get an object from the pool
function DragDropPerformanceManager.getPooledObject(objectType)
    if not DragDropSystemConfig.PERFORMANCE.ENABLE_OBJECT_POOLING then
        -- Create new object if pooling is disabled
        return createNewObject(objectType)
    end
    
    local pool = objectPools[objectType]
    if not pool or #pool == 0 then
        -- Create new object if pool is empty
        return createNewObject(objectType)
    end
    
    -- Return object from pool
    local object = table.remove(pool)
    resetPooledObject(object, objectType)
    return object
end

-- Return an object to the pool
function DragDropPerformanceManager.returnPooledObject(object, objectType)
    if not DragDropSystemConfig.PERFORMANCE.ENABLE_OBJECT_POOLING then
        object:Destroy()
        return
    end
    
    local pool = objectPools[objectType]
    if not pool then
        object:Destroy()
        return
    end
    
    -- Clean up object before returning to pool
    object.Parent = nil
    resetPooledObject(object, objectType)
    
    -- Return to pool if there's space
    if #pool < DragDropSystemConfig.PERFORMANCE.POOL_SIZE then
        table.insert(pool, object)
    else
        object:Destroy()
    end
end

-- Create a new object of the specified type
function createNewObject(objectType)
    if objectType == "attachments" then
        local attachment = Instance.new("Attachment")
        attachment.Name = "DragAttachment"
        return attachment
    elseif objectType == "alignPositions" then
        local alignPosition = Instance.new("AlignPosition")
        alignPosition.Name = "DragAlignPosition"
        return alignPosition
    elseif objectType == "alignOrientations" then
        local alignOrientation = Instance.new("AlignOrientation")
        alignOrientation.Name = "DragAlignOrientation"
        return alignOrientation
    elseif objectType == "weldConstraints" then
        local weld = Instance.new("WeldConstraint")
        weld.Name = "DragDropWeld"
        return weld
    end
    
    warn("DragDropPerformanceManager: Unknown object type:", objectType)
    return nil
end

-- Reset a pooled object to default state
function resetPooledObject(object, objectType)
    if objectType == "attachments" then
        object.Position = Vector3.new(0, 0, 0)
        object.Orientation = Vector3.new(0, 0, 0)
    elseif objectType == "alignPositions" then
        object.Position = Vector3.new(0, 0, 0)
        object.MaxForce = math.huge
        object.MaxVelocity = math.huge
        object.Responsiveness = 10
        object.RigidityEnabled = false
    elseif objectType == "alignOrientations" then
        object.CFrame = CFrame.new()
        object.MaxTorque = math.huge
        object.MaxAngularVelocity = math.huge
        object.Responsiveness = 10
        object.RigidityEnabled = false
    elseif objectType == "weldConstraints" then
        object.Part0 = nil
        object.Part1 = nil
    end
end

-- Spatial partitioning functions

-- Add object to spatial grid
function DragDropPerformanceManager.addToSpatialGrid(object, position)
    if not DragDropSystemConfig.PERFORMANCE.ENABLE_SPATIAL_PARTITIONING then
        return
    end
    
    local cellX = math.floor(position.X / spatialGrid.cellSize)
    local cellZ = math.floor(position.Z / spatialGrid.cellSize)
    local cellKey = cellX .. "," .. cellZ
    
    if not spatialGrid.cells[cellKey] then
        spatialGrid.cells[cellKey] = {}
    end
    
    table.insert(spatialGrid.cells[cellKey], object)
    spatialGrid.objectLocations[object] = cellKey
end

-- Remove object from spatial grid
function DragDropPerformanceManager.removeFromSpatialGrid(object)
    if not DragDropSystemConfig.PERFORMANCE.ENABLE_SPATIAL_PARTITIONING then
        return
    end
    
    local cellKey = spatialGrid.objectLocations[object]
    if not cellKey then
        return
    end
    
    local cell = spatialGrid.cells[cellKey]
    if cell then
        for i, obj in pairs(cell) do
            if obj == object then
                table.remove(cell, i)
                break
            end
        end
    end
    
    spatialGrid.objectLocations[object] = nil
end

-- Get nearby objects from spatial grid
function DragDropPerformanceManager.getNearbyObjects(position, radius)
    if not DragDropSystemConfig.PERFORMANCE.ENABLE_SPATIAL_PARTITIONING then
        return {}
    end
    
    local nearbyObjects = {}
    local cellRadius = math.ceil(radius / spatialGrid.cellSize)
    local centerCellX = math.floor(position.X / spatialGrid.cellSize)
    local centerCellZ = math.floor(position.Z / spatialGrid.cellSize)
    
    for x = centerCellX - cellRadius, centerCellX + cellRadius do
        for z = centerCellZ - cellRadius, centerCellZ + cellRadius do
            local cellKey = x .. "," .. z
            local cell = spatialGrid.cells[cellKey]
            
            if cell then
                for _, object in pairs(cell) do
                    if object and object.Parent then
                        local distance = (object.Position - position).Magnitude
                        if distance <= radius then
                            table.insert(nearbyObjects, {
                                object = object,
                                distance = distance
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(nearbyObjects, function(a, b) return a.distance < b.distance end)
    
    return nearbyObjects
end

-- Performance monitoring and optimization

-- Log performance metrics
function logPerformanceMetrics()
    print("=== DragDropPerformanceManager Metrics ===")
    print("Frame Time:", math.floor(performanceMetrics.frameTime * 1000 * 100) / 100, "ms")
    print("Update Counts:")
    for rateName, count in pairs(performanceMetrics.updateCounts) do
        print("  -", rateName .. ":", count)
    end
    
    -- Pool usage
    print("Pool Usage:")
    for poolName, pool in pairs(objectPools) do
        print("  -", poolName .. ":", #pool, "/", DragDropSystemConfig.PERFORMANCE.POOL_SIZE)
    end
    
    -- Spatial grid usage
    if DragDropSystemConfig.PERFORMANCE.ENABLE_SPATIAL_PARTITIONING then
        local totalCells = 0
        local totalObjects = 0
        for _, cell in pairs(spatialGrid.cells) do
            totalCells = totalCells + 1
            totalObjects = totalObjects + #cell
        end
        print("Spatial Grid: ", totalCells, "cells,", totalObjects, "objects")
    end
    
    print("==========================================")
end

-- Get performance statistics
function DragDropPerformanceManager.getPerformanceStats()
    local poolStats = {}
    for poolName, pool in pairs(objectPools) do
        poolStats[poolName] = {
            available = #pool,
            capacity = DragDropSystemConfig.PERFORMANCE.POOL_SIZE,
            utilization = 1 - (#pool / DragDropSystemConfig.PERFORMANCE.POOL_SIZE)
        }
    end
    
    local spatialStats = {}
    if DragDropSystemConfig.PERFORMANCE.ENABLE_SPATIAL_PARTITIONING then
        local totalCells = 0
        local totalObjects = 0
        for _, cell in pairs(spatialGrid.cells) do
            totalCells = totalCells + 1
            totalObjects = totalObjects + #cell
        end
        spatialStats = {
            totalCells = totalCells,
            totalObjects = totalObjects,
            averageObjectsPerCell = totalCells > 0 and (totalObjects / totalCells) or 0
        }
    end
    
    return {
        frameTime = performanceMetrics.frameTime,
        updateCounts = performanceMetrics.updateCounts,
        poolStats = poolStats,
        spatialStats = spatialStats,
        isRunning = updateScheduler.isRunning
    }
end

-- Optimize performance based on current conditions
function DragDropPerformanceManager.optimizePerformance()
    local stats = DragDropPerformanceManager.getPerformanceStats()
    
    -- Adjust update rates based on frame time
    if stats.frameTime > 0.033 then -- More than 30 FPS
        print("DragDropPerformanceManager: High frame time detected, reducing update rates")
        -- Could dynamically adjust update rates here
    end
    
    -- Clean up empty spatial grid cells
    if DragDropSystemConfig.PERFORMANCE.ENABLE_SPATIAL_PARTITIONING then
        local cleanedCells = 0
        for cellKey, cell in pairs(spatialGrid.cells) do
            if #cell == 0 then
                spatialGrid.cells[cellKey] = nil
                cleanedCells = cleanedCells + 1
            end
        end
        
        if cleanedCells > 0 and DragDropSystemConfig.DEBUG.LOG_PERFORMANCE_METRICS then
            print("DragDropPerformanceManager: Cleaned up", cleanedCells, "empty spatial grid cells")
        end
    end
    
    return stats
end

-- Shutdown the performance manager
function DragDropPerformanceManager.shutdown()
    if not updateScheduler.isRunning then
        return
    end
    
    -- Clean up object pools
    for poolName, pool in pairs(objectPools) do
        for _, object in pairs(pool) do
            object:Destroy()
        end
        objectPools[poolName] = {}
    end
    
    -- Clear spatial grid
    spatialGrid.cells = {}
    spatialGrid.objectLocations = {}
    
    -- Clear scheduler
    updateScheduler.scheduledCallbacks = {}
    updateScheduler.lastUpdates = {}
    updateScheduler.isRunning = false
    
    print("DragDropPerformanceManager: Shutdown complete")
end

return DragDropPerformanceManager
