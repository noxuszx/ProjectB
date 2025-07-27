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
CollectionServiceTags.WEAPON_PICKUP = "WeaponPickup"    -- Weapons that can be picked up

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

function CollectionServiceTags.hasTag(object, tag)
    if not object or not tag then
        return false
    end
    
    return CollectionService:HasTag(object, tag)
end

function CollectionServiceTags.getTaggedObjects(tag)
    if not tag then
        return {}
    end
    
    return CollectionService:GetTagged(tag)
end

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

function CollectionServiceTags.isDragInProgress(object)
    if not object then
        return false
    end
    return CollectionServiceTags.hasTag(object, CollectionServiceTags.DRAG_IN_PROGRESS)
end

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

function CollectionServiceTags.isValidDropZone(object)
    if not object then
        return false
    end

    if CollectionServiceTags.hasTag(object, CollectionServiceTags.NO_DROP_ZONE) then
        return false
    end

    if CollectionServiceTags.hasTag(object, CollectionServiceTags.DROP_ZONE) then
        return true
    end

    return object:IsA("BasePart") and object.CanCollide
end


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

function CollectionServiceTags.isPlayerOwned(object, player)
    if not object or not player then
        return false
    end

    local ownerTag = "PlayerOwned_" .. player.UserId
    return CollectionServiceTags.hasTag(object, ownerTag)
end

function CollectionServiceTags.setPlayerOwnership(object, player)
    if not object or not player then
        return false
    end

    for _, tag in pairs(CollectionService:GetTags(object)) do
        if tag:match("^PlayerOwned_") then
            CollectionServiceTags.removeTag(object, tag)
        end
    end

    local ownerTag = "PlayerOwned_" .. player.UserId
    CollectionServiceTags.addTag(object, ownerTag)
    CollectionServiceTags.addTag(object, CollectionServiceTags.PLAYER_OWNED)
    return true
end

function CollectionServiceTags.clearPlayerOwnership(object)
    if not object then
        return false
    end

    for _, tag in pairs(CollectionService:GetTags(object)) do
        if tag:match("^PlayerOwned_") then
            CollectionServiceTags.removeTag(object, tag)
        end
    end

    CollectionServiceTags.removeTag(object, CollectionServiceTags.PLAYER_OWNED)
    return true
end

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

