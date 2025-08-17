--[[
    Crosshair.client.lua
    Simple dot crosshair that appears only in first person mode
    Also hides mouse cursor in first person for cleaner aiming
]]--

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Create crosshair UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CrosshairUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Crosshair dot
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.Size = UDim2.new(0, 4, 0, 4)  -- 4x4 pixel dot (smaller)
crosshair.Position = UDim2.new(0.5, -2, 0.5, -2)  -- Centered
crosshair.BackgroundColor3 = Color3.new(1, 1, 1)  -- White
crosshair.BorderSizePixel = 0
crosshair.Visible = false
crosshair.Parent = screenGui

-- Add rounded corners for smoother dot
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 2)  -- Makes it circular
corner.Parent = crosshair

-- Add stroke
local stroke = Instance.new("UIStroke")
stroke.Thickness = 1.5
stroke.Transparency = 0.6
stroke.Color = Color3.new(0, 0, 0)  -- Black stroke
stroke.Parent = crosshair


local function isFirstPerson()
    local character = player.Character
    if not character then return false end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return false end

    if camera.CameraSubject == humanoid then
        local head = character:FindFirstChild("Head")
        if head then
            local distance = (camera.CFrame.Position - head.Position).Magnitude
            return distance < 1
        end
    end
    
    return false
end

-- Update crosshair visibility and mouse cursor
local function updateCrosshair()
    if not player.Character then
        crosshair.Visible = false
        UserInputService.MouseIconEnabled = true
        return
    end
    
    local inFirstPerson = isFirstPerson()
    crosshair.Visible = inFirstPerson
    
    -- Hide mouse cursor in first person, show in third person
    UserInputService.MouseIconEnabled = not inFirstPerson
end

-- Monitor camera changes
local connection
connection = RunService.Heartbeat:Connect(updateCrosshair)

-- Clean up when player leaves
player.CharacterRemoving:Connect(function()
    crosshair.Visible = false
    UserInputService.MouseIconEnabled = true  -- Restore cursor
end)

player.CharacterAdded:Connect(function()
    -- Short delay to let character load
    wait(0.1)
    updateCrosshair()
end)

-- Initial update
if player.Character then
    updateCrosshair()
end

if _G.SystemLoadMonitor then
	_G.SystemLoadMonitor.reportSystemLoaded("Crosshair")
end