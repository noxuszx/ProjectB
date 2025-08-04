--[[
    BackpackController.client.lua
    Client-side controller for the LIFO sack system
    Handles E key for storing and F key for retrieving, plus mobile buttons
]]--

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CS_tags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local player = Players.LocalPlayer

-- Wait for BackpackEvent and InteractableHandler
local BackpackEvent
repeat
    BackpackEvent = ReplicatedStorage.Remotes:FindFirstChild("BackpackEvent")
    if not BackpackEvent then
        wait(0.1)
    end
until BackpackEvent

-- Wait for InteractableHandler to be available
repeat
    wait(0.1)
until _G.InteractableHandler

local InteractableHandler = _G.InteractableHandler

-- Configuration
local STORE_COOLDOWN = 0.5
local lastStoreTime = 0

-- State
local currentBackpackContents = {}
local lastUIHint = ""

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Store the currently highlighted object
local function storeCurrentObject()
    local currentTime = tick()
    if currentTime - lastStoreTime < STORE_COOLDOWN then
        return -- Cooldown active
    end
    
    local target = InteractableHandler.GetCurrentTarget()
    if not target then
        showUIHint("No object selected to store")
        return
    end
    
    -- Check if object is storable
    if not CS_tags.hasTag(target, CS_tags.STORABLE) then
        showUIHint("This object cannot be stored")
        return
    end
    
    lastStoreTime = currentTime
    BackpackEvent:FireServer("RequestStore", target)
end

-- Retrieve the top object from backpack
local function retrieveTopObject()
    local currentTime = tick()
    if currentTime - lastStoreTime < STORE_COOLDOWN then
        return -- Cooldown active
    end
    
    lastStoreTime = currentTime
    BackpackEvent:FireServer("RequestRetrieve")
end

-- Show UI hint message
function showUIHint(message)
    lastUIHint = message
    print("[Backpack]", message) -- Console backup
    
    -- Show in actual UI if available
    if _G.BackpackUI and _G.BackpackUI.showHint then
        _G.BackpackUI.showHint(message)
    end
end

-- Handle server responses
BackpackEvent.OnClientEvent:Connect(function(action, ...)
    local args = {...}
    
    if action == "Sync" then
        currentBackpackContents = args[1] or {}
        local uiHint = args[2]
        
        if uiHint then
            showUIHint(uiHint)
        end
        
        -- Update UI when BackpackUI exists
        if _G.BackpackUI then
            _G.BackpackUI.updateContents(currentBackpackContents)
        end
        
    elseif action == "Error" then
        local errorMessage = args[1] or "Unknown error"
        showUIHint(errorMessage)
    end
end)

-- Keyboard input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.E then
        storeCurrentObject()
    elseif input.KeyCode == Enum.KeyCode.F then
        -- Only allow F key retrieval when Sack is equipped
        local character = player.Character
        if character and character:FindFirstChild("Sack") then
            retrieveTopObject()
        end
    end
end)

-- Context action for E key (supports both keyboard and gamepad)
local function handleStoreAction(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        storeCurrentObject()
    end
end

ContextActionService:BindAction("StoreObject", handleStoreAction, false, Enum.KeyCode.E)

-- Context action for F key (retrieve)
local function handleRetrieveAction(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        -- Only allow F key retrieval when Sack is equipped
        local character = player.Character
        if character and character:FindFirstChild("Sack") then
            retrieveTopObject()
        end
    end
end

ContextActionService:BindAction("RetrieveObject", handleRetrieveAction, false, Enum.KeyCode.F)

-- Mobile UI buttons (will be created when BackpackUI is implemented)
local function setupMobileButtons()
    if not isMobile then return end
    
    -- Mobile buttons will be handled by BackpackUI
    -- This is a placeholder for mobile-specific logic
end

-- Note: Retrieval is now handled by F key, not left click on Sack tool
-- Tool activation handler removed - using F key instead

-- Initialize
setupMobileButtons()

-- Request initial sync
BackpackEvent:FireServer("RequestSync")

-- Export for UI integration
_G.BackpackController = {
    storeCurrentObject = storeCurrentObject,
    retrieveTopObject = retrieveTopObject,
    getBackpackContents = function() return currentBackpackContents end,
    getLastUIHint = function() return lastUIHint end
}