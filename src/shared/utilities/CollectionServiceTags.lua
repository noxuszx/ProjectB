--[[
    CollectionServiceTags.lua
    Simple utility for managing CollectionService tags for drag and drop system
]]--

local CollectionService = game:GetService("CollectionService")
local CollectionServiceTags = {}

-- Tag constants
CollectionServiceTags.DRAGGABLE = "Draggable"
CollectionServiceTags.NON_DRAGGABLE = "NonDraggable"
CollectionServiceTags.WELDABLE = "Weldable"
CollectionServiceTags.NON_WELDABLE = "NonWeldable"
CollectionServiceTags.WATER_REFILL_SOURCE = "WaterRefillSource"
CollectionServiceTags.STORABLE = "Storable"


function CollectionServiceTags.addTag(object, tag)
    if not object or not tag then
        return false
    end
    CollectionService:AddTag(object, tag)
    return true
end

function CollectionServiceTags.removeTag(object, tag)
    if not object or not tag then
        return false
    end
    CollectionService:RemoveTag(object, tag)
    return true
end

function CollectionServiceTags.hasTag(object, tag)
    if not object or not tag then
        return false
    end
    return CollectionService:HasTag(object, tag)
end

function CollectionServiceTags.isDraggable(object)
    if not object or not object.Parent then
        return false
    end

    if CollectionServiceTags.hasTag(object, CollectionServiceTags.NON_DRAGGABLE) then
        return false
    end

    if CollectionServiceTags.hasTag(object, CollectionServiceTags.DRAGGABLE) then
        return true
    end
    local parent = object.Parent
    if parent and (parent.Name == "SpawnedVegetation" or
                   parent.Name == "SpawnedRocks" or
                   parent.Name == "SpawnedStructures" or
                   parent.Name == "Chunks" or
                   parent.Name == "SpawnedCreatures" or
                   parent.Name == "PassiveCreatures" or
                   parent.Name == "HostileCreatures") then
        return false
    end

    if (object:IsA("Part") or object:IsA("MeshPart")) and not object.Anchored and parent == workspace then
        return true
    end

    return false
end


local function tagFolder(folder, tag, recursive)
    if not folder or not tag then
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

function CollectionServiceTags.initializeDefaultTags()
    print("Initializing CollectionService tags...")
    
    -- Debug: Check what's in workspace when this runs
    local creatureFolder = workspace:FindFirstChild("SpawnedCreatures")
    if creatureFolder then
        print("Found SpawnedCreatures folder with", #creatureFolder:GetChildren(), "children")
        for _, child in pairs(creatureFolder:GetChildren()) do
            print("  Creature folder child:", child.Name, child.ClassName)
        end
    end

    -- Tag terrain and environment objects (excluding creature folders since they're tagged individually when spawned)
    local nonDraggableFolders = {"Chunks", "SpawnedVegetation", "SpawnedRocks", "SpawnedStructures"}
    for _, folderName in pairs(nonDraggableFolders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            local count = tagFolder(folder, CollectionServiceTags.NON_DRAGGABLE, true)
            tagFolder(folder, CollectionServiceTags.WELDABLE, true)
            print("Tagged", count, folderName, "objects as non-draggable but weldable")
        end
    end

    local DragDropConfig = require(game.ReplicatedStorage.Shared.config.DragDropConfig)
    local suspiciousNames = {}
    for _, name in ipairs(DragDropConfig.SUSPICIOUS_NAMES or {}) do
        suspiciousNames[name] = true
    end

    for _, child in pairs(workspace:GetChildren()) do
        if (child:IsA("Part") or child:IsA("MeshPart")) and not child.Anchored then
            if suspiciousNames[child.Name] then
                CollectionServiceTags.addTag(child, CollectionServiceTags.NON_DRAGGABLE)
            elseif not CollectionServiceTags.hasTag(child, CollectionServiceTags.DRAGGABLE) and
                   not CollectionServiceTags.hasTag(child, CollectionServiceTags.NON_DRAGGABLE) then
                CollectionServiceTags.addTag(child, CollectionServiceTags.DRAGGABLE)
                CollectionServiceTags.addTag(child, CollectionServiceTags.WELDABLE)
                CollectionServiceTags.addTag(child, CollectionServiceTags.STORABLE)
            end
        end
    end

    print("Tag initialization complete!")
end

function CollectionServiceTags.tagItemsFolder()
    local itemsFolder = game.ReplicatedStorage:FindFirstChild("Items")
    if not itemsFolder then
        return 0
    end

    local count = 0
    for _, item in pairs(itemsFolder:GetChildren()) do
        if item:IsA("MeshPart") or item:IsA("Tool") then
            CollectionServiceTags.addTag(item, CollectionServiceTags.DRAGGABLE)
            CollectionServiceTags.addTag(item, CollectionServiceTags.WELDABLE)
            CollectionServiceTags.addTag(item, CollectionServiceTags.STORABLE)
            count = count + 1
        end
    end

    print("Tagged", count, "items as draggable and storable")
    return count
end



function CollectionServiceTags.isWeldable(object)
    if not object or not object.Parent then
        return false
    end

    if CollectionServiceTags.hasTag(object, CollectionServiceTags.NON_WELDABLE) then
        return false
    end

    if CollectionServiceTags.hasTag(object, CollectionServiceTags.WELDABLE) then
        return true
    end
    return object:IsA("BasePart") and object.CanCollide
end

return CollectionServiceTags
