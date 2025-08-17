-- src/shared/tutorial/TutorialSteps.lua
-- Data-driven tutorial steps configuration

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local TutorialSteps = {}

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

TutorialSteps.Steps = {
	{
		id = "drag_basics",
		text = "You can drag items and weld them anywhere.",
		targetSelector = function(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local origin = root and root.Position or Vector3.new()
			return findNearestByTag(CollectionServiceTags.DRAGGABLE, origin)
		end,
	},
	{
		id = "cook_food",
		text = "You can drag raw food into campfires to cook it.",
		targetSelector = function(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local origin = root and root.Position or Vector3.new()
			local CollectionService = game:GetService("CollectionService")
			local nearest, nearestDist = nil, math.huge
			for _, inst in ipairs(CollectionService:GetTagged(CollectionServiceTags.CONSUMABLE)) do
				if inst and inst:IsDescendantOf(workspace) then
					local isCookedAttr = inst:GetAttribute("IsCooked")
					local isRawTag = CollectionService:HasTag(inst, "RawMeat")
					if (isCookedAttr == false) or isRawTag then
						local pos
						if inst:IsA("BasePart") then
							pos = inst.Position
						elseif inst:IsA("Model") then
							local primary = inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
							pos = primary and primary.Position
						end
						if pos then
							local d = (pos - origin).Magnitude
							if d < nearestDist then
								nearest, nearestDist = inst, d
							end
						end
					end
				end
			end
			return nearest or findNearestByTag(CollectionServiceTags.COOKING_SURFACE, origin)
		end,
	},
	{
		id = "eat_food",
		text = "Eat the cooked food.",
		targetSelector = function(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local origin = root and root.Position or Vector3.new()
			return findNearestByTag(CollectionServiceTags.CONSUMABLE, origin)
		end,
	},
	{
		id = "sell_item",
		text = "You can sell items in village trading posts.",
		targetSelector = function(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local origin = root and root.Position or Vector3.new()
			local zone = findNearestByTag(CollectionServiceTags.SELL_ZONE, origin)
			if not zone then
				return nil
			end
			local postModel = zone:FindFirstAncestorOfClass("Model")
			return postModel or zone
		end,
	},
	{
		id = "buy_item",
		text = "You can buy items from shops.",
		targetSelector = function(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local origin = root and root.Position or Vector3.new()
			local zone = findNearestByTag(CollectionServiceTags.BUY_ZONE, origin)
			if not zone then
				return nil
			end
			local shopModel = zone:FindFirstAncestorOfClass("Model")
			return shopModel or zone
		end,
		-- completion optional; final step
	},
}

return TutorialSteps
