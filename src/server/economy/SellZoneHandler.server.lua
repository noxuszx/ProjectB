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
	
	-- Find the item that touched the sell zone
	local item = hit.Parent
	if not item then
		return
	end
	
	-- Guard against trying to destroy workspace (happens with ungrouped parts)
	if item == workspace then
		return -- Ignore lone parts / terrain hits
	end
	
	
	-- Debounce check
	local debounceKey = tostring(item) .. "_" .. tostring(sellZone)
	local currentTime = os.clock()
	
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
					break
				end
			end
		end
	else
		if isSellable then
		end
	end
	
	if not isSellable then
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
		itemPosition = item.Position
	end
	
	if not itemPosition then
		warn("[SellZoneHandler] Could not determine position for item:", item.Name)
		return
	end
	
	item:Destroy()
	
	local spawnPosition = itemPosition + Vector3.new(0, 1, 0)
	local cashClone = CashPoolManager.getCashItem(cashType, spawnPosition)
	
	if not cashClone then
		local cashMeshpart = moneyFolder:FindFirstChild(cashType)
		if cashMeshpart then
			cashClone = cashMeshpart:Clone()
			
			for _, child in pairs(cashClone:GetChildren()) do
				child:Destroy()
			end
			
			cashClone.Parent = workspace
			cashClone.Position = spawnPosition
			
		else
			warn("[SellZoneHandler] Could not spawn cash - meshpart not found:", cashType)
			return
		end
	else
	end
	cashClone:SetAttribute("CashValue", itemValue)
end

local function setupSellZone(sellZone)
	
	if not sellZone:IsA("Part") and not sellZone:IsA("MeshPart") then
		warn("[SellZoneHandler] Sell zone", sellZone.Name, "is not a Part or MeshPart")
		return
	end
	
	local connection = sellZone.Touched:Connect(function(hit)
		onSellZoneTouched(sellZone, hit)
	end)
	
	sellZone.AncestryChanged:Connect(function()
		if not sellZone.Parent then
			connection:Disconnect()
			for key, _ in pairs(touchDebounce) do
				if string.find(key, tostring(sellZone)) then
					touchDebounce[key] = nil
				end
			end
		end
	end)
	
end


local function onSellZoneAdded(sellZone)
	setupSellZone(sellZone)
end

local function onSellZoneRemoved(sellZone)
	for key, _ in pairs(touchDebounce) do
		if string.find(key, tostring(sellZone)) then
			touchDebounce[key] = nil
		end
	end
end

-- Initialize the handler
local function init()
	local sellZones = CollectionService:GetTagged("SELL_ZONE")
	
	for _, zone in pairs(sellZones) do
		setupSellZone(zone)
	end
	
	CollectionService:GetInstanceAddedSignal("SELL_ZONE"):Connect(onSellZoneAdded)
	CollectionService:GetInstanceRemovedSignal("SELL_ZONE"):Connect(onSellZoneRemoved)
	
	task.spawn(function()
		while true do
			task.wait(30)
			local currentTime = os.clock()
			for key, time in pairs(touchDebounce) do
				if currentTime - time > 10 then
					touchDebounce[key] = nil
				end
			end
		end
	end)
	
end

-- Start the handler
init()