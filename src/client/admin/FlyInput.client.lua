-- src/client/admin/FlyInput.client.lua
-- Client-side input handler for admin fly system
-- Sends WASD + Space/Shift input to server via RemoteEvent

local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Wait for RemoteEvent to exist
local remote = game.ReplicatedStorage:WaitForChild("AdminFlyControl")

-- Input state
local input = {
    dir     = Vector3.zero,
    ascend  = false,
    descend = false
}

-- Key state tracking
local keys = {
    W = false,
    A = false,
    S = false,
    D = false,
    Space = false,
    LeftShift = false
}

-- Update movement direction based on camera orientation
local function updateMovementDirection()
    local moveVector = Vector3.zero
    
    if keys.W then moveVector += Vector3.new(0, 0, -1) end
    if keys.S then moveVector += Vector3.new(0, 0,  1) end
    if keys.A then moveVector += Vector3.new(-1, 0, 0) end
    if keys.D then moveVector += Vector3.new( 1, 0, 0) end
    
    -- Transform relative to camera orientation
    if moveVector.Magnitude > 0 then
        moveVector = camera.CFrame:VectorToWorldSpace(moveVector).Unit
    end
    
    input.dir = moveVector
    input.ascend = keys.Space
    input.descend = keys.LeftShift
end

-- Handle key press
UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
    if gameProcessed then return end
    
    local keyCode = inputObject.KeyCode
    if keyCode == Enum.KeyCode.W then
        keys.W = true
    elseif keyCode == Enum.KeyCode.A then
        keys.A = true
    elseif keyCode == Enum.KeyCode.S then
        keys.S = true
    elseif keyCode == Enum.KeyCode.D then
        keys.D = true
    elseif keyCode == Enum.KeyCode.Space then
        keys.Space = true
    elseif keyCode == Enum.KeyCode.LeftShift then
        keys.LeftShift = true
    end
    
    updateMovementDirection()
end)

-- Handle key release
UserInputService.InputEnded:Connect(function(inputObject, gameProcessed)
    local keyCode = inputObject.KeyCode
    if keyCode == Enum.KeyCode.W then
        keys.W = false
    elseif keyCode == Enum.KeyCode.A then
        keys.A = false
    elseif keyCode == Enum.KeyCode.S then
        keys.S = false
    elseif keyCode == Enum.KeyCode.D then
        keys.D = false
    elseif keyCode == Enum.KeyCode.Space then
        keys.Space = false
    elseif keyCode == Enum.KeyCode.LeftShift then
        keys.LeftShift = false
    end
    
    updateMovementDirection()
end)

-- Send input to server every frame
RunService.RenderStepped:Connect(function()
    updateMovementDirection()
    remote:FireServer(input)
end)
