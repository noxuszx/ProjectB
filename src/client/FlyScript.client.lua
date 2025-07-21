-- Simple Flying Script - Press G to toggle

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local flying = false
local bodyVelocity = nil
local flySpeed = 80

-- Toggle flying
local function toggleFly()
    flying = not flying
    
    if flying then
        -- Start flying
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        print("Flying ON")
    else
        -- Stop flying
        if bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
        print("Flying OFF")
    end
end

-- Update movement
local function updateMovement()
    if not flying or not bodyVelocity then return end
    
    local camera = workspace.CurrentCamera
    local velocity = Vector3.new(0, 0, 0)
    
    -- Simple directional movement
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        velocity = velocity + camera.CFrame.LookVector * flySpeed
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        velocity = velocity - camera.CFrame.LookVector * flySpeed
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        velocity = velocity - camera.CFrame.RightVector * flySpeed
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        velocity = velocity + camera.CFrame.RightVector * flySpeed
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        velocity = velocity + Vector3.new(0, flySpeed, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        velocity = velocity - Vector3.new(0, flySpeed, 0)
    end
    
    bodyVelocity.Velocity = velocity
end

-- Input handling
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.G then
        toggleFly()
    end
end)

-- Update every frame
RunService.Heartbeat:Connect(updateMovement)

-- Handle respawn
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    rootPart = character:WaitForChild("HumanoidRootPart")
    flying = false
    bodyVelocity = nil
end)
