-- src/server/services/EconomyService.lua
-- Core economy system service for managing player money, selling, and buying

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- Configuration
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)
local PlayerStatsConfig = require(ReplicatedStorage.Shared.config.PlayerStatsConfig)

-- Get RemoteEvents (defined in default.project.json)
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local economyFolder = remotesFolder:WaitForChild("Economy")
local updateMoneyRemote = economyFolder:WaitForChild("UpdateMoney")
local sellItemRemote = economyFolder:WaitForChild("SellItem")
local buyItemRemote = economyFolder:WaitForChild("BuyItem")
local refreshBuyZonesRemote = economyFolder:WaitForChild("RefreshBuyZones")


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
	local currentTime = os.clock()
	local lastSell = sellCooldowns[player][sellZone] or 0
	if currentTime - lastSell < EconomyConfig.Zones.SellZone.TouchCooldown then
		return
	end
	
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
	
	local currentTime = os.clock()
	local lastBuy = buyCooldowns[player][item] or 0
	if currentTime - lastBuy < EconomyConfig.Zones.BuyZone.InteractionCooldown then
		return
	end
	
	local selectedItem = nil
	-- Find the item data in config
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

function EconomyService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	
	sellItemRemote.OnServerEvent:Connect(onSellItem)
	buyItemRemote.OnServerEvent:Connect(onBuyItem)
	
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	
	if _G.SystemLoadMonitor then
		_G.SystemLoadMonitor.reportSystemLoaded("EconomyService")
	end
end

return EconomyService