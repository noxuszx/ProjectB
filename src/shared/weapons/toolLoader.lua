--[[
	toolLoader.lua
	Universal tool loader script for all weapons
	This script should be placed inside each Tool object as a LocalScript
	It acts as a bridge between the Tool instance and the weaponController module
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for weapon controller to be available
local weaponController = require(ReplicatedStorage.Shared.weapons.weaponController)

-- Get the tool this script is inside
local tool = script.Parent

-- Ensure this is actually a Tool
if not tool:IsA("Tool") then
	warn("[ToolLoader] Script must be placed inside a Tool object")
	return
end

-- Initialize weapon controller when player joins
local player = Players.LocalPlayer
if player then
	-- Initialize the weapon controller
	weaponController.init()
end

-- Connect tool events
tool.Equipped:Connect(function()
	print("[ToolLoader] Equipping weapon: " .. tool.Name)
	weaponController.equip(tool)
end)

tool.Unequipped:Connect(function()
	print("[ToolLoader] Unequipping weapon: " .. tool.Name)
	weaponController.unequip(tool)
end)

print("[ToolLoader] Tool loader initialized for: " .. tool.Name)
