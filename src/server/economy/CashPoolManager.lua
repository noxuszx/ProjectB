-- src/server/economy/CashPoolManager.lua
-- Object pooling system for cash items to prevent Write Marshalled frame drops

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Configuration
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)

-- No need for a separate folder - we'll hide items in workspace instead
-- This avoids destroy packets and makes restoration just a property change
local POOL_HIDING_POSITION = Vector3.new(0, -5000, 0) -- Far below the map

-- Pool storage for each cash type
local cashPools = {
	cash5 = {},
	cash15 = {},
	cash25 = {},
	cash50 = {}
}

-- Pool limits to prevent memory bloat
local POOL_LIMITS = {
	cash5 = 25,
	cash15 = 20,
	cash25 = 15,
	cash50 = 10
}

local CashPoolManager = {}

-- Get a cash item from pool or create new one
function CashPoolManager.getCashItem(cashType, position)
	local pool = cashPools[cashType]
	
	-- Try to reuse from pool first
	if #pool > 0 then
		local cashItem = table.remove(pool)
		
		-- Restore the item from hidden state
		if EconomyConfig.Debug.Enabled then
			print("[CashPoolManager] Restoring", cashType, "from", cashItem.Position, "to", position)
		end
		
		cashItem.Position = position
		cashItem.Transparency = 0
		cashItem.CanCollide = true
		cashItem.CanTouch = true
		cashItem.Anchored = false -- Unanchor so players can collect it
		-- Item already in workspace, no Parent change needed
		
		-- Create a BindableEvent to notify CashCollectionHandler
		-- We can't require the server script directly, so we'll create the prompt here
		local function createCashPrompt(item)
			-- Check if prompt already exists
			local existingPrompt = item:FindFirstChild("CashPrompt")
			if existingPrompt then
				return existingPrompt
			end
			
			local cashValue = item:GetAttribute("CashValue") or 0
			
			-- Create proximity prompt
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "CashPrompt"
			prompt.ActionText = "Collect $" .. tostring(cashValue)
			prompt.ObjectText = "Cash"
			prompt.MaxActivationDistance = 8
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.Parent = item
			
			if EconomyConfig.Debug.Enabled then
				print("[CashPoolManager] Added proximity prompt to restored", item.Name)
			end
			
			return prompt
		end
		
		-- Create proximity prompt for the restored item
		createCashPrompt(cashItem)
		
		if EconomyConfig.Debug.Enabled then
			print("[CashPoolManager] Restored", cashType, "to position:", cashItem.Position, "transparency:", cashItem.Transparency)
		end
		
		if EconomyConfig.Debug.Enabled then
			print("[CashPoolManager] Reused", cashType, "from pool, pool size:", #pool)
		end
		
		return cashItem
	end
	
	-- No pooled items available, would need to create new one
	-- For now, return nil to indicate pool is empty
	if EconomyConfig.Debug.Enabled then
		print("[CashPoolManager] Pool empty for", cashType, "- need to create new item")
	end
	
	return nil
end

-- Return a cash item to the pool instead of destroying it
function CashPoolManager.returnCashItem(cashItem)
	if not cashItem or not cashItem.Parent then
		if EconomyConfig.Debug.Enabled then
			print("[CashPoolManager] ERROR: Invalid cash item or no parent")
		end
		return false
	end
	
	local cashType = cashItem.Name
	if EconomyConfig.Debug.Enabled then
		print("[CashPoolManager] Attempting to pool:", cashType, "- ClassName:", cashItem.ClassName)
	end
	
	local pool = cashPools[cashType]
	if not pool then
		if EconomyConfig.Debug.Enabled then
			print("[CashPoolManager] ERROR: No pool found for", cashType)
		end
		return false
	end
	
	local limit = POOL_LIMITS[cashType]
	if not limit then
		if EconomyConfig.Debug.Enabled then
			print("[CashPoolManager] ERROR: No limit found for", cashType)
		end
		return false
	end
	
	if EconomyConfig.Debug.Enabled then
		print("[CashPoolManager] Current pool size:", #pool, "/ limit:", limit)
	end
	
	-- Check if pool has space
	if #pool >= limit then
		cashItem:Destroy()
		
		if EconomyConfig.Debug.Enabled then
			print("[CashPoolManager] Pool full for", cashType, "- destroyed item")
		end
		
		return true
	end
	
	-- Hide the item in workspace instead of moving to ServerStorage
	if EconomyConfig.Debug.Enabled then
		print("[CashPoolManager] Hiding", cashType, "in workspace for pooling")
	end
	
	cashItem.Position = POOL_HIDING_POSITION
	cashItem.Transparency = 1
	cashItem.CanCollide = false
	cashItem.CanTouch = false
	cashItem.Anchored = true -- Ensure it stays hidden
	
	-- Clear network ownership to remove from replication priority list
	pcall(function() cashItem:SetNetworkOwner(nil) end)
	
	-- Keep in workspace to avoid destroy packets
	
	-- Remove proximity prompt if it exists
	local prompt = cashItem:FindFirstChild("CashPrompt")
	if prompt then
		prompt:Destroy()
		if EconomyConfig.Debug.Enabled then
			print("[CashPoolManager] Removed proximity prompt from", cashType)
		end
	end
	
	-- Add to pool
	table.insert(pool, cashItem)
	
	if EconomyConfig.Debug.Enabled then
		print("[CashPoolManager] Returned", cashType, "to pool, pool size:", #pool, "- Hidden in workspace")
	end
	
	return true
end

-- Pre-warm the pools with some items (call during server startup)
function CashPoolManager.prewarmPools()
	-- TODO: Create one of each cash type and pool them to eliminate first-spawn Write Marshalled
	-- This would require access to the cash meshparts from ReplicatedStorage.Money
	-- For now, pools will fill naturally as items are collected
	
	if EconomyConfig.Debug.Enabled then
		print("[CashPoolManager] Pools initialized - items will be pooled as collected")
	end
end

-- Get pool statistics for debugging
function CashPoolManager.getPoolStats()
	local stats = {}
	
	for cashType, pool in pairs(cashPools) do
		stats[cashType] = {
			pooled = #pool,
			limit = POOL_LIMITS[cashType]
		}
	end
	
	return stats
end

-- Clear all pools (for cleanup)
function CashPoolManager.clearPools()
	for cashType, pool in pairs(cashPools) do
		for _, item in pairs(pool) do
			if item and item.Parent then
				item:Destroy()
			end
		end
		cashPools[cashType] = {}
	end
	
	if EconomyConfig.Debug.Enabled then
		print("[CashPoolManager] All pools cleared")
	end
end

return CashPoolManager