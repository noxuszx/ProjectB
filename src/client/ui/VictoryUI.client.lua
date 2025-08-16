-- src/client/ui/VictoryUI.client.lua
-- Handles the Victory UI display with countdown and player choices

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ArenaConfig = require(ReplicatedStorage.Shared.config.ArenaConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- References (re-bound if GUI is recreated)
local victoryGui
local textLabel
local textTimer
local victoryFrame
local lobbyBtn
local continueBtn

-- Connections to clean up on rebind
local lobbyConn
local continueConn
local ancestryConn

-- State tracking
local countdownActive = false
local countdownCoroutine = nil

-- Forward declarations for functions used before definition
local sendChoice
local startCountdown
local stopCountdown
local showVictoryUI
local ensureGuiBound

-- Helper functions
local function getArenaRemote(name)
	local arenaFolder = ReplicatedStorage:FindFirstChild("Remotes")
		and ReplicatedStorage.Remotes:FindFirstChild(ArenaConfig.Remotes.Folder)
	if not arenaFolder then
		return nil
	end
	return arenaFolder:FindFirstChild(name)
end

local function waitForArenaRemote(name, timeout)
	timeout = timeout or 10
	local start = os.clock()
	-- Try fast path first
	local r = getArenaRemote(name)
	if r then return r end
	-- Wait for the folders and remote to appear
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", math.max(0, timeout - (os.clock() - start)))
	if not remotesFolder then return nil end
	local arenaFolder = remotesFolder:WaitForChild(ArenaConfig.Remotes.Folder, math.max(0, timeout - (os.clock() - start)))
	if not arenaFolder then return nil end
	return arenaFolder:WaitForChild(name, math.max(0, timeout - (os.clock() - start)))
end

local function bindVictoryGui()
	-- Disconnect old connections if any
	if lobbyConn then lobbyConn:Disconnect() lobbyConn = nil end
	if continueConn then continueConn:Disconnect() continueConn = nil end
	if ancestryConn then ancestryConn:Disconnect() ancestryConn = nil end

	victoryGui = playerGui:WaitForChild("VictoryGui")
	textLabel = victoryGui:WaitForChild("TextLabel")
	textTimer = victoryGui:WaitForChild("TextTimer")
	victoryFrame = victoryGui:WaitForChild("VictoryFrame")
	lobbyBtn = victoryFrame:WaitForChild("LobbyBTN")
	continueBtn = victoryFrame:WaitForChild("ContinueBTN")

	-- Ensure starts hidden on (re)bind
	victoryGui.Enabled = false

	-- Reconnect button handlers
	lobbyConn = lobbyBtn.MouseButton1Click:Connect(function()
		sendChoice("lobby")
	end)
	continueConn = continueBtn.MouseButton1Click:Connect(function()
		sendChoice("continue")
	end)

	-- Watch for GUI removal (e.g., on respawn) and rebind when it comes back
	ancestryConn = victoryGui.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			-- Stop any active countdown and wait for PlayerGui to restore child, then rebind
			stopCountdown()
			task.defer(function()
				if playerGui and playerGui.Parent then
					local ok = pcall(function()
						bindVictoryGui()
					end)
					if not ok then
						-- will try again on next removal/add cycle
					end
				end
			end)
		end
	end)
end

local function ensureGuiBound()
	if not victoryGui or victoryGui.Parent ~= playerGui then
		bindVictoryGui()
	end
end

sendChoice = function(choice)
	local postGameRemote = getArenaRemote(ArenaConfig.Remotes.PostGameChoice) or waitForArenaRemote(ArenaConfig.Remotes.PostGameChoice, 5)
	if postGameRemote then
		postGameRemote:FireServer({ choice = choice })
	end
	hideVictoryUI()
end

startCountdown = function()
	if countdownActive then
		return
	end
	
	countdownActive = true
	local timeLeft = 30
	
	countdownCoroutine = task.spawn(function()
		while timeLeft > 0 and countdownActive do
			if not textTimer or textTimer.Parent == nil then
				-- GUI likely recreated; try to rebind and continue
				ensureGuiBound()
			end
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

stopCountdown = function()
	countdownActive = false
	if countdownCoroutine then
		task.cancel(countdownCoroutine)
		countdownCoroutine = nil
	end
end

showVictoryUI = function(message)
	ensureGuiBound()
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
	-- Note: keep frame transparency behavior as per user preference (remain invisible)
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
	if victoryGui then
		victoryGui.Enabled = false
	end
end

-- Remote event connection
local function connectVictoryRemote()
	-- Be robust to replication timing: wait up to 10s for the remote to exist
	local victoryRemote = getArenaRemote(ArenaConfig.Remotes.Victory) or waitForArenaRemote(ArenaConfig.Remotes.Victory, 10)
	if victoryRemote then
		victoryRemote.OnClientEvent:Connect(function(data)
			local message = data and data.message or ArenaConfig.UI.VictoryMessage
			showVictoryUI(message)
		end)
	else
		-- As a fallback, listen for Remotes folder being added and try once more
		ReplicatedStorage.ChildAdded:Once(function(child)
			if child.Name == "Remotes" then
				connectVictoryRemote()
			end
		end)
	end
end

-- Initialize
bindVictoryGui()
connectVictoryRemote()

-- Also rebind if the character respawns (some setups rebuild GUIs)
player.CharacterAdded:Connect(function()
	bindVictoryGui()
end)
