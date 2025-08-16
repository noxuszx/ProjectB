-- src/server/economy/CashCollectionHandler.server.lua
-- Handles cash collection via proximity prompts

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Services
local SystemLoadMonitor = _G.SystemLoadMonitor or require(script.Parent.Parent.SystemLoadMonitor)
local EconomyService = require(script.Parent.Parent.services.EconomyService)
local CashPoolManager = require(script.Parent.CashPoolManager)
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)
local SoundPlayer = require(ReplicatedStorage.Shared.modules.SoundPlayer)

-- Track cash items and their prompts
local cashItems = {}
local cashPrompts = {}

local function createCashPrompt(cashItem)
	local existingPrompt = cashItem:FindFirstChild("CashPrompt")
	if existingPrompt then
		return existingPrompt
	end

	local cashValue = cashItem:GetAttribute("CashValue") or 0

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CashPrompt"
	prompt.ActionText = "Collect $" .. tostring(cashValue)
	prompt.ObjectText = "Cash"
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = cashItem

	cashPrompts[cashItem] = prompt

	if EconomyConfig.Debug.Enabled then
		print(
			"[CashCollectionHandler] Added proximity prompt to",
			cashItem.Name,
			"worth",
			cashValue
		)
	end

	return prompt
end

local function onCashCollected(promptObject, player)
	-- Only handle our own cash prompts
	if promptObject.Name ~= "CashPrompt" then
		return
	end

	local cashItem = promptObject.Parent
	if not cashItem or not cashItem:IsA("BasePart") then
		-- Prompt fired but no valid parent; ignore safely
		return
	end

	local cashValue = cashItem:GetAttribute("CashValue")
	if not cashValue or cashValue <= 0 then
		if EconomyConfig.Debug.Enabled then
			warn("[CashCollectionHandler] Cash item has no value or missing attribute:", cashItem.Name)
		end
		return
	end

