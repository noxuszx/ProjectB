--[[
    BackpackUI.client.lua
    Simple responsive counter UI for backpack that only shows when Sack is equipped
]]--

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Reference manually created UI elements
local screenGui = playerGui:WaitForChild("BackpackGui")
local mainFrame = screenGui:WaitForChild("BackpackFrame")
local counterLabel = mainFrame:WaitForChild("Counter")

-- Mobile buttons references
local mobileFrame = nil
local storeButton = nil
local retrieveButton = nil

if isMobile then
    mobileFrame = screenGui:WaitForChild("MobileButtons")
    storeButton = mobileFrame:WaitForChild("StoreButton")
    retrieveButton = mobileFrame:WaitForChild("RetrieveButton")
    
    task.spawn(function()
        repeat wait(0.1) until _G.BackpackController
        
        storeButton.MouseButton1Click:Connect(function()
            _G.BackpackController.storeCurrentObject()
        end)
        
        retrieveButton.MouseButton1Click:Connect(function()
            _G.BackpackController.retrieveTopObject()
        end)
    end)
end

-- State tracking
local currentItemCount = 0
local sackEquipped = false

-- Show hint message (console only since no HintLabel)
local function showHint(message)
    print("[BackpackUI Hint]", message)
end

-- Update UI visibility based on Sack equipped status
local function updateVisibility()
    local shouldShow = sackEquipped
    mainFrame.Visible = shouldShow
    
    if isMobile and mobileFrame then
        mobileFrame.Visible = shouldShow
    end
end

-- Update backpack counter display
local function updateContents(contents)
    currentItemCount = #contents
    counterLabel.Text = currentItemCount .. "/10"
    
    -- Update visibility based on Sack equipped status
    updateVisibility()
end

-- Check if Sack tool is equipped
local function checkSackEquipped()
    local character = player.Character
    if not character then
        sackEquipped = false
        updateVisibility()
        return
    end
    
    -- Check if Sack is equipped in character
    local sackTool = character:FindFirstChild("Sack")
    sackEquipped = (sackTool ~= nil)
    updateVisibility()
end

-- Monitor for Sack tool equipped/unequipped
local function onCharacterAdded(character)
    -- Monitor for tools being equipped (added to character)
    character.ChildAdded:Connect(function(child)
        if child.Name == "Sack" and child:IsA("Tool") then
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

-- Monitor player's backpack for when Sack tool is added/removed
local function onBackpackAdded(child)
    if child.Name == "Sack" and child:IsA("Tool") then
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
    if tool.Name == "Sack" and tool:IsA("Tool") then
        onBackpackAdded(tool)
    end
end

-- Handle character spawning
if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Responsive positioning for different screen sizes
local function updateResponsiveLayout()
    local viewportSize = workspace.CurrentCamera.ViewportSize
    
    if viewportSize.X < 800 then
        -- Small screen (mobile/tablet)
        mainFrame.Size = UDim2.new(0, 100, 0, 50)
        mainFrame.Position = UDim2.new(1, -120, 0.5, -25)
        counterLabel.TextSize = 28
        
        if isMobile and mobileFrame then
            mobileFrame.Position = UDim2.new(1, -140, 0.5, 35)
        end
    else
        -- Large screen (desktop)
        mainFrame.Size = UDim2.new(0, 120, 0, 60)
        mainFrame.Position = UDim2.new(1, -140, 0.5, -30)
        counterLabel.TextSize = 36
        
        if isMobile and mobileFrame then
            mobileFrame.Position = UDim2.new(1, -150, 0.5, 40)
        end
    end
end

-- Update layout on viewport size change
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
updateResponsiveLayout()  -- Initial setup

-- Export functions for BackpackController
_G.BackpackUI = {
    updateContents = updateContents,
    showHint = showHint
}