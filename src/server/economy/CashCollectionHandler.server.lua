-- src/server/economy/CashCollectionHandler.server.lua
-- Handles cash collection via proximity prompts

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

-- Services
local EconomyService = require(script.Parent.Parent.services.EconomyService)
local CashPoolManager = require(script.Parent.CashPoolManager)
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)

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
	local cashItem = promptObject.Parent

	local cashValue = cashItem:GetAttribute("CashValue")
	if not cashValue or cashValue <= 0 then
		warn("[CashCollectionHandler] Cash item has no value:", cashItem.Name)
		return
	end

	if EconomyService.addMoney(player, cashValue) then
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
		) and (child.Name == "cash15" or child.Name == "cash25" or child.Name == "cash50") then
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

local function init()
	ProximityPromptService.PromptTriggered:Connect(onCashCollected)
	monitorWorkspaceChildAdded()

	for _, child in pairs(workspace:GetChildren()) do
		if child:IsA(
			"MeshPart"
		) and (child.Name == "cash15" or child.Name == "cash25" or child.Name == "cash50") then
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

	CashPoolManager.prewarmPools()
	print("[CashCollectionHandler] Initialized successfully")
end
init()
