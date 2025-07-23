--[[
    CollectionServiceTags.lua
    Utility module for managing CollectionService tags for drag and drop system
]]--

local CollectionService = game:GetService("CollectionService")

local CollectionServiceTags = {}

-- Tag names for different object types
CollectionServiceTags.DRAGGABLE = "Draggable"
CollectionServiceTags.NON_DRAGGABLE = "NonDraggable"
CollectionServiceTags.WELDABLE = "Weldable"
CollectionServiceTags.NON_WELDABLE = "NonWeldable"

-- Enhanced drag-drop system tags
CollectionServiceTags.DRAG_IN_PROGRESS = "DragInProgress"
CollectionServiceTags.DROP_ZONE = "DropZone"
CollectionServiceTags.NO_DROP_ZONE = "NoDropZone"
CollectionServiceTags.HEAVY_OBJECT = "HeavyObject"      -- Requires special handling
CollectionServiceTags.FRAGILE_OBJECT = "FragileObject"  -- Special physics settings
CollectionServiceTags.PLAYER_OWNED = "PlayerOwned"      -- Player-specific ownership

-- Add a tag to an object
function CollectionServiceTags.addTag(object, tag)
    if not object or not tag then
        warn("Invalid object or tag provided to addTag")
        return false
    end
    
    CollectionService:AddTag(object, tag)
    return true
end

-- Remove a tag from an object
function CollectionServiceTags.removeTag(object, tag)
    if not object or not tag then
        warn("Invalid object or tag provided to removeTag")
        return false
    end
    
    CollectionService:RemoveTag(object, tag)
    return true
end

-- Check if an object has a specific tag
function CollectionServiceTags.hasTag(object, tag)
    if not object or not tag then
        return false
    end
    
    return CollectionService:HasTag(object, tag)
end

-- Get all objects with a specific tag
function CollectionServiceTags.getTaggedObjects(tag)
    if not tag then
        return {}
    end
    
    return CollectionService:GetTagged(tag)
end

-- Check if an object is draggable using tags or fallback logic
function CollectionServiceTags.isDraggable(object)
    if not object or not object.Parent then
        return false
    end
    
    -- First check explicit tags
    if CollectionServiceTags.hasTag(object, CollectionServiceTags.NON_DRAGGABLE) then
        return false
    end
    
    if CollectionServiceTags.hasTag(object, CollectionServiceTags.DRAGGABLE) then
        return true
    end
    
    -- Fallback to name-based logic for existing objects
    local parent = object.Parent
    if parent and (parent.Name == "SpawnedVegetation" or 
                   parent.Name == "SpawnedRocks" or 
                   parent.Name == "SpawnedStructures" or
                   parent.Name == "Chunks") then
        return false
    end
    
    if (object:IsA("Part") or object:IsA("MeshPart")) and not object.Anchored and parent == workspace then
        return true
    end
    
    return false
end

-- Check if an object is weldable using tags or fallback logic
function CollectionServiceTags.isWeldable(object)
    if not object or not object.Parent then
        return false
    end

    -- First check explicit tags
    if CollectionServiceTags.hasTag(object, CollectionServiceTags.NON_WELDABLE) then
        return false
    end

    if CollectionServiceTags.hasTag(object, CollectionServiceTags.WELDABLE) then
        return true
    end

    -- Fallback to existing logic
    return object:IsA("BasePart") and object.CanCollide
end

-- Enhanced drag-drop system functions

-- Check if an object is currently being dragged
function CollectionServiceTags.isDragInProgress(object)
    if not object then
        return false
    end
    return CollectionServiceTags.hasTag(object, CollectionServiceTags.DRAG_IN_PROGRESS)
end

-- Mark an object as being dragged
function CollectionServiceTags.setDragInProgress(object, inProgress)
    if not object then
        return false
    end

    if inProgress then
        CollectionServiceTags.addTag(object, CollectionServiceTags.DRAG_IN_PROGRESS)
    else
        CollectionServiceTags.removeTag(object, CollectionServiceTags.DRAG_IN_PROGRESS)
    end
    return true
end

-- Check if a location is a valid drop zone
function CollectionServiceTags.isValidDropZone(object)
    if not object then
        return false
    end

    -- Explicit no-drop zones take priority
    if CollectionServiceTags.hasTag(object, CollectionServiceTags.NO_DROP_ZONE) then
        return false
    end

    -- Explicit drop zones are always valid
    if CollectionServiceTags.hasTag(object, CollectionServiceTags.DROP_ZONE) then
        return true
    end

    -- Default: solid, collidable parts are valid drop zones
    return object:IsA("BasePart") and object.CanCollide
end

-- Check if an object requires special handling (heavy/fragile)
function CollectionServiceTags.getObjectType(object)
    if not object then
        return "normal"
    end

    if CollectionServiceTags.hasTag(object, CollectionServiceTags.HEAVY_OBJECT) then
        return "heavy"
    elseif CollectionServiceTags.hasTag(object, CollectionServiceTags.FRAGILE_OBJECT) then
        return "fragile"
    else
        return "normal"
    end
end

-- Check if an object is owned by a specific player
function CollectionServiceTags.isPlayerOwned(object, player)
    if not object or not player then
        return false
    end

    local ownerTag = "PlayerOwned_" .. player.UserId
    return CollectionServiceTags.hasTag(object, ownerTag)
end

