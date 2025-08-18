--[[
    BackpackUI.client.lua
    Simple responsive counter UI for backpack that only shows when Backpack/Sack is equipped
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BackpackChanged = ReplicatedStorage.Remotes:WaitForChild("BackpackChanged")

-- Player References
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI Elements
local screenGui = playerGui:WaitForChild("SackGui")
local mainFrame = screenGui:WaitForChild("SackFrame")
local counterLabel = mainFrame:WaitForChild("Counter")

local isMobile = UserInputService.TouchEnabled
local currentItemCount = 0
local maxCapacity = 10
local sackEquipped = false

counterLabel.TextSize = 12

---------------------------------------------------------------------------------------

local function updateVisibility()
	local shouldShow = sackEquipped
	mainFrame.Visible = shouldShow
	-- Mobile action buttons are handled by MobileActionController (no binding here)
end


local function updateContents(contents, capacity)
	currentItemCount = #contents
	if typeof(capacity) == "number" then
		maxCapacity = capacity
	end
	counterLabel.Text = string.format("%d/%d", currentItemCount, maxCapacity)
	updateVisibility()
end

local function findSackTool(container)
	return container:FindFirstChild("Backpack")
		or container:FindFirstChild("BackpackPro")
		or container:FindFirstChild("BackPackPro")
		or container:FindFirstChild("BackpackPrestige")
		or container:FindFirstChild("Sack")
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
		if (child:IsA("Tool") and (child.Name == "Backpack" or child.Name == "BackpackPro" or child.Name == "BackpackPrestige" or child.Name == "Sack")) then
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
	if child:IsA("Tool") and (child.Name == "Backpack" or child.Name == "BackpackPro" or child.Name == "BackpackPrestige" or child.Name == "Sack") then
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
	if tool:IsA("Tool") and (tool.Name == "Backpack" or tool.Name == "BackpackPro" or tool.Name == "BackpackPrestige" or tool.Name == "Sack") then
		onBackpackAdded(tool)
	end
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

BackpackChanged.OnClientEvent:Connect(function(contents)
	updateContents(contents or {}, maxCapacity)
end)

task.spawn(function()
	repeat
		task.wait(0.1)
	until _G.BackpackController
	local get = _G.BackpackController.getBackpackContents
	if typeof(get) == "function" then
		local ok, contents = pcall(get)
		if ok and contents then
			updateContents(contents, maxCapacity)
		end
	end
end)

_G.BackpackUI = {
	updateContents = updateContents,
	showHint = showHint,
}
