-- src/client/economy/ItemHoverHighlighting.client.lua
-- Client-side highlighting system for buyable items on hover (green=buyable, red=not buyable)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Configuration
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)

-- Player references
local player = Players.LocalPlayer

-- RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Economy")
local updateMoneyRemote = remotes:WaitForChild("UpdateMoney")
local buyItemRemote = remotes:WaitForChild("BuyItem")

-- State tracking
local currentMoney = 0
local hoveredItemHighlight = nil
local lastHoveredItem = nil

-- Get item cost from config
local function getItemCost(itemName)
	for _, itemData in pairs(EconomyConfig.BuyableItems) do
		if itemData.ItemName == itemName then
			return itemData.Cost
		end
	end
	return nil -- Item not buyable
end

-- Check if item is buyable (exists in config)
local function isItemBuyable(item)
	if not item or not item.Name then
		return false
	end

	local cost = getItemCost(item.Name)
	return cost ~= nil
end

-- Check if player can afford the item
local function canAffordItem(item)
	local cost = getItemCost(item.Name)
	if not cost then
		return false
	end
	return currentMoney >= cost
end

-- Create highlight for hovered item
local function createItemHighlight(item, canAfford)
	-- Remove existing highlight
	if hoveredItemHighlight then
		hoveredItemHighlight:Destroy()
		hoveredItemHighlight = nil
	end

	-- Create new highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "ItemHoverHighlight"
	highlight.Parent = item
	highlight.FillTransparency = EconomyConfig.UI.Highlighting.Transparency
	highlight.OutlineTransparency = 0

	-- Set color based on affordability
	if canAfford then
		highlight.FillColor = EconomyConfig.UI.Highlighting.CanAfford -- Green
		highlight.OutlineColor = EconomyConfig.UI.Highlighting.CanAfford
	else
		highlight.FillColor = EconomyConfig.UI.Highlighting.CannotAfford -- Red
		highlight.OutlineColor = EconomyConfig.UI.Highlighting.CannotAfford
	end

	hoveredItemHighlight = highlight

end

-- Remove highlight
local function removeItemHighlight()
	if hoveredItemHighlight then
		hoveredItemHighlight:Destroy()
		hoveredItemHighlight = nil
	end
	lastHoveredItem = nil
end

-- Handle mouse hover detection
local function checkMouseHover()
	local mouse = player:GetMouse()
	local target = mouse.Target

	-- Check if we're hovering over a different item
	if target ~= lastHoveredItem then
		removeItemHighlight()

		-- Check if new target is a buyable item model
		if target then
			local item = target.Parent
			if item and item:IsA("Model") and isItemBuyable(item) then
				local canAfford = canAffordItem(item)
				createItemHighlight(item, canAfford)
				lastHoveredItem = target
			end
		end
	end
end

-- Handle money updates
local function onMoneyUpdated(newAmount)
	currentMoney = newAmount

	-- Update highlight if we're currently hovering over an item
	if lastHoveredItem and lastHoveredItem.Parent then
		local item = lastHoveredItem.Parent
		if isItemBuyable(item) then
			local canAfford = canAffordItem(item)
			createItemHighlight(item, canAfford)
		end
	end
end

-- Item purchasing is now handled by ProximityPrompts in BuyZoneHandler
-- This click-based system is disabled to avoid conflicts

-- Initialize the system
local function init()
	-- Connect to money updates
	updateMoneyRemote.OnClientEvent:Connect(onMoneyUpdated)

	-- Click-based purchasing removed - now using ProximityPrompts

	-- Run hover detection continuously for visual feedback
	RunService.Heartbeat:Connect(checkMouseHover)

	if _G.SystemLoadMonitor then
		_G.SystemLoadMonitor.reportSystemLoaded("ItemHoverHighlighting")
	end
end

-- Start the system
init()
