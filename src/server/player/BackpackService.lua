--[[
    BackpackService.lua
    Server-side LIFO stack management for player backpacks
    Follows the sack system pattern with 10-slot capacity
]]
--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local CS_tags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local BackpackService = {}
local playerBackpacks = {}

local BACKPACK_HIDING_POSITION = Vector3.new(10000, -5000, 10000)

local MAX_SLOTS = 10
local COOLDOWN_TIME = 0.1

local function initializeBackpack(player)
	playerBackpacks[player.UserId] = {
		topIndex = 0,
		slots = {},
		lastAction = 0,
	}
end

local function cleanupBackpack(player)
	local backpack = playerBackpacks[player.UserId]
	if backpack then
		for i = 1, backpack.topIndex do
			local poolData = backpack.slots[i]
			if poolData and poolData.object and poolData.object.Parent then
				local randomOffset = Vector3.new(math.random(-10, 10), 5, math.random(-10, 10))

				if poolData.object:IsA("BasePart") then
					poolData.object.CFrame = CFrame.new(randomOffset)
					poolData.object.Transparency = poolData.originalTransparency or 0
					poolData.object.CanCollide = true
					poolData.object.CanTouch = true
				elseif poolData.object:IsA("Model") and poolData.object.PrimaryPart then
					poolData.object:SetPrimaryPartCFrame(CFrame.new(randomOffset))
					for _, part in pairs(poolData.object:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Transparency = poolData.originalTransparencies
									and poolData.originalTransparencies[part]
								or 0
							part.CanCollide = true
							part.CanTouch = true
						end
					end
				end
			end
		end
	end
	playerBackpacks[player.UserId] = nil
end

local function storeObjectInPool(object)
	if not object or not object.Parent then
		return nil
	end

	local originalPosition       = nil
	local originalTransparency   = nil
	local originalTransparencies = nil

	if object:IsA("BasePart") then
		originalPosition = object.CFrame
		originalTransparency = object.Transparency

		-- Hide the object in place
		object.Position = BACKPACK_HIDING_POSITION
		object.Transparency = 1
		object.CanCollide = false
		object.CanTouch = false
		object.Anchored = true -- Keep it stable while hidden
	elseif object:IsA("Model") and object.PrimaryPart then
		originalPosition = object.PrimaryPart.CFrame
		originalTransparencies = {}

		-- Store original transparencies and hide all parts
		for _, part in pairs(object:GetDescendants()) do
			if part:IsA("BasePart") then
				originalTransparencies[part] = part.Transparency
				part.Transparency = 1
				part.CanCollide = false
				part.CanTouch = false
				part.Anchored = true
			end
		end

		-- Move entire model to hiding position
		object:SetPrimaryPartCFrame(CFrame.new(BACKPACK_HIDING_POSITION))
	elseif object:IsA("Tool") then
		-- Tools don't need position storage, they get equipped
		originalPosition = CFrame.new(0, 0, 0)
		-- Tools get hidden differently - they just become non-interactive
		-- Move to hiding position
		if object.Handle then
			object.Handle.Position = BACKPACK_HIDING_POSITION
			object.Handle.Transparency = 1
			object.Handle.CanCollide = false
			object.Handle.CanTouch = false
		end
	end

	-- Object stays in workspace, just hidden

	return {
		object = object,
		originalPosition = originalPosition,
		originalTransparency = originalTransparency,
		originalTransparencies = originalTransparencies,
		name = object.Name,
		className = object.ClassName,
	}
end

-- Restore object from hidden state to world
local function restoreObjectFromPool(poolData, position)
	if not poolData or not poolData.object or not poolData.object.Parent then
		return nil
	end

	local object = poolData.object

	-- Restore object visibility and position (already in workspace)
	if object:IsA("BasePart") then
		object.CFrame = CFrame.new(position)
		object.Transparency = poolData.originalTransparency or 0
		object.CanCollide = true
		object.CanTouch = true
		object.Anchored = false -- Unanchor for normal physics
	elseif object:IsA("Model") and object.PrimaryPart then
		object:SetPrimaryPartCFrame(CFrame.new(position))

		-- Restore transparency for all parts in model
		for _, part in pairs(object:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = poolData.originalTransparencies and poolData.originalTransparencies[part] or 0
				part.CanCollide = true
				part.CanTouch = true
				part.Anchored = false -- Unanchor for normal physics
			end
		end
	elseif object:IsA("Tool") then
		-- Restore tool visibility
		if object.Handle then
			object.Handle.Position = position
			object.Handle.Transparency = 0
			object.Handle.CanCollide = true
			object.Handle.CanTouch = true
		end
	end

	-- Object was never moved from workspace, just made visible again

	return object
end

-- Get drop position in front of player
local function getDropPosition(player)
	local character = player.Character
	if not character or not character.PrimaryPart then
		return Vector3.new(0, 5, 0)
	end

	local humanoidRootPart = character.PrimaryPart
	local forwardDirection = humanoidRootPart.CFrame.LookVector

	-- Drop items further in front and at ground level for better placement
	local dropPosition = humanoidRootPart.Position + (forwardDirection * 5) + Vector3.new(0, 0.5, 0)

	return dropPosition
end

-- Check if object can be stored
function BackpackService.canStore(player, object)
	if not player or not object or not object.Parent then
		return false, "Invalid object"
	end

	local backpack = playerBackpacks[player.UserId]
	if not backpack then
		return false, "No backpack initialized"
	end

	if backpack.topIndex >= MAX_SLOTS then
		return false, "Backpack is full"
	end

	if not CS_tags.hasTag(object, CS_tags.STORABLE) then
		return false, "Object is not storable"
	end

	-- Extra safety: Don't allow storing alive creatures
	local humanoid = object:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return false, "Cannot store living creatures"
	end

	if os.clock() - backpack.lastAction < COOLDOWN_TIME then
		return false, "Please wait before storing again"
	end

	return true, "Can store"
end

-- Store object in backpack (LIFO push)
function BackpackService.storeObject(player, object)
	local canStore, reason = BackpackService.canStore(player, object)
	if not canStore then
		return false, reason
	end

	local backpack = playerBackpacks[player.UserId]
	local poolData = storeObjectInPool(object)

	if not poolData then
		return false, "Could not store object in pool"
	end

	-- Push to stack
	backpack.topIndex = backpack.topIndex + 1
	backpack.slots[backpack.topIndex] = poolData
	backpack.lastAction = os.clock()

	return true, "Stored " .. poolData.name, backpack
end

-- Retrieve object from backpack (LIFO pop)
function BackpackService.retrieveObject(player)
	local backpack = playerBackpacks[player.UserId]
	if not backpack then
		return false, "No backpack initialized"
	end

	if backpack.topIndex <= 0 then
		return false, "Backpack is empty"
	end

	if os.clock() - backpack.lastAction < COOLDOWN_TIME then
		return false, "Please wait before retrieving again"
	end

	-- Pop from stack
	local poolData = backpack.slots[backpack.topIndex]
	backpack.slots[backpack.topIndex] = nil
	backpack.topIndex = backpack.topIndex - 1
	backpack.lastAction = os.clock()

	-- Restore object from pool to world
	local dropPosition = getDropPosition(player)
	local restoredObject = restoreObjectFromPool(poolData, dropPosition)

	if restoredObject then
		return true, "Retrieved " .. poolData.name, backpack, restoredObject
	else
		-- If restoration failed, restore the stack
		backpack.topIndex = backpack.topIndex + 1
		backpack.slots[backpack.topIndex] = poolData
		return false, "Could not restore object from pool"
	end
end

-- Get backpack contents for UI sync
function BackpackService.getBackpackContents(player)
	local backpack = playerBackpacks[player.UserId]
	if not backpack then
		return {}
	end

	-- Return slots in display order (top of stack first)
	-- Convert poolData to UI-friendly format
	local contents = {}
	for i = backpack.topIndex, 1, -1 do
		local poolData = backpack.slots[i]
		if poolData then
			table.insert(contents, {
				Name = poolData.name,
				ClassName = poolData.className,
			})
		end
	end

	return contents
end

-- Get backpack stats
function BackpackService.getBackpackStats(player)
	local backpack = playerBackpacks[player.UserId]
	if not backpack then
		return 0, MAX_SLOTS
	end

	return backpack.topIndex, MAX_SLOTS
end

-- Event handlers
Players.PlayerAdded:Connect(initializeBackpack)
Players.PlayerRemoving:Connect(cleanupBackpack)

-- Initialize existing players
for _, player in pairs(Players:GetPlayers()) do
	initializeBackpack(player)
end

return BackpackService