function CollectionServiceTags.initializeDefaultTags()
    print("Initializing CollectionService tags for existing objects...")

    local chunksFolder = workspace:FindFirstChild("Chunks")
    if chunksFolder then
        local count = CollectionServiceTags.tagFolder(chunksFolder, CollectionServiceTags.NON_DRAGGABLE, true)
        CollectionServiceTags.tagFolder(chunksFolder, CollectionServiceTags.WELDABLE, true)
        print("Tagged", count, "chunk parts as non-draggable but weldable")
    end

    local spawnedFolders = {"SpawnedVegetation", "SpawnedRocks", "SpawnedStructures"}
    for _, folderName in pairs(spawnedFolders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            local count = CollectionServiceTags.tagFolder(folder, CollectionServiceTags.NON_DRAGGABLE, true)
            CollectionServiceTags.tagFolder(folder, CollectionServiceTags.WELDABLE, true)
            print("Tagged", count, folderName, "objects as non-draggable but weldable")
        end
    end

    -- Get suspicious names from DragDropConfig
    local DragDropConfig = require(game.ReplicatedStorage.Shared.config.DragDropConfig)
    local suspiciousNames = DragDropConfig.SUSPICIOUS_NAMES or {}

    -- Create a lookup table for faster checking
    local suspiciousNamesLookup = {}
    for _, name in ipairs(suspiciousNames) do
        suspiciousNamesLookup[name] = true
    end

    -- Tag creature folders first to ensure all creature parts are marked as non-draggable
    local creatureFolders = {"SpawnedCreatures", "PassiveCreatures", "HostileCreatures"}
    for _, folderName in pairs(creatureFolders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            local count = CollectionServiceTags.tagFolder(folder, CollectionServiceTags.NON_DRAGGABLE, true)
            print("Tagged", count, folderName, "parts as NON-draggable (creature parts)")
        end
    end

    for _, child in pairs(workspace:GetChildren()) do
        if (child:IsA("Part") or child:IsA("MeshPart")) and not child.Anchored then
            -- Skip creature body parts and other suspicious names
            if suspiciousNamesLookup[child.Name] then
                -- Tag as non-draggable to prevent accidental tagging later
                CollectionServiceTags.addTag(child, CollectionServiceTags.NON_DRAGGABLE)
                print("Tagged", child.Name, "as NON-draggable (suspicious name)")
            elseif not CollectionServiceTags.hasTag(child, CollectionServiceTags.DRAGGABLE) and
                   not CollectionServiceTags.hasTag(child, CollectionServiceTags.NON_DRAGGABLE) then
                -- Check if this part belongs to a creature
                local isCreaturePart = false
                local parent = child.Parent

                -- Check if parent is in creature folders (direct child)
                if parent and (parent.Name == "PassiveCreatures" or
                              parent.Name == "HostileCreatures" or
                              parent.Name == "SpawnedCreatures") then
                    isCreaturePart = true
                end

                -- Check if parent is a creature model (grandparent is creature folder)
                if not isCreaturePart and parent and parent.Parent then
                    local grandParent = parent.Parent
                    if grandParent and (grandParent.Name == "PassiveCreatures" or
                                       grandParent.Name == "HostileCreatures" or
                                       grandParent.Name == "SpawnedCreatures") then
                        isCreaturePart = true
                    end
                end

                -- Check if the part is inside a creature model (check if model has Humanoid)
                if not isCreaturePart and parent and parent:IsA("Model") then
                    local humanoid = parent:FindFirstChild("Humanoid")
                    if humanoid then
                        isCreaturePart = true
                    end
                end

                if isCreaturePart then
                    CollectionServiceTags.addTag(child, CollectionServiceTags.NON_DRAGGABLE)
                    print("Tagged", child.Name, "as NON-draggable (creature part)")
                else
                    CollectionServiceTags.addTag(child, CollectionServiceTags.DRAGGABLE)
                    CollectionServiceTags.addTag(child, CollectionServiceTags.WELDABLE)
                    print("Tagged", child.Name, "(", child.ClassName, ") as draggable and weldable")
                end
            end
        end
    end

    print("CollectionService tag initialization complete!")
end

function CollectionServiceTags.getAllDraggedObjects()
    return CollectionServiceTags.getTaggedObjects(CollectionServiceTags.DRAG_IN_PROGRESS)
end

function CollectionServiceTags.getPlayerOwnedObjects(player)
    if not player then
        return {}
    end

    local ownerTag = "PlayerOwned_" .. player.UserId
    return CollectionServiceTags.getTaggedObjects(ownerTag)
end

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

function CollectionServiceTags.cleanupPlayerOwnership(player)
    if not player then
        return 0
    end

    local ownedObjects = CollectionServiceTags.getPlayerOwnedObjects(player)
    local count = 0

    for _, object in pairs(ownedObjects) do
        CollectionServiceTags.clearPlayerOwnership(object)
        CollectionServiceTags.setDragInProgress(object, false)
        count = count + 1
    end

    print("Cleaned up ownership for", player.Name, "on", count, "objects")
    return count
end

function CollectionServiceTags.tagItemsFolder()
    local itemsFolder = game.ReplicatedStorage:FindFirstChild("Items")
    if not itemsFolder then
        warn("Items folder not found in ReplicatedStorage")
        return 0
    end

    local count = 0
    for _, item in pairs(itemsFolder:GetChildren()) do
        if item:IsA("MeshPart") or item:IsA("Tool") then
            CollectionServiceTags.addTag(item, CollectionServiceTags.DRAGGABLE)
            CollectionServiceTags.addTag(item, CollectionServiceTags.WELDABLE)
            count = count + 1
        end
    end

    print("Tagged", count, "items as draggable and weldable")
    return count
end

-- Function to tag a creature model as non-draggable when it's spawned
function CollectionServiceTags.tagCreatureAsNonDraggable(creatureModel)
    if not creatureModel or not creatureModel:IsA("Model") then
        warn("Invalid creature model provided to tagCreatureAsNonDraggable")
        return false
    end

    local count = 0

    -- Tag the model itself
    CollectionServiceTags.addTag(creatureModel, CollectionServiceTags.NON_DRAGGABLE)
    count = count + 1

    -- Tag all BaseParts in the creature
    for _, descendant in pairs(creatureModel:GetDescendants()) do
        if descendant:IsA("BasePart") then
            CollectionServiceTags.addTag(descendant, CollectionServiceTags.NON_DRAGGABLE)
            count = count + 1
        end
    end

    print("Tagged creature", creatureModel.Name, "and", count, "parts as NON-draggable")
    return true
end

return CollectionServiceTags
