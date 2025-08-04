-- src/server/economy/SellZoneHandler.server.lua
-- Handles sell zone detection and processing using CollectionService

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Services
local EconomyService = require(script.Parent.Parent.services.EconomyService)
local CashPoolManager = require(script.Parent.CashPoolManager)
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)

-- RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Economy")
local sellItemRemote = remotes:WaitForChild("SellItem")

-- Tracking for debouncing
local touchDebounce = {}

-- Handle when something touches a sell zone
local function onSellZoneTouched(sellZone, hit)
	print("[SellZoneHandler] SELL_ZONE", sellZone.Name, "was touched by", hit.Name)
	
	-- Find the item that touched the sell zone
	local item = hit.Parent
	if not item then
		return
	end
	
	-- Guard against trying to destroy workspace (happens with ungrouped parts)
	if item == workspace then
		return -- Ignore lone parts / terrain hits
	end
	
	print("[SellZoneHandler] Checking if", item.Name, "is sellable")
	
	-- Debounce check
	local debounceKey = tostring(item) .. "_" .. tostring(sellZone)
	local currentTime = tick()
	
	if touchDebounce[debounceKey] and currentTime - touchDebounce[debounceKey] < EconomyConfig.Performance.TouchDebounceTime then
		return -- Still on debounce
	end
	
	touchDebounce[debounceKey] = currentTime
	
	-- Validate that the item is sellable and get cash type
	-- Check both the item itself and its children for sellable tags
	local isSellable = false
	local itemValue = 0
	local cashType = nil
	
	-- Function to check tags on an object
	local function checkSellableTags(obj)
		for tagName, value in pairs(EconomyConfig.SellableItems) do
			if CollectionService:HasTag(obj, tagName) then
				return true, value, "cash" .. tostring(value), tagName
			end
		end
		return false, 0, nil, nil
	end
	
	-- Check the item itself first
	isSellable, itemValue, cashType, tagName = checkSellableTags(item)
	
	-- If item isn't tagged, check its children (for Models with tagged MeshParts)
	if not isSellable and item:IsA("Model") then
		for _, child in pairs(item:GetChildren()) do
			if child:IsA("MeshPart") then
				isSellable, itemValue, cashType, tagName = checkSellableTags(child)
				if isSellable then
					print("[SellZoneHandler] Child", child.Name, "has tag", tagName, "worth", itemValue, "coins")
					break
				end
			end
		end
	else
		if isSellable then
			print("[SellZoneHandler] Item", item.Name, "has tag", tagName, "worth", itemValue, "coins")
		end
	end
	
	if not isSellable then
		print("[SellZoneHandler] Item", item.Name, "has no sellable tags")
		return
	end
	
	-- Find the cash meshpart in ReplicatedStorage.Money
	local moneyFolder = ReplicatedStorage:FindFirstChild("Money")
	if not moneyFolder then
		warn("[SellZoneHandler] Money folder not found in ReplicatedStorage")
		return
	end
	
	local cashMeshpart = moneyFolder:FindFirstChild(cashType)
	if not cashMeshpart then
		warn("[SellZoneHandler] Cash meshpart", cashType, "not found in Money folder")
		return
	end
	
	-- Get the item's position before destroying it
	local itemPosition = nil
	
	if item:IsA("Model") then
		-- For Models, use PrimaryPart position or first Part position
		if item.PrimaryPart then
			itemPosition = item.PrimaryPart.Position
		else
			local firstPart = item:FindFirstChildOfClass("Part") or item:FindFirstChildOfClass("MeshPart")
			if firstPart then
				itemPosition = firstPart.Position
			end
		end
	elseif item:IsA("Part") or item:IsA("MeshPart") then
		-- For Parts/MeshParts, use their position directly
		itemPosition = item.Position
	end
	
	if not itemPosition then
		warn("[SellZoneHandler] Could not determine position for item:", item.Name)
		return
	end
	
	-- Destroy the sellable item
	item:Destroy()
	
	-- Try to get cash from pool first
	local spawnPosition = itemPosition + Vector3.new(0, 1, 0)
	local cashClone = CashPoolManager.getCashItem(cashType, spawnPosition)
	
	if not cashClone then
		-- Pool is empty, create new cash item
		local cashMeshpart = moneyFolder:FindFirstChild(cashType)
		if cashMeshpart then
			cashClone = cashMeshpart:Clone()
			
			-- STRIP ALL DESCENDANTS to prevent Write Marshalled (Scripts, ProximityPrompts, etc.)
			for _, child in pairs(cashClone:GetChildren()) do
				child:Destroy()
			end
			
			cashClone.Parent = workspace
			cashClone.Position = spawnPosition
			
			print("[SellZoneHandler] Created new stripped", cashType, "worth", itemValue, "coins at", itemPosition)
		else
			warn("[SellZoneHandler] Could not spawn cash - meshpart not found:", cashType)
			return
		end
	else
		print("[SellZoneHandler] Used pooled", cashType, "worth", itemValue, "coins at", itemPosition)
	end
	
	-- Store the cash value as an attribute for collection
	cashClone:SetAttribute("CashValue", itemValue)
