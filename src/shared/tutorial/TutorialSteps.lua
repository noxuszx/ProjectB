-- src/shared/tutorial/TutorialSteps.lua
-- Data-driven tutorial steps configuration
-- Each step: id, text, targetSelector, onStart (optional), completionCheck, onComplete (optional)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local TutorialSteps = {}

-- Utility to find nearest instance by tag
local function findNearestByTag(tag, originPosition)
    local nearest, nearestDist = nil, math.huge
    for _, inst in ipairs(game:GetService("CollectionService"):GetTagged(tag)) do
        if inst and inst:IsDescendantOf(workspace) then
            local pos
            if inst:IsA("BasePart") then
                pos = inst.Position
            elseif inst:IsA("Model") then
                local primary = inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
                pos = primary and primary.Position
            end
            if pos then
                local d = (pos - originPosition).Magnitude
                if d < nearestDist then
                    nearest, nearestDist = inst, d
                end
            end
        end
    end
    return nearest
end

-- Provide step definitions. The controller will call targetSelector(player) to get current target.
TutorialSteps.Steps = {
    {
        id = "drag_basics",
        text = "You can drag items and weld them anywhere.",
        targetSelector = function(player)
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local origin = root and root.Position or Vector3.new()
            -- Target a nearby draggable item
            return findNearestByTag(CollectionServiceTags.DRAGGABLE, origin)
        end,
        -- completion handled on client by raycast+click detection in controller
    },
    {
        id = "cook_food",
        text = "You can drag raw food into campfires to cook it.",
        targetSelector = function(player)
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local origin = root and root.Position or Vector3.new()
            return findNearestByTag(CollectionServiceTags.COOKING_SURFACE, origin)
        end,
        -- completion heuristic handled by controller (detect cooked item nearby or server hint)
    },
    {
        id = "eat_food",
        text = "Eat the cooked food.",
        targetSelector = function(player)
            -- Highlight nearest consumable as a hint
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local origin = root and root.Position or Vector3.new()
            return findNearestByTag(CollectionServiceTags.CONSUMABLE, origin)
        end,
        -- completion handled by controller via UpdatePlayerStats (Hunger increase)
    },
    {
        id = "sell_item",
        text = "You can sell items in village trading posts.",
        targetSelector = function(player)
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local origin = root and root.Position or Vector3.new()
            return findNearestByTag(CollectionServiceTags.SELL_ZONE, origin)
        end,
        -- completion handled by controller via money increase or server hint
    },
    {
        id = "buy_item",
        text = "You can buy items from shops.",
        targetSelector = function(player)
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local origin = root and root.Position or Vector3.new()
            return findNearestByTag(CollectionServiceTags.BUY_ZONE, origin)
        end,
        -- completion optional; final step
    },
}

return TutorialSteps