if EconomyService.addMoney(player, cashValue) then
		-- Randomly pick one of the two collection sounds at the player's character
		pcall(function()
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") or SoundService
			local choices = {"economy.cash_small", "economy.cash_large"}
			local idx = math.random(1, #choices)
			SoundPlayer.playAt(choices[idx], root)
		end)
		if CashPoolManager.returnCashItem(cashItem) then
			cashItems[cashItem] = nil
			cashPrompts[cashItem] = nil

			if EconomyConfig.Debug.Enabled then
				print(
					"[CashCollectionHandler]",
					player.Name,
					"collected $" .. tostring(cashValue),
					"- item pooled"
				)
			end
		else
			-- Fallback to destroy if pooling failed
			cashItem:Destroy()
			cashItems[cashItem] = nil
			cashPrompts[cashItem] = nil

			if EconomyConfig.Debug.Enabled then
				print(
					"[CashCollectionHandler]",
					player.Name,
					"collected $" .. tostring(cashValue),
					"- item destroyed"
				)
			end
		end
	else
		warn("[CashCollectionHandler] Failed to give money to", player.Name)
	end
end

local function monitorWorkspaceChildAdded()
	workspace.ChildAdded:Connect(function(child)
		if child:IsA(
			"MeshPart"
		) and (child.Name == "cash5" or child.Name == "cash15" or child.Name == "cash25" or child.Name == "cash50") then
			-- Wait a frame to ensure attributes are set
			RunService.Heartbeat:Wait()

			-- Set up the cash item
			cashItems[child] = true
			createCashPrompt(child)

			-- Set up cleanup when cash item is removed
			child.AncestryChanged:Connect(function()
				if not child.Parent then
					cashItems[child] = nil
					cashPrompts[child] = nil
				end
			end)

			if EconomyConfig.Debug.Enabled then
				print(
					"[CashCollectionHandler] New cash item added:",
					child.Name
				)
			end
		end
	end)
end

-- Goldpile support: detection and prompt creation
local function isInSpawnedTreasure(inst)
	if not inst or not inst.Parent then return false end
	local current = inst
	while current and current ~= workspace do
		if current:IsA("Folder") and current.Name == "SpawnedTreasure" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isGoldpile(part)
	if not part or not part:IsA("MeshPart") then return false end
	if not isInSpawnedTreasure(part) then return false end
	local isAttr = part:GetAttribute("IsGoldpile")
	if isAttr ~= nil then
		return isAttr == true
	end
	local name = string.lower(part.Name or "")
	return string.sub(name, 1, 8) == "goldpile"
end

local function getGoldValue(part)
	local v = part:GetAttribute("GoldValue")
	if typeof(v) == "number" and v > 0 then return v end
	return 100
end

local function createGoldpilePrompt(goldpile)
	local existing = goldpile:FindFirstChild("GoldpilePrompt")
	if existing then return existing end
	local value = getGoldValue(goldpile)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GoldpilePrompt"
	prompt.ActionText = "Collect Gold (+" .. tostring(value) .. ")"
	prompt.ObjectText = "Gold Pile"
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration = 1.0
	prompt.RequiresLineOfSight = false
	prompt.Parent = goldpile
	return prompt
end

local goldpilesSetup = 0

local function setupGoldpileChild(child)
	if child:IsA("MeshPart") and isGoldpile(child) then
		createGoldpilePrompt(child)
		goldpilesSetup = goldpilesSetup + 1
		child.AncestryChanged:Connect(function()
			if not child.Parent then
				-- nothing to clean, weak refs
			end
		end)
	end
end

local function onGoldpilePromptTriggered(promptObject, player)
	if promptObject.Name ~= "GoldpilePrompt" then return end
	if not promptObject.Enabled then return end
	promptObject.Enabled = false
	local goldpile = promptObject.Parent
	if not goldpile or not goldpile:IsA("MeshPart") or not isGoldpile(goldpile) then
		return
	end
	local value = getGoldValue(goldpile)
	if value <= 0 then value = 100 end
	if EconomyService.addMoney(player, value) then
		goldpile:Destroy()
		if EconomyConfig.Debug.Enabled then
			print("[CashCollectionHandler]", player.Name, "collected goldpile for", value)
		end
	else
		if promptObject and promptObject.Parent then
			promptObject.Enabled = true
		end
		warn("[CashCollectionHandler] Failed to add money from goldpile for", player.Name)
	end
end

local function init()
	ProximityPromptService.PromptTriggered:Connect(onCashCollected)
	ProximityPromptService.PromptTriggered:Connect(onGoldpilePromptTriggered)
	monitorWorkspaceChildAdded()

	for _, child in pairs(workspace:GetChildren()) do
		if child:IsA(
			"MeshPart"
		) and (child.Name == "cash5" or child.Name == "cash15" or child.Name == "cash25" or child.Name == "cash50") then
			cashItems[child] = true
			createCashPrompt(child)

			-- Set up cleanup
			child.AncestryChanged:Connect(function()
				if not child.Parent then
					cashItems[child] = nil
					cashPrompts[child] = nil
				end
			end)
		end
	end

	-- Goldpiles: scan existing and watch for new ones under SpawnedTreasure
	local spawnedTreasure = workspace:FindFirstChild("SpawnedTreasure")
	if spawnedTreasure then
		for _, gp in ipairs(spawnedTreasure:GetChildren()) do
			setupGoldpileChild(gp)
		end
		spawnedTreasure.ChildAdded:Connect(setupGoldpileChild)
	end
	workspace.ChildAdded:Connect(function(child)
		if child:IsA("Folder") and child.Name == "SpawnedTreasure" then
			child.ChildAdded:Connect(setupGoldpileChild)
			for _, gp in ipairs(child:GetChildren()) do
				setupGoldpileChild(gp)
			end
		end
	end)

	CashPoolManager.prewarmPools()
	
	if EconomyConfig.Debug.Enabled and goldpilesSetup > 0 then
		print("[CashCollectionHandler] Setup " .. goldpilesSetup .. " goldpile prompts")
	end
	
	SystemLoadMonitor.reportSystemLoaded("EconomySystem")
end
init()
