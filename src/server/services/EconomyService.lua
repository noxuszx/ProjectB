-- src/server/services/EconomyService.lua
-- Core economy system service for managing player money, selling, and buying

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- Configuration
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)
local PlayerStatsConfig = require(ReplicatedStorage.Shared.config.PlayerStatsConfig)

-- Create Remotes folder if it doesn't exist
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

-- Create Economy folder if it doesn't exist
local economyFolder = remotesFolder:FindFirstChild("Economy")
if not economyFolder then
	economyFolder = Instance.new("Folder")
	economyFolder.Name = "Economy"
	economyFolder.Parent = remotesFolder
end

-- Create RemoteEvents if they don't exist
local updateMoneyRemote = economyFolder:FindFirstChild("UpdateMoney")
if not updateMoneyRemote then
	updateMoneyRemote = Instance.new("RemoteEvent")
	updateMoneyRemote.Name = "UpdateMoney"
	updateMoneyRemote.Parent = economyFolder
end

local sellItemRemote = economyFolder:FindFirstChild("SellItem")
if not sellItemRemote then
	sellItemRemote = Instance.new("RemoteEvent")
	sellItemRemote.Name = "SellItem"
	sellItemRemote.Parent = economyFolder
end

local buyItemRemote = economyFolder:FindFirstChild("BuyItem")
if not buyItemRemote then
	buyItemRemote = Instance.new("RemoteEvent")
	buyItemRemote.Name = "BuyItem"
	buyItemRemote.Parent = economyFolder
end

local refreshBuyZonesRemote = economyFolder:FindFirstChild("RefreshBuyZones")
if not refreshBuyZonesRemote then
	refreshBuyZonesRemote = Instance.new("RemoteEvent")
	refreshBuyZonesRemote.Name = "RefreshBuyZones"
	refreshBuyZonesRemote.Parent = economyFolder
end

-- Remove CollectCash RemoteEvent - no longer needed since CashCollectionHandler handles everything
-- local collectCashRemote = economyFolder:FindFirstChild("CollectCash")
-- if not collectCashRemote then
-- 	collectCashRemote = Instance.new("RemoteEvent")
-- 	collectCashRemote.Name = "CollectCash"
-- 	collectCashRemote.Parent = economyFolder
-- end

-- Player data storage (session-based)
local playerMoney = {}
local sellCooldowns = {}
local buyCooldowns = {}
local buyZoneUsage = {} -- Track which buy zones have been used

local EconomyService = {}

-- Initialize player money when they join
local function onPlayerAdded(player)
	playerMoney[player] = PlayerStatsConfig.STARTING_MONEY
	sellCooldowns[player] = {}
	buyCooldowns[player] = {}
	buyZoneUsage[player] = {}
	
	-- Send initial money to client
	updateMoneyRemote:FireClient(player, playerMoney[player])
	
	if EconomyConfig.Debug.Enabled and EconomyConfig.Debug.LogMoneyChanges then
		print("[EconomyService] Player", player.Name, "joined with", playerMoney[player], "coins")
	end
end

-- Clean up player data when they leave
local function onPlayerRemoving(player)
	playerMoney[player] = nil
	sellCooldowns[player] = nil
	buyCooldowns[player] = nil
	buyZoneUsage[player] = nil
	
	if EconomyConfig.Debug.Enabled then
		print("[EconomyService] Cleaned up data for", player.Name)
	end
end

-- Get player's current money
function EconomyService.getMoney(player)
	return playerMoney[player] or 0
end

-- Add money to player (with validation)
function EconomyService.addMoney(player, amount)
	if not player or not amount or amount <= 0 then
		return false
	end
	
	playerMoney[player] = (playerMoney[player] or 0) + amount
	updateMoneyRemote:FireClient(player, playerMoney[player])
	
	if EconomyConfig.Debug.Enabled and EconomyConfig.Debug.LogMoneyChanges then
		print("[EconomyService]", player.Name, "gained", amount, "coins, total:", playerMoney[player])
	end
	
	return true
end

