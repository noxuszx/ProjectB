-- Simple medkit healing script
-- Place this script inside your medkit tool

local Tool = script.Parent
local HEAL_AMOUNT = 35
local Players = game:GetService("Players")
local PlayerStatsManager = require(game.ServerScriptService.Server.player.PlayerStatsManager)

local function onActivated(player)
	PlayerStatsManager.Heal(player, HEAL_AMOUNT)
	Tool:Destroy() -- Consume the medkit
end

Tool.Activated:Connect(function()
	local player = Players:GetPlayerFromCharacter(Tool.Parent)
	if player then 
		onActivated(player) 
	end
end)