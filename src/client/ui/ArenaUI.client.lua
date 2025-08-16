-- src/client/ui/ArenaUI.client.lua
-- Handles the Arena UI display and countdown timer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ArenaConfig = require(ReplicatedStorage.Shared.config.ArenaConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- References (may be re-bound if GUI is recreated)
local arenaGui = nil
local mainText = nil
local timerText = nil

-- State tracking
local arenaActive = false
local endTime = nil

-- Flash state to avoid spawning overlapping tweens
local flashTweenActive = false

-- Helper to (re)bind ArenaGui and children safely
local arenaAncestryConn = nil
local function bindArenaGui()
	arenaGui = playerGui:WaitForChild("ArenaGui")
	mainText = arenaGui:WaitForChild("MainText")
	timerText = arenaGui:WaitForChild("TimerText")
	if arenaGui:GetAttribute("Active") == nil then
		arenaGui:SetAttribute("Active", false)
	end
	if arenaGui:GetAttribute("EndTime") == nil then
		arenaGui:SetAttribute("EndTime", 0)
	end
	-- If arena is active when GUI gets recreated, ensure it becomes visible again
	if arenaActive then
		arenaGui.Enabled = true
		arenaGui:SetAttribute("Active", true)
		arenaGui:SetAttribute("EndTime", endTime or 0)
		-- Update timer text immediately using current endTime
		local remaining = math.max(0, (endTime or 0) - os.clock())
		timerText.Text = "SURVIVE FOR " .. string.format("%d:%02d", math.floor(remaining/60), math.floor(remaining % 60))
	end
	-- Reconnect a watcher so if ArenaGui is removed again, we re-bind on re-parent
	if arenaAncestryConn then
		arenaAncestryConn:Disconnect()
		arenaAncestryConn = nil
	end
	arenaAncestryConn = arenaGui.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			-- Wait a moment for Studio/engine to reinsert PlayerGui children, then rebind
			task.defer(function()
				if playerGui and playerGui.Parent then
					local ok = pcall(function()
						bindArenaGui()
					end)
					if not ok then
						-- Ignore; will bind next time ArenaGui exists
					end
				end
			end)
		end
	end)
end

-- Helper functions
local function getArenaRemote(name)
	local arenaFolder = ReplicatedStorage:FindFirstChild("Remotes")
		and ReplicatedStorage.Remotes:FindFirstChild(ArenaConfig.Remotes.Folder)
	if not arenaFolder then
		return nil
	end
	return arenaFolder:FindFirstChild(name)
end

-- Rebind ArenaGui initially and on future respawns/recreations
bindArenaGui()

local function showArenaUI()
	arenaGui.Enabled = true
	arenaGui:SetAttribute("Active", true)
	arenaGui:SetAttribute("EndTime", endTime or 0)
	
	-- Set initial text
	mainText.Text = "AN ANCIENT EVIL HAS AWAKENED"
	-- Use config duration for initial text to avoid mismatch
	local initialSeconds = tonumber(ArenaConfig.DurationSeconds) or 0
	if initialSeconds > 0 then
		timerText.Text = string.format("SURVIVE FOR %d:%02d", math.floor(initialSeconds/60), initialSeconds % 60)
	else
		timerText.Text = "SURVIVE"
	end
	
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
	arenaGui:SetAttribute("Active", false)
	arenaGui:SetAttribute("EndTime", 0)
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
	
	-- Flash red when under 10 seconds (throttled)
	if remaining > 10 then
		-- Ensure normal color outside danger zone
		if timerText.TextColor3 ~= Color3.fromRGB(255, 255, 255) then
			timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		flashTweenActive = false
	elseif remaining > 0 then
		if not flashTweenActive then
			flashTweenActive = true
			local flash = TweenService:Create(
				timerText,
				TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{TextColor3 = Color3.fromRGB(255, 0, 0)}
			)
			flash:Play()
			flash.Completed:Once(function()
				local flashBack = TweenService:Create(
					timerText,
					TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{TextColor3 = Color3.fromRGB(255, 255, 255)}
				)
				flashBack:Play()
				flashBack.Completed:Once(function()
					flashTweenActive = false
				end)
			end)
		end
	end
	
	if remaining <= 0 then
		-- Timer reached zero - arena should end
		hideArenaUI()
		-- TODO: Show victory UI (not implemented yet)
	end
end

-- Remote event connections are handled by the new UI system when enabled
-- This script is deprecated when UseUIManager is true. Legacy logic removed.

-- Initialize
arenaGui.Enabled = false -- Start hidden
arenaGui:SetAttribute("Active", false)
arenaGui:SetAttribute("EndTime", 0)

-- If character respawns and Arena is still active, ensure GUI is restored
player.CharacterAdded:Connect(function()
	if arenaActive then
		-- Re-bind in case GUI was recreated on respawn
		bindArenaGui()
		arenaGui.Enabled = true
	end
end)
