--[[
    BackpackUI.client.lua
    Simple responsive counter UI for backpack that only shows when Backpack is equipped
]]
--

local Players		   = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local player       = Players.LocalPlayer
local playerGui    = player:WaitForChild("PlayerGui")

-- Mobile detection
local isMobile 	   = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local screenGui    = playerGui:WaitForChild("SackGui")
local mainFrame	   = screenGui:WaitForChild("SackFrame")
local counterLabel = mainFrame:WaitForChild("Counter")

counterLabel.TextSize = 12
local mobileFrame 	  = nil
local storeButton 	  = nil
local retrieveButton  = nil

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

local currentItemCount = 0
local sackEquipped = false

local function showHint(message)
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
	counterLabel.Text = currentItemCount .. "/10"
	updateVisibility()
end

-- Check if Backpack tool is equipped
local function checkSackEquipped()
	local character = player.Character
	if not character then
		sackEquipped = false
		updateVisibility()
		return
	end

	-- Check if Backpack is equipped in character
	local sackTool = character:FindFirstChild("Backpack")
	sackEquipped = (sackTool ~= nil)
	updateVisibility()
end

-- Monitor for Backpack tool equipped/unequipped
local function onCharacterAdded(character)
	-- Monitor for tools being equipped (added to character)
	character.ChildAdded:Connect(function(child)
		if child.Name == "Backpack" and child:IsA("Tool") then
			sackEquipped = true
			updateVisibility()

			-- Monitor for when this specific tool is unequipped
			child.AncestryChanged:Connect(function()
				if child.Parent ~= character then
					sackEquipped = false
					updateVisibility()
				end
			end)
		end
	end)

	-- Initial check
	checkSackEquipped()
end

local function onBackpackAdded(child)
	if child.Name == "Backpack" and child:IsA("Tool") then
		-- Tool was added to backpack, monitor for equipping
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
	if tool.Name == "Backpack" and tool:IsA("Tool") then
		onBackpackAdded(tool)
	end
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

_G.BackpackUI = {
	updateContents = updateContents,
	showHint = showHint,
}
