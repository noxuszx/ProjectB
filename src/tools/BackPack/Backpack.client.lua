--[[
    Sack.client.lua
    Client script for the Sack tool - handles tool activation for retrieving items
]]--

local tool = script.Parent
repeat
	task.wait(0.1)
until _G.BackpackController

-- Deactivate mouse click retrieval; F key handles store/unstore on PC
-- Leaving Activated connected to a no-op to avoid unexpected tool behavior
tool.Activated:Connect(function()
	-- no-op
end)
