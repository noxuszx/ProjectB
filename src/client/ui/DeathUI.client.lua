-- src/client/ui/DeathUI.client.lua
-- Handles death UI display and respawn functionality

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local deathRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Death")
local showUIRemote = deathRemotes:WaitForChild("ShowUI")
local requestRespawnRemote = deathRemotes:WaitForChild("RequestRespawn")

local deathGui = playerGui:WaitForChild("DeathGui")
local deathGuiTemplate = deathGui:Clone()

local titleLabel = deathGui:WaitForChild("TextLabel")
local timerLabel = deathGui:WaitForChild("TextTimer")
local deathFrame = deathGui:WaitForChild("DeathFrame")

local arenaGui = playerGui:WaitForChild("ArenaGui")

local reviveButton = deathFrame:WaitForChild("ReviveBTN")
local lobbyButton = deathFrame:WaitForChild("LobbyBTN")
local reviveAllButton = deathFrame:FindFirstChild("RevivAllBTN")

local isShowingDeathUI = false
local countdownThread = nil

local reviveConn, lobbyConn, reviveAllConn = nil, nil, nil

local function bindGuiElements()
	if not deathGui then
		return
	end

	titleLabel 		= deathGui:WaitForChild("TextLabel")
	timerLabel 		= deathGui:WaitForChild("TextTimer")
	deathFrame 		= deathGui:WaitForChild("DeathFrame")
	reviveButton 	= deathFrame:WaitForChild("ReviveBTN")
	lobbyButton 	= deathFrame:WaitForChild("LobbyBTN")
	reviveAllButton = deathFrame:FindFirstChild("RevivAllBTN")

	if reviveConn then
		reviveConn:Disconnect()
		reviveConn = nil
	end
	if lobbyConn then
		lobbyConn:Disconnect()
		lobbyConn = nil
	end
	if reviveAllConn then
		reviveAllConn:Disconnect()
		reviveAllConn = nil
	end

	-- Reconnect
	reviveConn = reviveButton.MouseButton1Click:Connect(function()
		if not isShowingDeathUI then
			return
		end
		deathGui.Enabled = false
		isShowingDeathUI = false
		requestRespawnRemote:FireServer()
	end)

	lobbyConn = lobbyButton.MouseButton1Click:Connect(function()
		if not isShowingDeathUI then
			return
		end
	end)

	if reviveAllButton then
		reviveAllConn = reviveAllButton.MouseButton1Click:Connect(function()
			if not isShowingDeathUI then
				return
			end
		end)
	end
end

local function resolveDeathGui()
	if not playerGui or not playerGui.Parent then
		playerGui = player:WaitForChild("PlayerGui")
	end

	local found = playerGui:FindFirstChild("DeathGui")
	if found and found ~= deathGui then
		deathGui = found
		bindGuiElements()
	elseif not found and deathGui and not deathGui.Parent then
		local ok = pcall(function()
			deathGui.Parent = playerGui
		end)
		if ok then
			bindGuiElements()
		else
			if deathGuiTemplate then
				local newGui = deathGuiTemplate:Clone()
				newGui.Name = "DeathGui"
				newGui.Parent = playerGui
				deathGui = newGui
				bindGuiElements()
			else
				warn("[DeathUI] No template to recreate DeathGui; waiting for engine to provide one")
			end
		end
	end

	if not deathGui or not deathGui.Parent then
		deathGui = playerGui:WaitForChild("DeathGui")
		bindGuiElements()
	end

	deathGui.DisplayOrder = 100

	deathGui.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			task.defer(function()
				if deathGui and not deathGui.Parent then
					local ok2 = pcall(function()
						deathGui.Parent = playerGui
					end)
					if not ok2 and deathGuiTemplate then
						local newGui = deathGuiTemplate:Clone()
						newGui.Name = "DeathGui"
						newGui.Parent = playerGui
						deathGui = newGui
						bindGuiElements()
					end
				end
			end)
		end
	end)
end

if deathGui then
	deathGui.Enabled = false
end

local function showDeathUI(timeoutSeconds)
	resolveDeathGui()

	isShowingDeathUI = true
	deathGui.Enabled = true

	if arenaGui.Enabled then
		arenaGui.Enabled = false
	end

	deathGui.DisplayOrder = 100

	if countdownThread then
		task.cancel(countdownThread)
	end

	-- Handle timer vs no-timer scenarios
	if timeoutSeconds > 0 then
		countdownThread = task.spawn(function()
			local timeLeft = timeoutSeconds
			while timeLeft > 0 and isShowingDeathUI do
				timerLabel.Text = "Returning to lobby in: " .. timeLeft .. "s"
				task.wait(1)
				timeLeft = timeLeft - 1
			end
			if isShowingDeathUI then
				timerLabel.Text = "Returning to lobby..."
			end
		end)
	else
		timerLabel.Text = "Other players are still alive"
	end
end

local function hideDeathUI()
	if not isShowingDeathUI then
		return
	end
	isShowingDeathUI = false
	deathGui.Enabled = false

	if countdownThread then
		task.cancel(countdownThread)
		countdownThread = nil
	end
end

local function onCharacterAdded(character)
	if isShowingDeathUI then
		hideDeathUI()
	end
end

showUIRemote.OnClientEvent:Connect(showDeathUI)

bindGuiElements()

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
