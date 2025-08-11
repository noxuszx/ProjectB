-- src/client/ui/DeathUI.client.lua
-- Handles death UI display and respawn functionality

local Players 			= game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService 		= game:GetService("TweenService")
local player 			= Players.LocalPlayer
local playerGui 		= player:WaitForChild("PlayerGui")

local deathRemotes 		   = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Death")
local showUIRemote 		   = deathRemotes:WaitForChild("ShowUI")
local requestRespawnRemote = deathRemotes:WaitForChild("RequestRespawn")

local deathGui 		  = playerGui:WaitForChild("DeathGui")
local titleLabel 	  = deathGui:WaitForChild("TextLabel")
local timerLabel 	  = deathGui:WaitForChild("TextTimer")
local deathFrame 	  = deathGui:WaitForChild("DeathFrame")

-- Reference to ArenaGui to hide it when death UI shows
local arenaGui = playerGui:WaitForChild("ArenaGui")

local reviveButton 	  = deathFrame:WaitForChild("ReviveBTN")
local lobbyButton 	  = deathFrame:WaitForChild("LobbyBTN")
local reviveAllButton = deathFrame:FindFirstChild("RevivAllBTN")

local isShowingDeathUI = false
local countdownThread = nil

deathGui.Enabled = false
--------------------------------------------------------------------------------------------------

local function showDeathUI(timeoutSeconds)
	if isShowingDeathUI then
		return
	end

	isShowingDeathUI = true
	deathGui.Enabled = true
	
	-- Hide ArenaUI when death UI is shown to prevent overlap
	arenaGui.Enabled = false

	print("[DeathUI] Showing death UI with", timeoutSeconds, "second timeout")

	if countdownThread then
		task.cancel(countdownThread)
	end

	countdownThread = task.spawn(function()
		local timeLeft = timeoutSeconds
		while timeLeft > 0 and isShowingDeathUI do
			timerLabel.Text = "Respawning in: " .. timeLeft .. "s"
			task.wait(1)
			timeLeft = timeLeft - 1
		end
		if isShowingDeathUI then
			timerLabel.Text = "Respawning..."
		end
	end)
end

local function hideDeathUI()
	if not isShowingDeathUI then
		return
	end

	print("[DeathUI] Hiding death UI")
	isShowingDeathUI = false
	deathGui.Enabled = false

	if countdownThread then
		task.cancel(countdownThread)
		countdownThread = nil
	end
end

local function onReviveClicked()
	if not isShowingDeathUI then
		return
	end

	print("[DeathUI] Revive button clicked")
	hideDeathUI()
	requestRespawnRemote:FireServer()
end

local function onLobbyClicked()
	if not isShowingDeathUI then
		return
	end

	print("[DeathUI] Lobby button clicked (placeholder - does nothing)")

	-- For now, just show a message in console
	-- Future: This will teleport player back to lobby
end

-- Handle revive all button click (placeholder)
local function onReviveAllClicked()
	if not isShowingDeathUI then
		return -- UI not showing
	end

	print("[DeathUI] Revive All button clicked (placeholder - does nothing)")

	-- For now, just show a message in console
	-- Future: This could revive all dead players or similar functionality
end

local function onCharacterAdded(character)
	if isShowingDeathUI then
		print("[DeathUI] Character spawned, hiding death UI")
		hideDeathUI()
	end
end

showUIRemote.OnClientEvent:Connect(showDeathUI)
reviveButton.MouseButton1Click:Connect(onReviveClicked)
lobbyButton.MouseButton1Click:Connect(onLobbyClicked)

if reviveAllButton then
	reviveAllButton.MouseButton1Click:Connect(onReviveAllClicked)
	print("[DeathUI] ReviveAll button found and connected")
else
	print("[DeathUI] ReviveAll button not found, skipping connection")
end


if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

print("[DeathUI] Death UI system initialized with responsive layout")
