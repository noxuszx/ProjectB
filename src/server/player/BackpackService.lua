--[[
    BackpackService.lua
    Server-side LIFO stack management for player backpacks
    Follows the sack system pattern with 10-slot capacity
]]--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local CS_tags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local BackpackService = {}
local playerBackpacks = {}

local ServerStorage = game:GetService("ServerStorage")
local storageFolder = ServerStorage:FindFirstChild("BackpackStorage")
if not storageFolder then
    storageFolder = Instance.new("Folder")
    storageFolder.Name = "BackpackStorage"
    storageFolder.Parent = ServerStorage
end

local MAX_SLOTS = 10
local COOLDOWN_TIME = 0.5 -- Prevent spam

-- Initialize player backpack
local function initializeBackpack(player)
    playerBackpacks[player.UserId] = {
        topIndex = 0,
        slots = {},
        lastAction = 0
    }
end

-- Clean up on player leave
local function cleanupBackpack(player)
    local backpack = playerBackpacks[player.UserId]
    if backpack then
        -- Return all stored objects to workspace before cleanup
        for i = 1, backpack.topIndex do
            local poolData = backpack.slots[i]
            if poolData and poolData.object and poolData.object.Parent then
                poolData.object.Parent = workspace
                -- Position randomly around spawn to avoid clustering
                local randomOffset = Vector3.new(
                    math.random(-10, 10),
                    5,
                    math.random(-10, 10)
                )
                if poolData.object:IsA("BasePart") then
                    poolData.object.CFrame = CFrame.new(randomOffset)
                elseif poolData.object:IsA("Model") and poolData.object.PrimaryPart then
                    poolData.object:SetPrimaryPartCFrame(CFrame.new(randomOffset))
                end
            end
        end
    end
    
    playerBackpacks[player.UserId] = nil
end

-- Store object reference and original position for pooling
local function storeObjectInPool(object)
    if not object or not object.Parent then
        return nil
    end
    
    -- Store original position for restoration
    local originalPosition = nil
    if object:IsA("BasePart") then
        originalPosition = object.CFrame
    elseif object:IsA("Model") and object.PrimaryPart then
        originalPosition = object.PrimaryPart.CFrame
    elseif object:IsA("Tool") then
        -- Tools don't need position storage, they get equipped
        originalPosition = CFrame.new(0, 0, 0)
    end
    
    -- Move object to storage folder (pooling)
    object.Parent = storageFolder
    
    return {
        object = object,
        originalPosition = originalPosition,
        name = object.Name,
        className = object.ClassName
    }
end

-- Restore object from pool to world
local function restoreObjectFromPool(poolData, position)
    if not poolData or not poolData.object or not poolData.object.Parent then
        return nil
    end
    
    local object = poolData.object
    
    -- Position the object at drop location
    if object:IsA("BasePart") then
        object.CFrame = CFrame.new(position)
    elseif object:IsA("Model") and object.PrimaryPart then
        object:SetPrimaryPartCFrame(CFrame.new(position))
    elseif object:IsA("Tool") then
        -- Tools will be handled by the tool system
    end
    
    -- Restore to workspace
    object.Parent = workspace
    
    return object
end

-- Get drop position in front of player
local function getDropPosition(player)
    local character = player.Character
    if not character or not character.PrimaryPart then
        return Vector3.new(0, 5, 0)
    end
    
    local humanoidRootPart = character.PrimaryPart
    local forwardDirection = humanoidRootPart.CFrame.LookVector
    
    -- Drop items further in front and at ground level for better placement
    local dropPosition = humanoidRootPart.Position + (forwardDirection * 5) + Vector3.new(0, 0.5, 0)
    
    return dropPosition
end

-- Check if object can be stored
function BackpackService.canStore(player, object)
    if not player or not object or not object.Parent then
        return false, "Invalid object"
    end
    
    local backpack = playerBackpacks[player.UserId]
    if not backpack then
        return false, "No backpack initialized"
    end
    
    if backpack.topIndex >= MAX_SLOTS then
        return false, "Backpack is full"
    end
    
    if not CS_tags.hasTag(object, CS_tags.STORABLE) then
        return false, "Object is not storable"
    end
    
    -- Extra safety: Don't allow storing alive creatures
    local humanoid = object:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health > 0 then
        return false, "Cannot store living creatures"
    end
    
    if tick() - backpack.lastAction < COOLDOWN_TIME then
        return false, "Please wait before storing again"
    end
    
    return true, "Can store"
end

-- Store object in backpack (LIFO push)
function BackpackService.storeObject(player, object)
    local canStore, reason = BackpackService.canStore(player, object)
    if not canStore then
        return false, reason
    end
    
    local backpack = playerBackpacks[player.UserId]
    local poolData = storeObjectInPool(object)
    
    if not poolData then
        return false, "Could not store object in pool"
    end
    
    -- Push to stack
    backpack.topIndex = backpack.topIndex + 1
    backpack.slots[backpack.topIndex] = poolData
    backpack.lastAction = tick()
    
    return true, "Stored " .. poolData.name, backpack
end

-- Retrieve object from backpack (LIFO pop)
function BackpackService.retrieveObject(player)
    local backpack = playerBackpacks[player.UserId]
    if not backpack then
        return false, "No backpack initialized"
    end
    
    if backpack.topIndex <= 0 then
        return false, "Backpack is empty"
    end
    
    if tick() - backpack.lastAction < COOLDOWN_TIME then
        return false, "Please wait before retrieving again"
    end
    
    -- Pop from stack
    local poolData = backpack.slots[backpack.topIndex]
    backpack.slots[backpack.topIndex] = nil
    backpack.topIndex = backpack.topIndex - 1
    backpack.lastAction = tick()
    
    -- Restore object from pool to world
    local dropPosition = getDropPosition(player)
    local restoredObject = restoreObjectFromPool(poolData, dropPosition)
    
    if restoredObject then
        return true, "Retrieved " .. poolData.name, backpack, restoredObject
    else
        -- If restoration failed, restore the stack
        backpack.topIndex = backpack.topIndex + 1
        backpack.slots[backpack.topIndex] = poolData
        return false, "Could not restore object from pool"
    end
end

-- Get backpack contents for UI sync
function BackpackService.getBackpackContents(player)
    local backpack = playerBackpacks[player.UserId]
    if not backpack then
        return {}
    end
    
    -- Return slots in display order (top of stack first)
    -- Convert poolData to UI-friendly format
    local contents = {}
    for i = backpack.topIndex, 1, -1 do
        local poolData = backpack.slots[i]
        if poolData then
            table.insert(contents, {
                Name = poolData.name,
                ClassName = poolData.className
            })
        end
    end
    
    return contents
end

-- Get backpack stats
function BackpackService.getBackpackStats(player)
    local backpack = playerBackpacks[player.UserId]
    if not backpack then
        return 0, MAX_SLOTS
    end
    
    return backpack.topIndex, MAX_SLOTS
end

-- Event handlers
Players.PlayerAdded:Connect(initializeBackpack)
Players.PlayerRemoving:Connect(cleanupBackpack)

-- Initialize existing players
for _, player in pairs(Players:GetPlayers()) do
    initializeBackpack(player)
end

return BackpackService