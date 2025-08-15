--[[
    BackpackUI.client.lua
    Simple responsive counter UI for backpack that only shows when Backpack/Sack is equipped
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BackpackChanged = ReplicatedStorage.Remotes:WaitForChild("BackpackChanged")

-- Player References
local player 	= Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI Elements
local screenGui = playerGui:WaitForChild("SackGui")
local mainFrame = screenGui:WaitForChild("SackFrame")
local counterLabel 	 = mainFrame:WaitForChild("Counter")
local mobileFrame 	 = nil
local storeButton 	 = nil
local retrieveButton = nil

local isMobile = UserInputService.TouchEnabled
local currentItemCount = 0
local sackEquipped = false

counterLabel.TextSize = 12

---------------------------------------------------------------------------------------

if isMobile then
	mobileFrame = screenGui:WaitForChild("MobileButtons")
	storeButton = mobileFrame:WaitForChild("StoreButton")
	retrieveButton = mobileFrame:WaitForChild("RetrieveButton")

	task.spawn(function()
		repeat
			task.wait(0.1)
		until _G.BackpackController
		storeButton.MouseButton1Click:Connect(function()
			_G.BackpackController.storeCurrentObject()
		end)
		retrieveButton.MouseButton1Click:Connect(function()
			_G.BackpackController.retrieveTopObject()
		end)
	end)
end

local function updateVisibility()
	local shouldShow = sackEquipped
	mainFrame.Visible = shouldShow
	if isMobile and mobileFrame then
		mobileFrame.Visible = shouldShow
	end
end

local function updateContents(contents)
	currentItemCount = #contents
	counterLabel.Text = string.format("%d/10", currentItemCount)
	updateVisibility()
end

local function findSackTool(container)
	return container:FindFirstChild("Backpack") or container:FindFirstChild("Sack")
end

local function checkSackEquipped()
	local character = player.Character
	if not character then
		sackEquipped = false
		updateVisibility()
		return
	end
	local sackTool = findSackTool(character)
	sackEquipped = (sackTool ~= nil)
	updateVisibility()
end

local function onCharacterAdded(character)
	character.ChildAdded:Connect(function(child)
		if (child.Name == "Backpack" or child.Name == "Sack") and child:IsA("Tool") then
			sackEquipped = true
			updateVisibility()
			child.AncestryChanged:Connect(function()
				if child.Parent ~= character then
					sackEquipped = false
					updateVisibility()
				end
			end)
		end
	end)
	checkSackEquipped()
end

local function onBackpackAdded(child)
	if (child.Name == "Backpack" or child.Name == "Sack") and child:IsA("Tool") then
		child.Equipped:Connect(function()
			sackEquipped = true
			updateVisibility()
		end)
		child.Unequipped:Connect(function()
			sackEquipped = false
			updateVisibility()
		end)
	end
end

player.Backpack.ChildAdded:Connect(onBackpackAdded)
for _, tool in pairs(player.Backpack:GetChildren()) do
	if (tool.Name == "Backpack" or tool.Name == "Sack") and tool:IsA("Tool") then
		onBackpackAdded(tool)
	end
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

BackpackChanged.OnClientEvent:Connect(function(contents)
	updateContents(contents or {})
end)

task.spawn(function()
	repeat
		task.wait(0.1)
	until _G.BackpackController
	local get = _G.BackpackController.getBackpackContents
	if typeof(get) == "function" then
		local ok, contents = pcall(get)
		if ok and contents then
			updateContents(contents)
		end
	end
end)

_G.BackpackUI = {
	updateContents = updateContents,
	showHint = showHint,
}
