-- src/client/admin/AdminUIController.client.lua
-- Client-side admin UI controller
-- Handles UI interactions and sends commands to server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Admin")
local toggleRemote = remotes:WaitForChild("AdminUIToggle")
local commandRemote = remotes:WaitForChild("AdminCommand")
local stateSyncRemote = remotes:WaitForChild("AdminStateSync")
local hideAllUIRemote = remotes:WaitForChild("HideAllUI")

-- Get or create UI elements
local adminUI = playerGui:FindFirstChild("AdminUI")
if not adminUI then
    -- Create the entire UI structure programmatically
    adminUI = Instance.new("ScreenGui")
    adminUI.Name = "AdminUI"
    adminUI.ResetOnSpawn = false
    adminUI.Enabled = false -- Start hidden
    adminUI.Parent = playerGui
    
    -- Main Frame (Fixed smaller size with scrolling)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    -- Fixed size: 320px wide, 450px tall - much smaller than before
    mainFrame.Size = UDim2.new(0, 320, 0, 450)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = adminUI
    
    -- Add UICorner for modern rounded corners
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame
    
    -- Add UIStroke for border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0.3, 0.3, 0.3)
    stroke.Thickness = 2
    stroke.Parent = mainFrame
    
    -- Header Frame for title and close button (fixed at top)
    local headerFrame = Instance.new("Frame")
    headerFrame.Name = "Header"
    headerFrame.Size = UDim2.new(1, 0, 0, 40)
    headerFrame.Position = UDim2.new(0, 0, 0, 0)
    headerFrame.BackgroundTransparency = 1
    headerFrame.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Admin Panel"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = headerFrame
    
    -- Close Button (responsive)
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 35, 0, 35)
    closeButton.Position = UDim2.new(1, -35, 0, 0)
    closeButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = headerFrame
    
    -- Add corner to close button
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    -- ScrollingFrame for all content below header
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ContentScroll"
    scrollFrame.Size = UDim2.new(1, 0, 1, -50) -- Full width, height minus header and padding
    scrollFrame.Position = UDim2.new(0, 0, 0, 45) -- Below header with small gap
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.new(0.5, 0.5, 0.5)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will be set by AutomaticCanvasSize
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.Parent = mainFrame
    
    -- Add UIListLayout for automatic spacing in scroll frame
    local scrollLayout = Instance.new("UIListLayout")
    scrollLayout.FillDirection = Enum.FillDirection.Vertical
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.Padding = UDim.new(0, 8)
    scrollLayout.Parent = scrollFrame
    
    -- Add UIPadding for consistent margins in scroll frame
    local scrollPadding = Instance.new("UIPadding")
    scrollPadding.PaddingTop = UDim.new(0, 8)
    scrollPadding.PaddingBottom = UDim.new(0, 15)
    scrollPadding.PaddingLeft = UDim.new(0, 15)
    scrollPadding.PaddingRight = UDim.new(0, 15)
    scrollPadding.Parent = scrollFrame
    
    -- Helper function to create responsive sections
    local function createSection(name, title, layoutOrder, buttonData)
        local sectionFrame = Instance.new("Frame")
        sectionFrame.Name = name
        sectionFrame.Size = UDim2.new(1, 0, 0, 0) -- AutomaticSize will handle height
        sectionFrame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
        sectionFrame.BorderSizePixel = 0
        sectionFrame.LayoutOrder = layoutOrder
        sectionFrame.Parent = scrollFrame
        
        -- Section corner
        local sectionCorner = Instance.new("UICorner")
        sectionCorner.CornerRadius = UDim.new(0, 8)
        sectionCorner.Parent = sectionFrame
        
        -- Section stroke
        local sectionStroke = Instance.new("UIStroke")
        sectionStroke.Color = Color3.new(0.4, 0.4, 0.4)
        sectionStroke.Thickness = 1
        sectionStroke.Parent = sectionFrame
        
        -- Section layout
        local sectionLayout = Instance.new("UIListLayout")
        sectionLayout.FillDirection = Enum.FillDirection.Vertical
        sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
        sectionLayout.Padding = UDim.new(0, 6)
        sectionLayout.Parent = sectionFrame
        
        -- Section padding
        local sectionPadding = Instance.new("UIPadding")
        sectionPadding.PaddingTop = UDim.new(0, 10)
        sectionPadding.PaddingBottom = UDim.new(0, 10)
        sectionPadding.PaddingLeft = UDim.new(0, 10)
        sectionPadding.PaddingRight = UDim.new(0, 10)
        sectionPadding.Parent = sectionFrame
        
        -- AutomaticSize for responsive height
        sectionFrame.AutomaticSize = Enum.AutomaticSize.Y
        
        -- Section title
        local sectionTitle = Instance.new("TextLabel")
        sectionTitle.Name = "SectionTitle"
        sectionTitle.Size = UDim2.new(1, 0, 0, 25)
        sectionTitle.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
        sectionTitle.Text = title
        sectionTitle.TextColor3 = Color3.new(1, 1, 1)
        sectionTitle.TextScaled = true
        sectionTitle.Font = Enum.Font.GothamBold
        sectionTitle.LayoutOrder = 1
        sectionTitle.Parent = sectionFrame
        
        -- Title corner
        local titleCorner = Instance.new("UICorner")
        titleCorner.CornerRadius = UDim.new(0, 4)
        titleCorner.Parent = sectionTitle
        
        return sectionFrame
    end
    
    -- Helper function to create responsive button grid
    local function createButtonGrid(parent, buttons, columns)
        local gridFrame = Instance.new("Frame")
        gridFrame.Name = "ButtonGrid"
        gridFrame.Size = UDim2.new(1, 0, 0, 0)
        gridFrame.BackgroundTransparency = 1
        gridFrame.LayoutOrder = 2
        gridFrame.AutomaticSize = Enum.AutomaticSize.Y
        gridFrame.Parent = parent
        
        -- Grid layout
        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.CellSize = UDim2.new(1/columns, -4, 0, 40)
        gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
        gridLayout.FillDirection = Enum.FillDirection.Horizontal
        gridLayout.Parent = gridFrame
        
        -- Create buttons
        for _, btn in ipairs(buttons) do
            local button = Instance.new("TextButton")
            button.Name = btn.name
            button.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
            button.Text = btn.text
            button.TextColor3 = Color3.new(1, 1, 1)
            button.TextScaled = true
            button.Font = Enum.Font.Gotham
            button.Parent = gridFrame
            
            -- Button corner
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 6)
            buttonCorner.Parent = button
            
            -- Button stroke for better definition
            local buttonStroke = Instance.new("UIStroke")
            buttonStroke.Color = Color3.new(0.5, 0.5, 0.5)
            buttonStroke.Thickness = 1
            buttonStroke.Parent = button
        end
        
        return gridFrame
    end
    
    -- Movement Section
    local movementFrame = createSection("Movement", "Movement", 2, nil)
    local movementButtons = {
        {name = "FlyButton", text = "Fly"},
        {name = "NoclipButton", text = "Noclip"},
        {name = "GodButton", text = "God Mode"},
        {name = "KillButton", text = "Kill"}
    }
    createButtonGrid(movementFrame, movementButtons, 2)
    
    -- Time Section
    local timeFrame = createSection("Time", "Time Control", 3, nil)
    local timeButtons = {
        {name = "DawnButton", text = "Dawn"},
        {name = "NoonButton", text = "Noon"},
        {name = "DuskButton", text = "Dusk"},
        {name = "NightButton", text = "Night"},
        {name = "NextButton", text = "Next"}
    }
    createButtonGrid(timeFrame, timeButtons, 3) -- 3 columns for time buttons
    
    -- Economy Section
    local economyFrame = createSection("Economy", "Economy", 4, nil)
    
    -- Money input field
    local moneyInput = Instance.new("TextBox")
    moneyInput.Name = "MoneyInput"
    moneyInput.Size = UDim2.new(1, 0, 0, 35)
    moneyInput.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    moneyInput.Text = ""
    moneyInput.PlaceholderText = "Amount"
    moneyInput.TextColor3 = Color3.new(1, 1, 1)
    moneyInput.TextScaled = true
    moneyInput.Font = Enum.Font.Gotham
    moneyInput.LayoutOrder = 2
    moneyInput.Parent = economyFrame
    
    -- Input corner
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = moneyInput
    
    -- Input stroke
    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.new(0.5, 0.5, 0.5)
    inputStroke.Thickness = 1
    inputStroke.Parent = moneyInput
    
    -- Economy buttons
    local economyButtons = {
        {name = "SetMoneyButton", text = "Set Money"},
        {name = "GiveMoneyButton", text = "Give Money"}
    }
    createButtonGrid(economyFrame, economyButtons, 2)
    
    -- Arena Section
    local arenaFrame = createSection("Arena", "Arena", 5, nil)
    local arenaButtons = {
        {name = "StartButton", text = "Start"},
        {name = "PauseButton", text = "Pause"},
        {name = "ResumeButton", text = "Resume"},
        {name = "VictoryButton", text = "Victory"},
        {name = "DoorButton", text = "Door"},
        {name = "StateButton", text = "State"},
        {name = "TpButton", text = "TP"}
    }
    createButtonGrid(arenaFrame, arenaButtons, 4) -- 4 columns for arena buttons
    
    print("[AdminUIController] Created AdminUI programmatically")
