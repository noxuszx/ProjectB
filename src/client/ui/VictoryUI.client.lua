-- src/client/ui/VictoryUI.client.lua
-- Handles the Victory UI display with countdown and player choices

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ArenaConfig = require(ReplicatedStorage.Shared.config.ArenaConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Reference existing VictoryGui elements
local victoryGui = playerGui:WaitForChild("VictoryGui")
local textLabel = victoryGui:WaitForChild("TextLabel")
local textTimer = victoryGui:WaitForChild("TextTimer")
local victoryFrame = victoryGui:WaitForChild("VictoryFrame")
local lobbyBtn = victoryFrame:WaitForChild("LobbyBTN")
local continueBtn = victoryFrame:WaitForChild("ContinueBTN")

-- State tracking
local countdownActive = false
local countdownCoroutine = nil

-- Helper functions
local function getArenaRemote(name)
	local arenaFolder = ReplicatedStorage:FindFirstChild("Remotes")
		and ReplicatedStorage.Remotes:FindFirstChild(ArenaConfig.Remotes.Folder)
	if not arenaFolder then
		return nil
	end
	return arenaFolder:FindFirstChild(name)
end

local function sendChoice(choice)
	local postGameRemote = getArenaRemote(ArenaConfig.Remotes.PostGameChoice)
	if postGameRemote then
		postGameRemote:FireServer({ choice = choice })
	end
	hideVictoryUI()
end

local function startCountdown()
	if countdownActive then
		return
	end
	
	countdownActive = true
	local timeLeft = 30
	
	countdownCoroutine = task.spawn(function()
		while timeLeft > 0 and countdownActive do
			textTimer.Text = string.format("GOING BACK TO LOBBY IN %ds", timeLeft)
			task.wait(1)
			timeLeft -= 1
		end
		
		if countdownActive then
			-- Auto-select lobby after countdown
			sendChoice("lobby")
		end
	end)
end

local function stopCountdown()
	countdownActive = false
	if countdownCoroutine then
		task.cancel(countdownCoroutine)
		countdownCoroutine = nil
	end
end

local function showVictoryUI(message)
	-- Set victory message
	textLabel.Text = message or "VICTORY!"
	
	-- Show UI with fade in animation
	victoryGui.Enabled = true
	
	-- Set initial transparency for fade in
	textLabel.TextTransparency = 1
	textTimer.TextTransparency = 1
	victoryFrame.BackgroundTransparency = 1
	lobbyBtn.BackgroundTransparency = 1
	lobbyBtn.TextTransparency = 1
	continueBtn.BackgroundTransparency = 1
	continueBtn.TextTransparency = 1
	
	-- Create fade in tweens
	local fadeInDuration = 0.8
	local fadeInfo = TweenInfo.new(fadeInDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	local textLabelTween = TweenService:Create(textLabel, fadeInfo, {TextTransparency = 0})
	local textTimerTween = TweenService:Create(textTimer, fadeInfo, {TextTransparency = 0})
	local frameTween = TweenService:Create(victoryFrame, fadeInfo, {BackgroundTransparency = 1})
	local lobbyBtnBgTween = TweenService:Create(lobbyBtn, fadeInfo, {BackgroundTransparency = 0})
	local lobbyBtnTextTween = TweenService:Create(lobbyBtn, fadeInfo, {TextTransparency = 0})
	local continueBtnBgTween = TweenService:Create(continueBtn, fadeInfo, {BackgroundTransparency = 0})
	local continueBtnTextTween = TweenService:Create(continueBtn, fadeInfo, {TextTransparency = 0})
	
	-- Play all tweens
	textLabelTween:Play()
	textTimerTween:Play()
	frameTween:Play()
	lobbyBtnBgTween:Play()
	lobbyBtnTextTween:Play()
	continueBtnBgTween:Play()
	continueBtnTextTween:Play()
	
	-- Start countdown after fade in
	textLabelTween.Completed:Connect(function()
		startCountdown()
	end)
end

function hideVictoryUI()
	stopCountdown()
	victoryGui.Enabled = false
end

-- Button click handlers
lobbyBtn.MouseButton1Click:Connect(function()
	sendChoice("lobby")
end)

continueBtn.MouseButton1Click:Connect(function()
	sendChoice("continue")
end)

-- Remote event connection
local function connectVictoryRemote()
	local victoryRemote = getArenaRemote(ArenaConfig.Remotes.Victory)
	if victoryRemote then
		victoryRemote.OnClientEvent:Connect(function(data)
			local message = data and data.message or ArenaConfig.UI.VictoryMessage
			showVictoryUI(message)
		end)
	end
end

-- Initialize
victoryGui.Enabled = false -- Start hidden
connectVictoryRemote()