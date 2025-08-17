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
local touchDebounce = {}

local function getZoneDebounceTable(zone)
	local t = touchDebounce[zone]
	if not t then
		t = setmetatable({}, { __mode = "k" })
		touchDebounce[zone] = t
	end
	return t
end

-- Resolve the topmost model for a touched part
local function resolveTopModel(part)
	if not part then return nil end
	return part:FindFirstAncestorOfClass("Model")
end


local function isSellableHumanoidCorpse(model)
	if not model or not model.Parent then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	local ragdolled = model:GetAttribute("Ragdolled")
	local isDead = model:GetAttribute("IsDead") or (hum and hum.Health <= 0) or false
	local ctype = model:GetAttribute("CreatureType")

	if game.Players:GetPlayerFromCharacter(model) then return false end
	if ctype and string.find(ctype, "Villager") then return false end
	if not (ragdolled or isDead) then return false end
	if not (ctype and EconomyConfig.CreatureSellValues[ctype]) then return false end
	return true
end

local function onSellZoneTouched(sellZone, hit)
	if EconomyConfig.Debug.Enabled then
		print("[SellZoneHandler] Something touched sell zone:", hit.Name, "from", hit.Parent and hit.Parent.Name or "nil")
	end

	local zoneDebounce = getZoneDebounceTable(sellZone)
	local now = os.clock()

	local model = resolveTopModel(hit)
	if model and isSellableHumanoidCorpse(model) then
		local last = zoneDebounce[model]
		if last and now - last < EconomyConfig.Performance.TouchDebounceTime then
			return
		end
		zoneDebounce[model] = now

		local ctype = model:GetAttribute("CreatureType")
		local itemValue = EconomyConfig.CreatureSellValues[ctype]
		local cashType = "cash" .. tostring(itemValue)

		if not MoneyFolder then
			warn("[SellZoneHandler] Money folder not available")
			return
		end
		local cashMeshpart = MoneyFolder:FindFirstChild(cashType)
		if not cashMeshpart then
			warn("[SellZoneHandler] Cash meshpart", cashType, "not found in Money folder")
			return
		end

		pcall(function()
			model:Destroy()
		end)

		local spawnPosition = sellZone.Position + Vector3.new(0, sellZone.Size.Y / 2 + 1, 0)
		local cashClone = CashPoolManager.getCashItem(cashType, spawnPosition)
		if not cashClone then
			cashClone = cashMeshpart:Clone()
			for _, child in pairs(cashClone:GetChildren()) do child:Destroy() end
			cashClone.Parent = workspace
			cashClone.Position = spawnPosition
		end
		cashClone:SetAttribute("CashValue", itemValue)
		pcall(function() SoundPlayer.playAt("economy.sell", sellZone) end)
		return
	end

	if model and not isSellableHumanoidCorpse(model) then
		local selectedValue, selectedCashType
		for tagName, value in pairs(EconomyConfig.SellableItems) do
			if CollectionService:HasTag(model, tagName) then
				selectedValue = value
				selectedCashType = "cash" .. tostring(value)
				break
			end
		end
		if selectedValue then
			local lastModel = zoneDebounce[model]
			if lastModel and now - lastModel < EconomyConfig.Performance.TouchDebounceTime then
				return
			end
			zoneDebounce[model] = now

			if not MoneyFolder then
				warn("[SellZoneHandler] Money folder not available")
				return
			end
			local cashMeshpart = MoneyFolder:FindFirstChild(selectedCashType)
			if not cashMeshpart then
				warn("[SellZoneHandler] Cash meshpart", selectedCashType, "not found in Money folder")
				return
			end

			pcall(function()
				model:Destroy()
			end)

			local spawnPosition = sellZone.Position + Vector3.new(0, sellZone.Size.Y / 2 + 1, 0)
			local cashClone = CashPoolManager.getCashItem(selectedCashType, spawnPosition)
			if not cashClone then
				cashClone = cashMeshpart:Clone()
				for _, child in pairs(cashClone:GetChildren()) do child:Destroy() end
				cashClone.Parent = workspace
				cashClone.Position = spawnPosition
			end
			cashClone:SetAttribute("CashValue", selectedValue)
			pcall(function() SoundPlayer.playAt("economy.sell", sellZone) end)
			return
		end
	end

	local item = hit
	if not item or not item:IsA("MeshPart") then
		if EconomyConfig.Debug.Enabled then
			print("[SellZoneHandler] Not a MeshPart and no sellable creature/model found:", hit.Name, hit.ClassName)
		end
		return
	end

	local lastTime = zoneDebounce[item]
	if lastTime and now - lastTime < EconomyConfig.Performance.TouchDebounceTime then
		return -- Still on debounce
	end
	zoneDebounce[item] = now

	local function checkSellableTags(obj)
		for tagName, value in pairs(EconomyConfig.SellableItems) do
			if CollectionService:HasTag(obj, tagName) then
				return true, value, "cash" .. tostring(value), tagName
			end
		end
		return false, 0, nil, nil
	end

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

	local spawnPosition = sellZone.Position + Vector3.new(0, sellZone.Size.Y / 2 + 1, 0)
	local cashClone = CashPoolManager.getCashItem(cashType, spawnPosition)
	if not cashClone then
		cashClone = cashMeshpart:Clone()
		for _, child in pairs(cashClone:GetChildren()) do child:Destroy() end
		cashClone.Parent = workspace
		cashClone.Position = spawnPosition
	end
	cashClone:SetAttribute("CashValue", itemValue)
	pcall(function() SoundPlayer.playAt("economy.sell", sellZone) end)
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
