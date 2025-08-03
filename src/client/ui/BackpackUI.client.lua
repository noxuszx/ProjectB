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

-- Create main UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BackpackUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Main frame - responsive positioning
local mainFrame = Instance.new("Frame")
mainFrame.Name = "BackpackFrame"
mainFrame.Size = UDim2.new(0, 120, 0, 60)  -- Smaller since only counter
mainFrame.Position = UDim2.new(1, -140, 0.5, -30)  -- Middle-right with margin
mainFrame.BackgroundTransparency = 1  -- Completely transparent (no background)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

-- Counter label (centered, bigger, with black outline)
local counterLabel = Instance.new("TextLabel")
counterLabel.Name = "Counter"
counterLabel.Size = UDim2.new(1, 0, 1, 0)  -- Take full frame size
counterLabel.Position = UDim2.new(0, 0, 0, 0)  -- Centered in frame
counterLabel.BackgroundTransparency = 1
counterLabel.Text = "0/10"
counterLabel.TextColor3 = Color3.new(1, 1, 1)  -- Pure white text
counterLabel.TextSize = 36  -- Much bigger
counterLabel.Font = Enum.Font.FredokaOne
counterLabel.TextXAlignment = Enum.TextXAlignment.Center  -- Center aligned
counterLabel.TextYAlignment = Enum.TextYAlignment.Center  -- Vertically centered
counterLabel.TextStrokeTransparency = 0  -- Enable stroke/outline
counterLabel.TextStrokeColor3 = Color3.new(0, 0, 0)  -- Black outline
counterLabel.Parent = mainFrame

-- Mobile buttons (only show on mobile when Sack is equipped)
local mobileFrame = nil
if isMobile then
    mobileFrame = Instance.new("Frame")
    mobileFrame.Name = "MobileButtons"
    mobileFrame.Size = UDim2.new(0, 130, 0, 40)
    mobileFrame.Position = UDim2.new(1, -280, 0.5, 60)  -- Below the counter in middle-right
    mobileFrame.BackgroundTransparency = 1
    mobileFrame.Visible = false  -- Hidden by default
    mobileFrame.Parent = screenGui
    
    -- Store button
    local storeButton = Instance.new("TextButton")
    storeButton.Name = "StoreButton"
    storeButton.Size = UDim2.new(0, 60, 0, 35)
    storeButton.Position = UDim2.new(0, 0, 0, 0)
    storeButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
    storeButton.Text = "Store"
    storeButton.TextColor3 = Color3.new(1, 1, 1)
    storeButton.TextSize = 14
    storeButton.Font = Enum.Font.FredokaOne
    storeButton.Parent = mobileFrame
    
    local storeCorner = Instance.new("UICorner")
    storeCorner.CornerRadius = UDim.new(0, 6)
    storeCorner.Parent = storeButton
    
    -- Retrieve button
    local retrieveButton = Instance.new("TextButton")
    retrieveButton.Name = "RetrieveButton"
    retrieveButton.Size = UDim2.new(0, 60, 0, 35)
    retrieveButton.Position = UDim2.new(0, 70, 0, 0)
    retrieveButton.BackgroundColor3 = Color3.new(0.6, 0.2, 0.2)
    retrieveButton.Text = "Take"
    retrieveButton.TextColor3 = Color3.new(1, 1, 1)
    retrieveButton.TextSize = 14
    retrieveButton.Font = Enum.Font.FredokaOne
    retrieveButton.Parent = mobileFrame
    
    local retrieveCorner = Instance.new("UICorner")
    retrieveCorner.CornerRadius = UDim.new(0, 6)
    retrieveCorner.Parent = retrieveButton
    
    -- Button connections (wait for BackpackController)
    spawn(function()
        repeat wait(0.1) until _G.BackpackController
        
        storeButton.MouseButton1Click:Connect(function()
            _G.BackpackController.storeCurrentObject()
        end)
        
        retrieveButton.MouseButton1Click:Connect(function()
            _G.BackpackController.retrieveTopObject()
        end)
    end)
end

-- Hint message display (positioned better for mobile)
local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.new(0, 250, 0, 30)
hintLabel.Position = UDim2.new(0.5, -125, 0, 50)
hintLabel.BackgroundColor3 = Color3.new(0, 0, 0)
hintLabel.BackgroundTransparency = 0.3
hintLabel.Text = ""
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 14
hintLabel.Font = Enum.Font.SourceSans
hintLabel.Visible = false
hintLabel.Parent = screenGui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 6)
hintCorner.Parent = hintLabel

-- State tracking
local currentItemCount = 0
local sackEquipped = false

-- Show hint message with fade
local function showHint(message)
    hintLabel.Text = message
    hintLabel.Visible = true
    hintLabel.BackgroundTransparency = 0.3
    hintLabel.TextTransparency = 0
    
    -- Fade out after 2 seconds
    spawn(function()
        wait(2)
        
        local fadeInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local fadeTween = TweenService:Create(hintLabel, fadeInfo, {
            BackgroundTransparency = 1,
            TextTransparency = 1
        })
        
        fadeTween:Play()
        fadeTween.Completed:Connect(function()
            hintLabel.Visible = false
        end)
    end)
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

-- Monitor backpack for Sack tool
player.Backpack.ChildAdded:Connect(onBackpackAdded)

-- Check existing tools in backpack
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