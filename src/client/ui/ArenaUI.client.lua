-- src/client/ui/ArenaUI.client.lua
-- Handles the Arena UI display and countdown timer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ArenaConfig = require(ReplicatedStorage.Shared.config.ArenaConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Reference existing ArenaGui elements
local arenaGui = playerGui:WaitForChild("ArenaGui")
local mainText = arenaGui:WaitForChild("MainText")
local timerText = arenaGui:WaitForChild("TimerText")

-- State tracking
local arenaActive = false
local endTime = nil

-- Helper functions
local function getArenaRemote(name)
	local arenaFolder = ReplicatedStorage:FindFirstChild("Remotes")
		and ReplicatedStorage.Remotes:FindFirstChild(ArenaConfig.Remotes.Folder)
	if not arenaFolder then
		return nil
	end
	return arenaFolder:FindFirstChild(name)
end

local function showArenaUI()
	arenaGui.Enabled = true
	
	-- Set initial text
	mainText.Text = "AN ANCIENT EVIL HAS AWAKENED"
	timerText.Text = "SURVIVE FOR 3 MINUTES"
	
	-- Fade in animation
	mainText.TextTransparency = 1
	timerText.TextTransparency = 1
	
	local fadeInTween = TweenService:Create(
		mainText,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 0}
	)
	
	local timerFadeInTween = TweenService:Create(
		timerText,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 0}
	)
	
	fadeInTween:Play()
	timerFadeInTween:Play()
end

local function hideArenaUI()
	arenaGui.Enabled = false
	arenaActive = false
	endTime = nil
end

local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", minutes, secs)
end

local function updateTimer()
	if not arenaActive or not endTime then
		return
	end
	
	local remaining = math.max(0, endTime - os.clock())
	timerText.Text = "SURVIVE FOR " .. formatTime(remaining)
	
	-- Flash red when under 10 seconds
	if remaining <= 10 and remaining > 0 then
		local flash = TweenService:Create(
			timerText,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{TextColor3 = Color3.fromRGB(255, 0, 0)}
		)
		flash:Play()
		flash.Completed:Connect(function()
			local flashBack = TweenService:Create(
				timerText,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{TextColor3 = Color3.fromRGB(255, 255, 255)}
			)
			flashBack:Play()
		end)
	end
	
	if remaining <= 0 then
		-- Timer reached zero - arena should end
		hideArenaUI()
		-- TODO: Show victory UI (not implemented yet)
	end
end

-- Remote event connections
local function connectRemotes()
	local startTimerRemote = getArenaRemote(ArenaConfig.Remotes.StartTimer)
	if startTimerRemote then
		startTimerRemote.OnClientEvent:Connect(function(data)
			arenaActive = true
			endTime = data.endTime
			showArenaUI()
		end)
	end
	
	local syncRemote = getArenaRemote(ArenaConfig.Remotes.Sync)
	if syncRemote then
		syncRemote.OnClientEvent:Connect(function(data)
			if arenaActive then
				endTime = data.endTime
			end
		end)
	end
	
	local pauseRemote = getArenaRemote(ArenaConfig.Remotes.Pause)
	if pauseRemote then
		pauseRemote.OnClientEvent:Connect(function()
			-- Could add pause UI effects here
		end)
	end
	
	local resumeRemote = getArenaRemote(ArenaConfig.Remotes.Resume)
	if resumeRemote then
		resumeRemote.OnClientEvent:Connect(function(data)
			endTime = data.endTime
		end)
	end
	
	local victoryRemote = getArenaRemote(ArenaConfig.Remotes.Victory)
	if victoryRemote then
		victoryRemote.OnClientEvent:Connect(function(data)
			hideArenaUI()
			-- TODO: Show victory UI with data.message
		end)
	end
end

-- Timer update loop
task.spawn(function()
	while true do
		updateTimer()
		task.wait(0.1) -- Update every 100ms for smooth countdown
	end
end)

-- Initialize
arenaGui.Enabled = false -- Start hidden
connectRemotes()

