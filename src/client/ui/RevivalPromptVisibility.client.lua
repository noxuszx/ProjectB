-- RevivalPromptVisibility.client.lua
-- Handles hiding revival prompts and death indicators from dead players themselves

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local function shouldHide(instance)
	local hiddenFromPlayerId = instance and instance:GetAttribute("HiddenFromPlayer")
	return hiddenFromPlayerId == player.UserId
end

-- Track which prompts/indicators to hide based on HiddenFromPlayer attribute
local function handleVisibility()
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		local character = otherPlayer.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- Revival Proximity Prompt
				local prompt = hrp:FindFirstChild("RevivalPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Enabled = not shouldHide(prompt)
				end

				-- Heal Proximity Prompt: only hide for the target; do not force-enable for others
				local healPrompt = hrp:FindFirstChild("HealPrompt")
				if healPrompt and healPrompt:IsA("ProximityPrompt") then
					if shouldHide(healPrompt) then
						healPrompt.Enabled = false
					else
						-- Use server-authored Healable attribute to reflect correct visibility
						local healable = hrp:GetAttribute("Healable")
						if typeof(healable) == "boolean" then
							healPrompt.Enabled = healable
						end
					end
				end

				-- Billboard (Death label)
				local billboard = hrp:FindFirstChild("DeathBillboard")
				if billboard and billboard:IsA("BillboardGui") then
					billboard.Enabled = not shouldHide(billboard)
				end
			end

			-- Highlight on character
			local highlight = character:FindFirstChild("DeathHighlight")
			if highlight and highlight:IsA("Highlight") then
				highlight.Enabled = not shouldHide(highlight)
			end
		end
	end
end

-- Check visibility every frame (lightweight attribute checks)
RunService.Heartbeat:Connect(handleVisibility)

-- Also check when players are added/removed
Players.PlayerAdded:Connect(function()
	task.wait(1)
	handleVisibility()
end)

Players.PlayerRemoving:Connect(handleVisibility)