end

local mainFrame = adminUI:WaitForChild("MainFrame")

-- UI Elements
local headerFrame = mainFrame:WaitForChild("Header")
local closeButton = headerFrame:WaitForChild("CloseButton")
local scrollFrame = mainFrame:WaitForChild("ContentScroll")

-- Movement section
local movementFrame = scrollFrame:WaitForChild("Movement")
local movementGrid = movementFrame:WaitForChild("ButtonGrid")
local flyButton = movementGrid:WaitForChild("FlyButton")
local noclipButton = movementGrid:WaitForChild("NoclipButton")
local godButton = movementGrid:WaitForChild("GodButton")
local killButton = movementGrid:WaitForChild("KillButton")

-- Time section
local timeFrame = scrollFrame:WaitForChild("Time")
local timeGrid = timeFrame:WaitForChild("ButtonGrid")
local dawnButton = timeGrid:WaitForChild("DawnButton")
local noonButton = timeGrid:WaitForChild("NoonButton")
local duskButton = timeGrid:WaitForChild("DuskButton")
local nightButton = timeGrid:WaitForChild("NightButton")
local nextButton = timeGrid:WaitForChild("NextButton")

-- Economy section
local economyFrame = scrollFrame:WaitForChild("Economy")
local moneyInput = economyFrame:WaitForChild("MoneyInput")
local economyGrid = economyFrame:WaitForChild("ButtonGrid")
local setMoneyButton = economyGrid:WaitForChild("SetMoneyButton")
local giveMoneyButton = economyGrid:WaitForChild("GiveMoneyButton")

