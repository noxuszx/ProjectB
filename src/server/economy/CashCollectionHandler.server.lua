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

-- Create proximity prompt for cash item
local function createCashPrompt(cashItem)
	-- Check if prompt already exists
	local existingPrompt = cashItem:FindFirstChild("CashPrompt")
	if existingPrompt then
		return existingPrompt
	end
	
	local cashValue = cashItem:GetAttribute("CashValue") or 0
	
	-- Create proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CashPrompt"
	prompt.ActionText = "Collect $" .. tostring(cashValue)
	prompt.ObjectText = "Cash"
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = cashItem
	
	-- Store reference
	cashPrompts[cashItem] = prompt
	
	if EconomyConfig.Debug.Enabled then
		print("[CashCollectionHandler] Added proximity prompt to", cashItem.Name, "worth", cashValue)
	end
	
	return prompt
end

-- Handle cash collection
local function onCashCollected(promptObject, player)
	local cashItem = promptObject.Parent
	
	-- Validate cash item has value
	local cashValue = cashItem:GetAttribute("CashValue")
	if not cashValue or cashValue <= 0 then
		warn("[CashCollectionHandler] Cash item has no value:", cashItem.Name)
		return
	end
	
	-- Give money to player
	if EconomyService.addMoney(player, cashValue) then
		-- Return cash item to pool instead of destroying
		if CashPoolManager.returnCashItem(cashItem) then
			-- Clean up references
			cashItems[cashItem] = nil
			cashPrompts[cashItem] = nil
			
			if EconomyConfig.Debug.Enabled then
				print("[CashCollectionHandler]", player.Name, "collected $" .. tostring(cashValue), "- item pooled")
			end
		else
			-- Fallback to destroy if pooling failed
			cashItem:Destroy()
			cashItems[cashItem] = nil
			cashPrompts[cashItem] = nil
			
			if EconomyConfig.Debug.Enabled then
				print("[CashCollectionHandler]", player.Name, "collected $" .. tostring(cashValue), "- item destroyed")
			end
		end
	else
		warn("[CashCollectionHandler] Failed to give money to", player.Name)
	end
end

-- Monitor workspace for cash items
local function monitorWorkspaceForCash()
	-- Check for cash items every second
	spawn(function()
		while true do
			wait(1)
			
			-- Look for cash meshparts in workspace
			for _, child in pairs(workspace:GetChildren()) do
				if child:IsA("MeshPart") and 
				   (child.Name == "cash15" or child.Name == "cash25" or child.Name == "cash50") and
				   not cashItems[child] then
					
					-- New cash item found
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
						print("[CashCollectionHandler] Detected new cash item:", child.Name)
					end
				end
			end
		end
	end)
end

-- Alternative: Use ChildAdded for better performance (if workspace monitoring is too expensive)
local function monitorWorkspaceChildAdded()
	workspace.ChildAdded:Connect(function(child)
		-- Check if it's a cash meshpart
		if child:IsA("MeshPart") and 
		   (child.Name == "cash15" or child.Name == "cash25" or child.Name == "cash50") then
			
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
				print("[CashCollectionHandler] New cash item added:", child.Name)
			end
		end
	end)
end

-- Initialize the handler
local function init()
	-- Connect proximity prompt service
	ProximityPromptService.PromptTriggered:Connect(function(promptObject, player)
		-- Check if it's a cash prompt
		if promptObject.Name == "CashPrompt" then
			onCashCollected(promptObject, player)
		end
	end)
	
	-- Use the more efficient ChildAdded approach
	monitorWorkspaceChildAdded()
	
	-- Also check for existing cash items in workspace (in case script restarts)
	for _, child in pairs(workspace:GetChildren()) do
		if child:IsA("MeshPart") and 
		   (child.Name == "cash15" or child.Name == "cash25" or child.Name == "cash50") then
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
	
	-- Initialize cash pooling system
	CashPoolManager.prewarmPools()
	
	print("[CashCollectionHandler] Initialized successfully")
end

-- Start the handler
init()