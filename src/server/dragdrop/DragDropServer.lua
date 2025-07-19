--[[
    DragDropServer.lua
    Server-side validation and replication for drag and drop
]]--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragDropConfig = require(ReplicatedStorage.Shared.config.DragDropConfig)

local DragDropServer = {}
local activeDrags = {} -- Track who is dragging what

-- Remote events for client-server communication
local remoteEvents = {}

local function createRemoteEvents()
    local remoteFolder = Instance.new("Folder")
    remoteFolder.Name = "DragDropRemotes"
    remoteFolder.Parent = ReplicatedStorage
    
    local startDragRemote = Instance.new("RemoteEvent")
    startDragRemote.Name = "StartDrag"
    startDragRemote.Parent = remoteFolder
    
    local stopDragRemote = Instance.new("RemoteEvent")
    stopDragRemote.Name = "StopDrag"
    stopDragRemote.Parent = remoteFolder
    
    local updatePositionRemote = Instance.new("RemoteEvent")
    updatePositionRemote.Name = "UpdatePosition"
    updatePositionRemote.Parent = remoteFolder
    
    remoteEvents.StartDrag = startDragRemote
    remoteEvents.StopDrag = stopDragRemote
    remoteEvents.UpdatePosition = updatePositionRemote
end

local function validateDragPermission(player, object)
    -- Basic validation
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    -- Check distance
    local distance = (object.Position - player.Character.HumanoidRootPart.Position).Magnitude
    if distance > DragDropConfig.MAX_DRAG_DISTANCE then
        return false
    end
    
    -- Check if object is already being dragged
    for _, dragInfo in pairs(activeDrags) do
        if dragInfo.object == object then
            return false
        end
    end
    
    -- Check concurrent drag limit
    local playerDragCount = 0
    for _, dragInfo in pairs(activeDrags) do
        if dragInfo.player == player then
            playerDragCount = playerDragCount + 1
        end
    end
    
    if playerDragCount >= DragDropConfig.MAX_CONCURRENT_DRAGS then
        return false
    end
    
    return true
end

local function onStartDrag(player, object)
    if not validateDragPermission(player, object) then
        warn("Player", player.Name, "failed drag validation for", object.Name)
        return
    end
    
    -- Register the drag
    local dragId = player.UserId .. "_" .. tick()
    activeDrags[dragId] = {
        player = player,
        object = object,
        startTime = tick()
    }
    
    print("Player", player.Name, "started dragging", object.Name)
end

local function onStopDrag(player, object, finalPosition)
    -- Find and remove the drag
    local dragId = nil
    for id, dragInfo in pairs(activeDrags) do
        if dragInfo.player == player and dragInfo.object == object then
            dragId = id
            break
        end
    end
    
    if dragId then
        activeDrags[dragId] = nil
        
        -- Validate final position (basic bounds checking)
        if finalPosition and typeof(finalPosition) == "Vector3" then
            -- Ensure object stays within reasonable bounds
            local clampedPosition = Vector3.new(
                math.clamp(finalPosition.X, -1000, 1000),
                math.clamp(finalPosition.Y, 0, 200),
                math.clamp(finalPosition.Z, -1000, 1000)
            )
            
            object.Position = clampedPosition
        end
        
        print("Player", player.Name, "stopped dragging", object.Name)
    end
end

local function onUpdatePosition(player, object, position)
    -- Validate that player is actually dragging this object
    local isValidDrag = false
    for _, dragInfo in pairs(activeDrags) do
        if dragInfo.player == player and dragInfo.object == object then
            isValidDrag = true
            break
        end
    end
    
    if not isValidDrag then
        warn("Invalid position update from", player.Name)
        return
    end
    
    -- Optional: Replicate position to other clients for real-time updates
    -- For now, we'll let the client handle the visual updates
end

-- Clean up when player leaves
local function onPlayerRemoving(player)
    local toRemove = {}
    for dragId, dragInfo in pairs(activeDrags) do
        if dragInfo.player == player then
            table.insert(toRemove, dragId)
        end
    end
    
    for _, dragId in ipairs(toRemove) do
        activeDrags[dragId] = nil
    end
end

function DragDropServer.init()
    print("Initializing drag and drop server...")
    
    createRemoteEvents()
    
    -- Connect remote events
    remoteEvents.StartDrag.OnServerEvent:Connect(onStartDrag)
    remoteEvents.StopDrag.OnServerEvent:Connect(onStopDrag)
    remoteEvents.UpdatePosition.OnServerEvent:Connect(onUpdatePosition)
    
    -- Handle player cleanup
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    
    print("Drag and drop server ready!")
end

return DragDropServer