end

-- Set up touch detection for sell zones
local function setupSellZone(sellZone)
	print("[SellZoneHandler] Setting up touch detection for sell zone:", sellZone.Name)
	
	if not sellZone:IsA("Part") and not sellZone:IsA("MeshPart") then
		warn("[SellZoneHandler] Sell zone", sellZone.Name, "is not a Part or MeshPart")
		return
	end
	
	-- Connect touch event to the sell zone
	local connection = sellZone.Touched:Connect(function(hit)
		onSellZoneTouched(sellZone, hit)
	end)
	
	-- Clean up connection when sell zone is removed
	sellZone.AncestryChanged:Connect(function()
		if not sellZone.Parent then
			connection:Disconnect()
			-- Clean up debounce entries for this sell zone
			for key, _ in pairs(touchDebounce) do
				if string.find(key, tostring(sellZone)) then
					touchDebounce[key] = nil
				end
			end
		end
	end)
	
	print("[SellZoneHandler] Connected touch events to sell zone:", sellZone.Name)
end

-- Monitor for new sell zones
local function onSellZoneAdded(sellZone)
	print("[SellZoneHandler] New sell zone detected:", sellZone.Name)
	setupSellZone(sellZone)
end

local function onSellZoneRemoved(sellZone)
	print("[SellZoneHandler] Sell zone removed:", sellZone.Name)
	-- Clean up any debounce entries for this sell zone
	for key, _ in pairs(touchDebounce) do
		if string.find(key, tostring(sellZone)) then
			touchDebounce[key] = nil
		end
	end
end

-- Initialize the handler
local function init()
	-- Set up existing SELL_ZONE parts
	local sellZones = CollectionService:GetTagged("SELL_ZONE")
	print("[SellZoneHandler] Found", #sellZones, "SELL_ZONE tagged parts:")
	
	for _, zone in pairs(sellZones) do
		print("  - SELL_ZONE:", zone.Name, "(" .. zone.ClassName .. ")")
		setupSellZone(zone)
	end
	
	-- Monitor for new/removed sell zones
	CollectionService:GetInstanceAddedSignal("SELL_ZONE"):Connect(onSellZoneAdded)
	CollectionService:GetInstanceRemovedSignal("SELL_ZONE"):Connect(onSellZoneRemoved)
	
	-- Periodic cleanup of old debounce entries
	spawn(function()
		while true do
			wait(30) -- Clean up every 30 seconds
			local currentTime = tick()
			for key, time in pairs(touchDebounce) do
				if currentTime - time > 10 then -- Remove entries older than 10 seconds
					touchDebounce[key] = nil
				end
			end
		end
	end)
	
	print("[SellZoneHandler] Initialized successfully - listening on", #sellZones, "sell zones")
end

-- Start the handler
init()