-- Arena section
local arenaFrame = scrollFrame:WaitForChild("Arena")
local arenaGrid = arenaFrame:WaitForChild("ButtonGrid")
local startButton = arenaGrid:WaitForChild("StartButton")
local pauseButton = arenaGrid:WaitForChild("PauseButton")
local resumeButton = arenaGrid:WaitForChild("ResumeButton")
local victoryButton = arenaGrid:WaitForChild("VictoryButton")
local doorButton = arenaGrid:WaitForChild("DoorButton")
local stateButton = arenaGrid:WaitForChild("StateButton")
local tpButton = arenaGrid:WaitForChild("TpButton")

-- State tracking for toggle buttons
local adminState = {
    flying = false,
    noclip = false,
    god = false
}

---------------------------------------------------------------------
-- UI MANAGEMENT ---------------------------------------------------
---------------------------------------------------------------------

-- Initially hide the UI
adminUI.Enabled = false

-- Toggle Admin panel visibility only
local function toggleUI()
    adminUI.Enabled = not adminUI.Enabled
    
    -- Add a smooth fade-in effect
    if adminUI.Enabled then
        -- Start from center point with 0 size
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        
        local tween = TweenService:Create(
            mainFrame,
            TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {
                Size = UDim2.new(0, 320, 0, 450) -- Fixed final size
            }
        )
        tween:Play()
    end
end

-- Hide/show all UI (CoreGui + all ScreenGuis)
local StarterGui = game:GetService("StarterGui")
local allUIVisible = true

local function setAllUIVisible(visible: boolean)
    allUIVisible = visible
    -- Core UI
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, visible)
    end)
    -- Custom UI in PlayerGui
    for _, child in ipairs(playerGui:GetChildren()) do
        if child:IsA("ScreenGui") then
            child.Enabled = visible
        end
    end
end

local function applyAllUIMode(mode: string)
    if mode == "on" then
        setAllUIVisible(true)
    elseif mode == "off" then
        setAllUIVisible(false)
    else -- "toggle" or anything else
        setAllUIVisible(not allUIVisible)
    end
end

