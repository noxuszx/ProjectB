-- src/client/ui/EconomyUI.client.lua
-- Client-side UI for displaying player money with green background and dollar sign

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Configuration
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)

-- Player and GUI references
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Economy")
local updateMoneyRemote = remotes:WaitForChild("UpdateMoney")

-- UI Variables
local moneyGui = nil
local moneyFrame = nil
local dollarLabel = nil
local amountLabel = nil
local currentMoney = 0

-- Initialize references to Studio-created UI
local function initializeExistingUI()
	-- Get references to the Studio-created UI elements
	moneyGui = playerGui:WaitForChild("EconomyGui")
	moneyFrame = moneyGui:WaitForChild("MoneyFrame")
	dollarLabel = moneyFrame:WaitForChild("DollarSign")
	amountLabel = moneyFrame:WaitForChild("Amount")
	
	-- Initialize with current money value
	amountLabel.Text = tostring(currentMoney)
	
	if EconomyConfig.Debug.Enabled then
		print("[EconomyUI] Connected to Studio-created UI")
	end
end

-- Update the money display with smooth animation
local function updateMoneyDisplay(newAmount)
      if not amountLabel then return end

      currentMoney = newAmount
      amountLabel.Text = tostring(newAmount)

      if EconomyConfig.Debug.Enabled and EconomyConfig.Debug.LogMoneyChanges then
          print("[EconomyUI] Money updated to:", newAmount)
      end
  end

-- Handle money updates from server
local function onMoneyUpdated(newAmount)
	updateMoneyDisplay(newAmount)
end

-- Handle player respawn
local function onCharacterAdded(character)
	-- Reconnect to UI if references were lost
	if not moneyGui or not moneyGui.Parent then
		initializeExistingUI()
	end
end

-- Initialize the UI
local function init()
	-- Connect to Studio-created UI
	initializeExistingUI()
	
	-- Connect to money updates
	updateMoneyRemote.OnClientEvent:Connect(onMoneyUpdated)
	
	-- Handle character respawn
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	
	if _G.SystemLoadMonitor then
		_G.SystemLoadMonitor.reportSystemLoaded("EconomyUI")
	end
end

-- Start the UI
init()