-- Simple medkit healing script
-- Place this script INSIDE your medkit tool

local Tool = script.Parent
local HEAL_AMOUNT = 35
local Players = game:GetService("Players")

local function onActivated(player)
	-- Heal the actual Roblox health system
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		local humanoid = player.Character.Humanoid
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + HEAL_AMOUNT)
		print("[Medkit] Healed", player.Name, "for", HEAL_AMOUNT, "health")
	end

	Tool:Destroy() -- Consume the medkit
end

Tool.Activated:Connect(function()
	local player = Players:GetPlayerFromCharacter(Tool.Parent)
	if player then
		onActivated(player)
	end
end)