-- Remove money from player (with validation)
function EconomyService.removeMoney(player, amount)
	if not player or not amount or amount <= 0 then
		return false
	end
	
	local currentMoney = playerMoney[player] or 0
	if currentMoney < amount then
		return false -- Insufficient funds
	end
	
	playerMoney[player] = currentMoney - amount
	updateMoneyRemote:FireClient(player, playerMoney[player])
	
	if EconomyConfig.Debug.Enabled and EconomyConfig.Debug.LogMoneyChanges then
		print("[EconomyService]", player.Name, "spent", amount, "coins, remaining:", playerMoney[player])
	end
	
	return true
end

-- Check if player can afford an item
function EconomyService.canAfford(player, cost)
	return (playerMoney[player] or 0) >= cost
end

-- Handle selling items
local function onSellItem(player, item, sellZone)
	-- Validate player and item
	if not player or not item or not item.Parent then
		return
	end
	
	-- Check sell cooldown
	local currentTime = tick()
	local lastSell = sellCooldowns[player][sellZone] or 0
	if currentTime - lastSell < EconomyConfig.Zones.SellZone.TouchCooldown then
		return -- Still on cooldown
	end
	
	-- Determine item value based on CollectionService tags
	local itemValue = 0
	for tagName, value in pairs(EconomyConfig.SellableItems) do
		if CollectionService:HasTag(item, tagName) then
			itemValue = value
			break
		end
	end
	
	if itemValue <= 0 then
		return -- Item is not sellable
	end
	
	-- Award money and destroy item
	if EconomyService.addMoney(player, itemValue) then
		sellCooldowns[player][sellZone] = currentTime
		item:Destroy()
		
		if EconomyConfig.Debug.Enabled and EconomyConfig.Debug.LogSells then
			print("[EconomyService]", player.Name, "sold", item.Name, "for", itemValue, "coins")
		end
	end
end

local function onBuyItem(player, item)
	if not player or not item or not item.Parent then
		return
	end
	
	local currentTime = tick()
	local lastBuy = buyCooldowns[player][item] or 0
	if currentTime - lastBuy < EconomyConfig.Zones.BuyZone.InteractionCooldown then
		return
	end
	
	-- Find the item data in config
	local selectedItem = nil
	for _, itemData in pairs(EconomyConfig.BuyableItems) do
		if itemData.ItemName == item.Name then
			selectedItem = itemData
			break
		end
	end
	
	if not selectedItem then
		if EconomyConfig.Debug.Enabled then
			print("[EconomyService] Item", item.Name, "is not buyable")
		end
		return -- Item not in buyable list
	end
	
	-- Check if player can afford the item
	if not EconomyService.canAfford(player, selectedItem.Cost) then
		if EconomyConfig.Debug.Enabled then
			print("[EconomyService]", player.Name, "cannot afford", item.Name, "- costs", selectedItem.Cost, "have", playerMoney[player] or 0)
		end
		return -- Insufficient funds
	end
	
	-- Process the purchase (remove money and destroy the clicked item)
	if EconomyService.removeMoney(player, selectedItem.Cost) then
		buyCooldowns[player][item] = currentTime
		
		-- Destroy the purchased item
		item:Destroy()
		
		if EconomyConfig.Debug.Enabled and EconomyConfig.Debug.LogBuys then
			print("[EconomyService]", player.Name, "bought", selectedItem.ItemName, "for", selectedItem.Cost, "coins")
		end
	else
		if EconomyConfig.Debug.Enabled then
			print("[EconomyService] Failed to remove money for", player.Name)
		end
	end
end

-- Remove onCollectCash function - no longer needed since CashCollectionHandler handles everything
-- local function onCollectCash(player, cashValue, cashItem)
-- 	-- This function is now redundant - CashCollectionHandler does all the work
-- end

-- Initialize the service
function EconomyService.init()
	-- Connect player events
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	
	-- Connect remote events
	sellItemRemote.OnServerEvent:Connect(onSellItem)
	buyItemRemote.OnServerEvent:Connect(onBuyItem)
	-- collectCashRemote.OnServerEvent:Connect(onCollectCash) -- Removed - handled by CashCollectionHandler
	
	-- Initialize existing players (for hot reloading)
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	
	print("[EconomyService] Initialized successfully")
end

return EconomyService