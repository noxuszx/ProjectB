--[[
    CollectionServiceTags.lua
    Simple utility for managing CollectionService tags for drag and drop system
]]--

local CollectionService = game:GetService("CollectionService")
local CollectionServiceTags = {}

-- Tag constants
CollectionServiceTags.DRAGGABLE             = "DRAGGABLE"
CollectionServiceTags.NON_DRAGGABLE         = "NON_DRAGGABLE"
CollectionServiceTags.WELDABLE              = "WELDABLE"
CollectionServiceTags.NON_WELDABLE          = "NON_WELDABLE"
CollectionServiceTags.STORABLE              = "STORABLE"

CollectionServiceTags.WATER_REFILL_SOURCE   = "WATER_SOURCE"
CollectionServiceTags.COOKING_SURFACE       = "COOKING_SURFACE"
CollectionServiceTags.CONSUMABLE            = "CONSUMABLE"

-- Economy system tags
CollectionServiceTags.SELL_ZONE             = "SELL_ZONE"
CollectionServiceTags.BUY_ZONE              = "BUY_ZONE"
CollectionServiceTags.SELLABLE_LOW          = "SELLABLE_LOW"
CollectionServiceTags.SELLABLE_MID          = "SELLABLE_MID"
CollectionServiceTags.SELLABLE_HIGH         = "SELLABLE_HIGH"
CollectionServiceTags.SELLABLE_SCRAP        = "SELLABLE_SCRAP"

-- Puzzle system tags
CollectionServiceTags.PEDESTAL              = "PEDESTAL"
CollectionServiceTags.EGYPT_DOOR            = "EGYPT_DOOR"
CollectionServiceTags.TOWER_BALL            = "TOWER_BALL"

CollectionServiceTags.ARENA_ANKH            = "ARENA_ANKH"
CollectionServiceTags.ARENA_ENEMY           = "ARENA_ENEMY"
CollectionServiceTags.TREASURE_DOOR         = "TREASURE_DOOR"
CollectionServiceTags.ARENA_SPAWN           = "ARENA_SPAWN"
CollectionServiceTags.ARENA_TELEPORT_MARKER = "ARENA_TELEPORT_MARKER"
CollectionServiceTags.PYRAMID_SEAL          = "PYRAMID_SEAL"

CollectionServiceTags.PYRAMID_PEDESTAL        = "PYRAMID_PEDESTAL"
CollectionServiceTags.BATTLE_TOWER_PEDESTAL_1 = "BATTLE_TOWER_PEDESTAL_1"
CollectionServiceTags.BATTLE_TOWER_PEDESTAL_2 = "BATTLE_TOWER_PEDESTAL_2"
CollectionServiceTags.BATTLE_TOWER_PEDESTAL_3 = "BATTLE_TOWER_PEDESTAL_3"

CollectionServiceTags.PROTECTED_VILLAGE     = "CMS:ProtectedVillage"
CollectionServiceTags.PROTECTED_CORE        = "CMS:ProtectedCore"
CollectionServiceTags.PROTECTED_SPAWNER     = "CMS:ProtectedSpawner"

CollectionServiceTags.TOWER                 = "Tower"
CollectionServiceTags.MOB_SPAWNER           = "MobSpawner"

CollectionServiceTags.TREASURE_SPAWNER      = "TREASURE_SPAWNER"



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

-- Protected geometry detection for CustomModelSpawner
function CollectionServiceTags.isProtectedGeometry(object)
    if not object or not object.Parent then
        return false
    end
    
    return CollectionServiceTags.hasTag(object, CollectionServiceTags.PROTECTED_VILLAGE) or
           CollectionServiceTags.hasTag(object, CollectionServiceTags.PROTECTED_CORE) or
           CollectionServiceTags.hasTag(object, CollectionServiceTags.PROTECTED_SPAWNER)
end

function CollectionServiceTags.getAllProtectedObjects()
    local protected = {}
    
    local villages = CollectionService:GetTagged(CollectionServiceTags.PROTECTED_VILLAGE)
    local cores = CollectionService:GetTagged(CollectionServiceTags.PROTECTED_CORE)
    local spawners = CollectionService:GetTagged(CollectionServiceTags.PROTECTED_SPAWNER)
    
    for _, obj in ipairs(villages) do table.insert(protected, obj) end
    for _, obj in ipairs(cores) do table.insert(protected, obj) end
    for _, obj in ipairs(spawners) do table.insert(protected, obj) end
    
    return protected
end

-- Get tagged instances that are live in workspace (not templates)
function CollectionServiceTags.getLiveTagged(tag)
    local live = {}
    for _, inst in ipairs(CollectionService:GetTagged(tag)) do
        if inst:IsDescendantOf(workspace) then
            table.insert(live, inst)
        end
    end
    return live
end

-- Debug helper to show template vs workspace tagged instances
function CollectionServiceTags.debugTaggedInstances(tag)
    local all = CollectionService:GetTagged(tag)
    local workspace_count = 0
    local template_count = 0
    
    print("[DEBUG]", tag, "- Total found:", #all)
    for _, inst in ipairs(all) do
        if inst:IsDescendantOf(workspace) then
            workspace_count = workspace_count + 1
            print("[DEBUG]   Workspace:", inst.Name, "in", inst.Parent.Name)
        else
            template_count = template_count + 1
            print("[DEBUG]   Template:", inst.Name, "in", inst.Parent.Name)
        end
    end
    print("[DEBUG]", tag, "Summary: Workspace =", workspace_count, ", Templates =", template_count)
end

-- Helper function to tag a root object and all its BasePart descendants
function CollectionServiceTags.tagDescendants(root, tag)
    if not root or not tag then
        return false
    end
    
    -- Tag the root object first
    CollectionServiceTags.addTag(root, tag)
    
    -- Tag all BasePart descendants
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("BasePart") then
            CollectionServiceTags.addTag(inst, tag)
        end
    end
    
    return true
end

return CollectionServiceTags
