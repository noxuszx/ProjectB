-- RevivalPromptVisibility.client.lua
-- Handles hiding revival prompts from dead players themselves

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Track which prompts to hide based on player death state
local function handlePromptVisibility()
	-- Find all revival prompts in the workspace
for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer.Character then
			local humanoidRootPart = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				local revivalPrompt = humanoidRootPart:FindFirstChild("RevivalPrompt")
				if revivalPrompt and revivalPrompt:IsA("ProximityPrompt") then
					local hiddenFromPlayerId = revivalPrompt:GetAttribute("HiddenFromPlayer")
					
					-- Hide for the owner (dead player), show for everyone else
					if hiddenFromPlayerId == player.UserId then
						revivalPrompt.Enabled = false
					else
						revivalPrompt.Enabled = true
					end
				end
			end
		end
	end
end

-- Check visibility every frame (lightweight since we're just checking attributes)
RunService.Heartbeat:Connect(handlePromptVisibility)

-- Also check when players are added/removed
Players.PlayerAdded:Connect(function()
	task.wait(1) -- Small delay to ensure character loads
	handlePromptVisibility()
end)

Players.PlayerRemoving:Connect(handlePromptVisibility)