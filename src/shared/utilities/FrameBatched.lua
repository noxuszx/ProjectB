--[[
	FrameBatched.lua
	Generic frame-budgeted processing utility
	Prevents server hitches by spreading heavy operations across multiple frames
]]--

local RunService = game:GetService("RunService")

local FrameBatched = {}

-- Process a list in batches, yielding every frame
-- @param list: Array to process
-- @param perFrame: Number of items to process per frame
-- @param fn: Function to call on each item
function FrameBatched.run(list, perFrame, fn)
	if not list or #list == 0 then
		return
	end
	
	perFrame = perFrame or 1
	local i = 1
	
	while i <= #list do
		-- Process up to perFrame items this frame
		for n = 1, math.min(perFrame, #list - i + 1) do
			fn(list[i])
			i = i + 1
		end
		
		-- Yield to next frame if there are more items to process
		if i <= #list then
			RunService.Heartbeat:Wait()
		end
	end
end

-- Process an iterator in batches, yielding every frame
-- @param iterator: Iterator function or iterable
-- @param perFrame: Number of items to process per frame
-- @param fn: Function to call on each item
function FrameBatched.wrap(iterator, perFrame, fn)
	perFrame = perFrame or 1
	local count = 0
	
	for value in iterator do
		fn(value)
		count = count + 1
		
		-- Yield after processing perFrame items
		if count >= perFrame then
			RunService.Heartbeat:Wait()
			count = 0
		end
	end
end

-- Create an iterator from nested loops for chunk coordinates
-- @param minX, maxX, minZ, maxZ: Coordinate bounds
-- @return iterator function that yields {x, z} coordinates
function FrameBatched.chunkIterator(minX, maxX, minZ, maxZ)
	local x, z = minX, minZ
	
	return function()
		if x > maxX then
			return nil -- End iteration
		end
		
		local current = {x = x, z = z}
		
		-- Advance to next coordinate
		z = z + 1
		if z > maxZ then
			z = minZ
			x = x + 1
		end
		
		return current
	end
end

-- Utility to get appropriate batch size based on device performance
-- @param baseBatchSize: Default batch size
-- @param mobileFactor: Multiplier for mobile devices (default 0.5)
-- @return adjusted batch size
function FrameBatched.getDeviceAdjustedBatchSize(baseBatchSize, mobileFactor)
	local UserInputService = game:GetService("UserInputService")
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	
	mobileFactor = mobileFactor or 0.5
	
	if isMobile then
		return math.max(1, math.floor(baseBatchSize * mobileFactor))
	else
		return baseBatchSize
	end
end

return FrameBatched