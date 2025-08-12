-- src/client/SprintController.client.lua
-- Adds sprinting (hold Shift on desktop; touch button on mobile) by adjusting Humanoid.WalkSpeed
-- Uses ContextActionUtility to place the mobile button near the Jump button's top-right.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local IS_MOBILE = UserInputService.TouchEnabled

-- Config
local NORMAL_SPEED = 16
local SPRINT_SPEED = 24
local ACTION_NAME = "Sprint"

-- Utilities
local ContextActionUtility
local function initUtils()
    local ok, mod = pcall(function()
        return require(ReplicatedStorage.Shared.modules.ContextActionUtility)
    end)
    if ok then ContextActionUtility = mod return end
end
initUtils()

-- State
local humanoid: Humanoid? = nil
local sprinting = false

-- Update movement speed
local function applySpeed()
    if humanoid then
        humanoid.WalkSpeed = sprinting and SPRINT_SPEED or NORMAL_SPEED
    end
end

-- Ensure speed reset on death/respawn
local function onCharacterAdded(char: Model)
    humanoid = char:WaitForChild("Humanoid")
    sprinting = false
    applySpeed()

    humanoid.Died:Once(function()
        sprinting = false
        applySpeed()
    end)
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

-- Input handler for sprint
local function onSprintAction(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        sprinting = true
        applySpeed()
    elseif inputState == Enum.UserInputState.End then
        sprinting = false
        applySpeed()
    end
end

-- Bind inputs
local function bindInputs()
    if IS_MOBILE then
        -- Use the provided ContextActionUtility to create and manage a mobile button near Jump.
        if ContextActionUtility then
            ContextActionUtility:BindAction(ACTION_NAME, onSprintAction, true, Enum.KeyCode.LeftShift)
            -- Label the button for clarity
            task.defer(function()
                pcall(function()
                    ContextActionUtility:SetTitle(ACTION_NAME, "Sprint")
                end)
            end)
        else
            -- Fallback: bind with CAS and let Roblox place a default button.
            ContextActionService:BindAction(ACTION_NAME, onSprintAction, true, Enum.KeyCode.LeftShift)
        end
    else
        -- Desktop binding (no touch button)
        ContextActionService:BindAction(ACTION_NAME, onSprintAction, false, Enum.KeyCode.LeftShift)
    end
end

bindInputs()

