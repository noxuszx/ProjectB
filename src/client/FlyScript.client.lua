-- Simple Flying Script - Press G to toggle

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character
local rootPart
local humanoid

local flying = false
local bodyVelocity = nil
local flySpeed = 80

-- Toggle flying
local function toggleFly()
    if not humanoid or humanoid.Health <= 0 then return end

    flying = not flying
    
    if flying then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        print("Flying ON")
    else
        if bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
        print("Flying OFF")
    end
end

-- Update movement
local function updateMovement()
    if not flying or not bodyVelocity or not rootPart then return end
    
    local camera = workspace.CurrentCamera
    local moveVector = Vector3.new(0, 0, 0)
    
    -- Get directional input
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveVector = moveVector + Vector3.new(0, 0, -1)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveVector = moveVector + Vector3.new(0, 0, 1)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveVector = moveVector + Vector3.new(-1, 0, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveVector = moveVector + Vector3.new(1, 0, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveVector = moveVector + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        moveVector = moveVector + Vector3.new(0, -1, 0)
    end

    if moveVector.Magnitude > 0 then
        moveVector = camera.CFrame:VectorToWorldSpace(moveVector.Unit)
    end

    bodyVelocity.Velocity = moveVector * flySpeed
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end -- Ignore if typing in chat
    if input.KeyCode == Enum.KeyCode.G then
        toggleFly()
    end
end)

local function setupCharacter(newCharacter)
    character = newCharacter
    rootPart = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")

    -- Ensure flying is disabled on respawn
    if flying then
        toggleFly() 
    end

    -- When the character dies, clean up the velocity
    humanoid.Died:Connect(function()
        if bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
        flying = false
    end)
end


RunService.Heartbeat:Connect(updateMovement)
player.CharacterAdded:Connect(setupCharacter)

if player.Character then
    setupCharacter(player.Character)
end