-- Safety hotkeys: F8 forces UI ON, F7 toggles all UI
local RESTORE_KEY = Enum.KeyCode.F8
local TOGGLE_ALL_KEY = Enum.KeyCode.F7

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == RESTORE_KEY then
        setAllUIVisible(true)
    elseif input.KeyCode == TOGGLE_ALL_KEY then
        setAllUIVisible(not allUIVisible)
    end
end)

---------------------------------------------------------------------
-- Update button states based on admin state
local function updateButtonStates()
    flyButton.Text = adminState.flying and "Unfly" or "Fly"
    flyButton.BackgroundColor3 = adminState.flying and Color3.new(0.2, 0.8, 0.2) or Color3.new(0.3, 0.3, 0.3)
    
    noclipButton.Text = adminState.noclip and "Clip" or "Noclip"
    noclipButton.BackgroundColor3 = adminState.noclip and Color3.new(0.2, 0.8, 0.2) or Color3.new(0.3, 0.3, 0.3)
    
    godButton.Text = adminState.god and "Ungod" or "God Mode"
    godButton.BackgroundColor3 = adminState.god and Color3.new(0.2, 0.8, 0.2) or Color3.new(0.3, 0.3, 0.3)
end

---------------------------------------------------------------------
-- COMMAND FUNCTIONS -----------------------------------------------
---------------------------------------------------------------------

local function sendCommand(command, args)
    commandRemote:FireServer(command, args)
end

-- Movement commands
flyButton.Activated:Connect(function()
    sendCommand(adminState.flying and "unfly" or "fly")
end)

noclipButton.Activated:Connect(function()
    sendCommand(adminState.noclip and "clip" or "noclip")
end)

godButton.Activated:Connect(function()
    sendCommand(adminState.god and "ungod" or "god")
end)

killButton.Activated:Connect(function()
    sendCommand("kill")
end)

-- Time commands
dawnButton.Activated:Connect(function()
    sendCommand("time", "dawn")
end)

noonButton.Activated:Connect(function()
    sendCommand("time", "noon")
end)

duskButton.Activated:Connect(function()
    sendCommand("time", "dusk")
end)

nightButton.Activated:Connect(function()
    sendCommand("time", "night")
end)

nextButton.Activated:Connect(function()
    sendCommand("time", "next")
end)

-- Economy commands
setMoneyButton.Activated:Connect(function()
    local amount = tonumber(moneyInput.Text)
    if amount and amount >= 0 then
        sendCommand("money", "set " .. tostring(math.floor(amount)))
        moneyInput.Text = ""
    else
        moneyInput.Text = "Invalid amount"
        wait(1)
        moneyInput.Text = ""
    end
end)

giveMoneyButton.Activated:Connect(function()
    local amount = tonumber(moneyInput.Text)
    if amount and amount > 0 then
        sendCommand("givemoney", tostring(math.floor(amount)))
        moneyInput.Text = ""
    else
        moneyInput.Text = "Invalid amount"
        wait(1)
        moneyInput.Text = ""
    end
end)

-- Arena commands
startButton.Activated:Connect(function()
    sendCommand("arena", "start")
end)

pauseButton.Activated:Connect(function()
    sendCommand("arena", "pause")
end)

resumeButton.Activated:Connect(function()
    sendCommand("arena", "resume")
end)

victoryButton.Activated:Connect(function()
    sendCommand("arena", "victory")
end)

doorButton.Activated:Connect(function()
    sendCommand("arena", "door")
end)

stateButton.Activated:Connect(function()
    sendCommand("arena", "state")
end)

tpButton.Activated:Connect(function()
    sendCommand("arena", "tp")
end)

-- Close button
closeButton.Activated:Connect(function()
    adminUI.Enabled = false
end)

---------------------------------------------------------------------
-- REMOTE EVENT HANDLERS -------------------------------------------
---------------------------------------------------------------------

-- Handle UI toggle from server (Admin Panel only)
toggleRemote.OnClientEvent:Connect(function()
    toggleUI()
end)

-- Handle hide/show all UI from server
hideAllUIRemote.OnClientEvent:Connect(function(mode)
    applyAllUIMode(mode)
end)

-- Handle state sync from server
stateSyncRemote.OnClientEvent:Connect(function(newState)
    adminState = newState
    updateButtonStates()
end)

-- Initialize button states
updateButtonStates()

print("[AdminUIController] Admin UI system initialized")
