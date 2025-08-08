--[[
    Sack.client.lua
    Client script for the Sack tool - handles tool activation for retrieving items
]]--

local tool = script.Parent

-- Wait for BackpackController to be available
repeat
	task.wait(0.1)
until _G.BackpackController

tool.Activated:Connect(function()
	-- Retrieve top item from backpack
	_G.BackpackController.retrieveTopObject()
end)