-- Set player ownership of an object
function CollectionServiceTags.setPlayerOwnership(object, player)
    if not object or not player then
        return false
    end

    -- Remove any existing ownership tags
    for _, tag in pairs(CollectionService:GetTags(object)) do
        if tag:match("^PlayerOwned_") then
            CollectionServiceTags.removeTag(object, tag)
        end
    end

    -- Add new ownership tag
    local ownerTag = "PlayerOwned_" .. player.UserId
    CollectionServiceTags.addTag(object, ownerTag)
    CollectionServiceTags.addTag(object, CollectionServiceTags.PLAYER_OWNED)
    return true
end

-- Clear player ownership of an object
function CollectionServiceTags.clearPlayerOwnership(object)
    if not object then
        return false
    end

    -- Remove all ownership tags
    for _, tag in pairs(CollectionService:GetTags(object)) do
        if tag:match("^PlayerOwned_") then
            CollectionServiceTags.removeTag(object, tag)
        end
    end

    CollectionServiceTags.removeTag(object, CollectionServiceTags.PLAYER_OWNED)
    return true
end

-- Batch tag objects in a folder
function CollectionServiceTags.tagFolder(folder, tag, recursive)
    if not folder or not tag then
        warn("Invalid folder or tag provided to tagFolder")
        return 0
    end
    
    local count = 0
    local function processObjects(container)
        for _, child in pairs(container:GetChildren()) do
            if child:IsA("BasePart") then
                CollectionServiceTags.addTag(child, tag)
                count = count + 1
            end
            
            if recursive and (child:IsA("Folder") or child:IsA("Model")) then
                processObjects(child)
            end
        end
    end
    
    processObjects(folder)
    return count
end

-- Initialize default tags for existing objects
function CollectionServiceTags.initializeDefaultTags()
    print("Initializing CollectionService tags for existing objects...")

    -- Tag terrain chunks as non-draggable and weldable
    local chunksFolder = workspace:FindFirstChild("Chunks")
    if chunksFolder then
        local count = CollectionServiceTags.tagFolder(chunksFolder, CollectionServiceTags.NON_DRAGGABLE, true)
        CollectionServiceTags.tagFolder(chunksFolder, CollectionServiceTags.WELDABLE, true)
        print("Tagged", count, "chunk parts as non-draggable but weldable")
    end

    -- Tag spawned objects as non-draggable but weldable
    local spawnedFolders = {"SpawnedVegetation", "SpawnedRocks", "SpawnedStructures"}
    for _, folderName in pairs(spawnedFolders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            local count = CollectionServiceTags.tagFolder(folder, CollectionServiceTags.NON_DRAGGABLE, true)
            CollectionServiceTags.tagFolder(folder, CollectionServiceTags.WELDABLE, true)
            print("Tagged", count, folderName, "objects as non-draggable but weldable")
        end
    end

    -- Tag regular workspace parts and meshparts as draggable
    for _, child in pairs(workspace:GetChildren()) do
        if (child:IsA("Part") or child:IsA("MeshPart")) and not child.Anchored then
            -- Only tag if it doesn't already have draggable-related tags
            if not CollectionServiceTags.hasTag(child, CollectionServiceTags.DRAGGABLE) and
               not CollectionServiceTags.hasTag(child, CollectionServiceTags.NON_DRAGGABLE) then
                CollectionServiceTags.addTag(child, CollectionServiceTags.DRAGGABLE)
                CollectionServiceTags.addTag(child, CollectionServiceTags.WELDABLE)
                print("Tagged", child.Name, "(", child.ClassName, ") as draggable and weldable")
            end
        end
    end

    print("CollectionService tag initialization complete!")
end

-- Enhanced utility functions for drag-drop system

-- Get all objects currently being dragged
function CollectionServiceTags.getAllDraggedObjects()
    return CollectionServiceTags.getTaggedObjects(CollectionServiceTags.DRAG_IN_PROGRESS)
end

-- Get all objects owned by a specific player
function CollectionServiceTags.getPlayerOwnedObjects(player)
    if not player then
        return {}
    end

    local ownerTag = "PlayerOwned_" .. player.UserId
    return CollectionServiceTags.getTaggedObjects(ownerTag)
end

-- Clean up all drag states (useful for server cleanup)
function CollectionServiceTags.cleanupAllDragStates()
    local draggedObjects = CollectionServiceTags.getAllDraggedObjects()
    local count = 0

    for _, object in pairs(draggedObjects) do
        CollectionServiceTags.setDragInProgress(object, false)
        count = count + 1
    end

    print("Cleaned up", count, "drag states")
    return count
end

-- Clean up ownership for a disconnected player
function CollectionServiceTags.cleanupPlayerOwnership(player)
    if not player then
        return 0
    end

    local ownedObjects = CollectionServiceTags.getPlayerOwnedObjects(player)
    local count = 0

    for _, object in pairs(ownedObjects) do
        CollectionServiceTags.clearPlayerOwnership(object)
        -- Also clear any drag states
        CollectionServiceTags.setDragInProgress(object, false)
        count = count + 1
    end

    print("Cleaned up ownership for", player.Name, "on", count, "objects")
    return count
end

-- Batch tag items from the Items folder as draggable
function CollectionServiceTags.tagItemsFolder()
    local itemsFolder = game.ReplicatedStorage:FindFirstChild("Items")
    if not itemsFolder then
        warn("Items folder not found in ReplicatedStorage")
        return 0
    end

    local count = 0
    for _, item in pairs(itemsFolder:GetChildren()) do
        if item:IsA("MeshPart") or item:IsA("Tool") then
            -- Items should be draggable and weldable by default
            CollectionServiceTags.addTag(item, CollectionServiceTags.DRAGGABLE)
            CollectionServiceTags.addTag(item, CollectionServiceTags.WELDABLE)
            count = count + 1
        end
    end

    print("Tagged", count, "items as draggable and weldable")
    return count
end

return CollectionServiceTags
