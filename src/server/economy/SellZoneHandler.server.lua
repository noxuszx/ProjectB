-- src/server/economy/SellZoneHandler.server.lua
-- Handles sell zone detection and processing using CollectionService

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Services
local CashPoolManager = require(script.Parent.CashPoolManager)
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local SoundPlayer = require(ReplicatedStorage.Shared.modules.SoundPlayer)

-- Cache Money folder at file scope
local MoneyFolder = ReplicatedStorage:FindFirstChild("Money")
if not MoneyFolder then
	warn("[SellZoneHandler] Money folder not found in ReplicatedStorage")
end

-- Tracking for debouncing - instance-keyed weak tables
local touchDebounce = {} -- [sellZone] = weak-key table of [item] = lastTime

local function getZoneDebounceTable(zone)
	local t = touchDebounce[zone]
	if not t then
		t = setmetatable({}, { __mode = "k" }) -- weak keys for auto-cleanup
		touchDebounce[zone] = t
	end
	return t
end

-- Handle when something touches a sell zone
local function onSellZoneTouched(sellZone, hit)
	if EconomyConfig.Debug.Enabled then
		print(
			"[SellZoneHandler] Something touched sell zone:",
			hit.Name,
			"from",
			hit.Parent and hit.Parent.Name or "nil"
		)
	end

	-- Simplified: only handle MeshPart sellables
	local item = hit
	if not item or not item:IsA("MeshPart") then
		if EconomyConfig.Debug.Enabled then
			print("[SellZoneHandler] Hit object is not a MeshPart:", hit.Name, hit.ClassName)
		end
		return
	end

	-- Debounce check using instance-keyed weak tables
	local zoneDebounce = getZoneDebounceTable(sellZone)
	local lastTime = zoneDebounce[item]
	local currentTime = os.clock()

	if lastTime and currentTime - lastTime < EconomyConfig.Performance.TouchDebounceTime then
		return -- Still on debounce
	end

	zoneDebounce[item] = currentTime

	-- Validate that the item is sellable and get cash type
	local function checkSellableTags(obj)
		for tagName, value in pairs(EconomyConfig.SellableItems) do
			if CollectionService:HasTag(obj, tagName) then
				return true, value, "cash" .. tostring(value), tagName
			end
		end
		return false, 0, nil, nil
	end

	-- Check the item itself first
	if EconomyConfig.Debug.Enabled then
		print("[SellZoneHandler] Checking item:", item.Name, "ClassName:", item.ClassName)
		print("[SellZoneHandler] Item tags:", table.concat(CollectionService:GetTags(item), ", "))
	end

	local isSellable, itemValue, cashType, tagName = checkSellableTags(item)

	if not isSellable then
		if EconomyConfig.Debug.Enabled then
			print("[SellZoneHandler] Item", item.Name, "is not sellable - no valid tags found")
		end
		return
	end

	if EconomyConfig.Debug.Enabled then
		print("[SellZoneHandler] Found sellable item:", item.Name, "value:", itemValue, "tag:", tagName)
	end

	-- Use cached Money folder
	if not MoneyFolder then
		warn("[SellZoneHandler] Money folder not available")
		return
	end

	local cashMeshpart = MoneyFolder:FindFirstChild(cashType)
	if not cashMeshpart then
		warn("[SellZoneHandler] Cash meshpart", cashType, "not found in Money folder")
		return
	end

	item:Destroy()

	-- Spawn cash 1 stud above the sell zone
	local sellZonePosition = sellZone.Position
	local spawnPosition = sellZonePosition + Vector3.new(0, sellZone.Size.Y / 2 + 1, 0)
	local cashClone = CashPoolManager.getCashItem(cashType, spawnPosition)

	if not cashClone then
		cashClone = cashMeshpart:Clone()
		for _, child in pairs(cashClone:GetChildren()) do
			child:Destroy()
		end
		cashClone.Parent = workspace
		cashClone.Position = spawnPosition
	end
cashClone:SetAttribute("CashValue", itemValue)

-- Play economy sell sound at the zone for feedback
pcall(function()
    SoundPlayer.playAt("economy.sell", sellZone)
end)
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
			-- Clean up debounce table for this zone
			touchDebounce[sellZone] = nil
		end
	end)
end

local function onSellZoneAdded(sellZone)
	setupSellZone(sellZone)
end

local function onSellZoneRemoved(sellZone)
	-- Clean up debounce table for removed zone
	touchDebounce[sellZone] = nil
end

-- Initialize the handler
local function init()
	local sellZones = CollectionServiceTags.getLiveTagged(CollectionServiceTags.SELL_ZONE)

	if EconomyConfig.Debug.Enabled then
		print("[SellZoneHandler] Found", #sellZones, "sell zones during initialization")
		for i, zone in pairs(sellZones) do
			print("  Sell Zone", i, ":", zone.Name, zone.ClassName)
		end
	end

	for _, zone in pairs(sellZones) do
		setupSellZone(zone)
	end

	CollectionService:GetInstanceAddedSignal(CollectionServiceTags.SELL_ZONE):Connect(onSellZoneAdded)
	CollectionService:GetInstanceRemovedSignal(CollectionServiceTags.SELL_ZONE):Connect(onSellZoneRemoved)

	task.spawn(function()
		while true do
			task.wait(30)
			local currentTime = os.clock()
			-- Clean up old debounce entries across all zones
			for zone, zoneTable in pairs(touchDebounce) do
				for item, time in pairs(zoneTable) do
					if currentTime - time > 10 then
						zoneTable[item] = nil
					end
				end
			end
		end
	end)
end

-- Start the handler
init()
