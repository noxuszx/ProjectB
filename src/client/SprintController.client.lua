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
local sprintToggled = false

local function applySpeed()
    if humanoid then
        humanoid.WalkSpeed = sprinting and SPRINT_SPEED or NORMAL_SPEED
    end
end

local function updateButtonAppearance()
    if IS_MOBILE and ContextActionUtility then
        pcall(function()
            local buttonText = sprintToggled and "ON" or "Sprint"
            ContextActionUtility:SetTitle(ACTION_NAME, buttonText)
            
            if sprintToggled then
                ContextActionUtility:SetReleasedColor(ACTION_NAME, Color3.fromRGB(0, 255, 0))
                ContextActionUtility:SetPressedColor(ACTION_NAME, Color3.fromRGB(0, 200, 0))
            else
                ContextActionUtility:SetReleasedColor(ACTION_NAME, Color3.fromRGB(255, 255, 255))
                ContextActionUtility:SetPressedColor(ACTION_NAME, Color3.fromRGB(125, 125, 125))
            end
        end)
    end
end

local function onCharacterAdded(char: Model)
    humanoid = char:WaitForChild("Humanoid")
    sprinting = false
    sprintToggled = false
    applySpeed()
    updateButtonAppearance()

    humanoid.Died:Once(function()
        sprinting = false
        sprintToggled = false
        applySpeed()
        updateButtonAppearance()
    end)
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

local function onSprintAction(actionName, inputState, inputObject)
    if IS_MOBILE then
        -- Mobile: Toggle mode on button press
        if inputState == Enum.UserInputState.Begin then
            sprintToggled = not sprintToggled
            sprinting = sprintToggled
            applySpeed()
            updateButtonAppearance()
        end
    else
        -- Desktop: Hold mode
        if inputState == Enum.UserInputState.Begin then
            sprinting = true
            applySpeed()
        elseif inputState == Enum.UserInputState.End then
            sprinting = false
            applySpeed()
        end
    end
end

-- Bind inputs
local function bindInputs()
    if IS_MOBILE then
        if ContextActionUtility then
            ContextActionUtility:BindAction(ACTION_NAME, onSprintAction, true, Enum.KeyCode.LeftShift)
            task.defer(function()
                updateButtonAppearance()
                
                local button = ContextActionUtility:GetButton(ACTION_NAME)
                if button then
                    button.Size = UDim2.new(0.6, 0, 0.6, 0)
                    button.Position = UDim2.new(0.728, 0, -1.89, 0)
                    
                    ContextActionUtility:MakeButtonRound(ACTION_NAME, 0.3)
                end
            end)
        else
            ContextActionService:BindAction(ACTION_NAME, onSprintAction, true, Enum.KeyCode.LeftShift)
        end
    else
        ContextActionService:BindAction(ACTION_NAME, onSprintAction, false, Enum.KeyCode.LeftShift)
    end
end

bindInputs()

