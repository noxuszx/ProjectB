--[[
    Sack.client.lua
    Client script for the Sack tool - handles tool activation for retrieving items
]]--

local tool = script.Parent
repeat
	task.wait(0.1)
until _G.BackpackController

tool.Activated:Connect(function()
	_G.BackpackController.retrieveTopObject()
end)