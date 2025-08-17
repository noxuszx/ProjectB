-- src/client/food/CookingSoundWatcher.client.lua
-- Plays local SFX when a consumable finishes cooking (IsCooked attribute turns true)
-- Lightweight client-only listener; no server validation. Attach sound to the food instance if available.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local SoundPlayer = require(ReplicatedStorage.Shared.modules.SoundPlayer)

local function bind(inst)
	if not inst or not inst.Parent then return end
	if not (CollectionService:HasTag(inst, CollectionServiceTags.CONSUMABLE) or (inst.Parent and CollectionService:HasTag(inst.Parent, CollectionServiceTags.CONSUMABLE))) then
		return
	end
	-- Only bind once per instance
	if inst:GetAttribute("__CookSFXBound") then return end
	inst:SetAttribute("__CookSFXBound", true)

	local container = inst
	if not container:IsA("Model") then
		local maybeModel = inst:FindFirstAncestorOfClass("Model")
		if maybeModel then container = maybeModel end
	end

	local function playCooked()
		-- Play at the instance for 3D spatialization if possible
		local parent = (container:IsA("Model") and (container.PrimaryPart or container)) or container
		SoundPlayer.playAt("food.cook_done", parent)
	end

	-- Immediate check in case it is already cooked
	if (container:GetAttribute("IsCooked")) == true then
		playCooked()
		return
	end

	container:GetAttributeChangedSignal("IsCooked"):Connect(function()
		if container:GetAttribute("IsCooked") == true then
			playCooked()
		end
	end)
end

-- Bind existing consumables
for _, inst in ipairs(CollectionService:GetTagged(CollectionServiceTags.CONSUMABLE)) do
	bind(inst)
end

-- Bind newly tagged consumables
CollectionService:GetInstanceAddedSignal(CollectionServiceTags.CONSUMABLE):Connect(function(inst)
	bind(inst)
end)

