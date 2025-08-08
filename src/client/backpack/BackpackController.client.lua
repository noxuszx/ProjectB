--[[
    BackpackController.client.lua
    Client-side controller for the LIFO Backpack system
    Handles E key for storing and F key for retrieving, plus mobile buttons
]]
--

local UserInputService      = game:GetService("UserInputService")
local ContextActionService  = game:GetService("ContextActionService")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local Players               = game:GetService("Players")

local CS_tags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local player  = Players.LocalPlayer

local BackpackEvent

repeat
	BackpackEvent = ReplicatedStorage.Remotes:FindFirstChild("BackpackEvent")
	if not BackpackEvent then
		task.wait(0.1)
	end
until BackpackEvent

repeat
	task.wait(0.1)
until _G.InteractableHandler


local InteractableHandler = _G.InteractableHandler
local STORE_COOLDOWN = 0.5
local lastStoreTime  = 0
local currentBackpackContents = {}
local lastUIHint     = ""

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function storeCurrentObject()
	local currentTime = os.clock()
	if currentTime - lastStoreTime < STORE_COOLDOWN then
		return
	end

	local target = InteractableHandler.GetCurrentTarget()
	if not target then
		showUIHint("No object selected to store")
		return
	end

	if not CS_tags.hasTag(target, CS_tags.STORABLE) then
		showUIHint("This object cannot be stored")
		return
	end

	lastStoreTime = currentTime
	BackpackEvent:FireServer("RequestStore", target)
end

local function retrieveTopObject()
	local currentTime = os.clock()
	if currentTime - lastStoreTime < STORE_COOLDOWN then
		return
	end

	lastStoreTime = currentTime
	BackpackEvent:FireServer("RequestRetrieve")
end


function showUIHint(message)
	lastUIHint = message
	print("[Backpack]", message)

	if _G.BackpackUI and _G.BackpackUI.showHint then
		_G.BackpackUI.showHint(message)
	end
end


BackpackEvent.OnClientEvent:Connect(function(action, ...)
	local args = { ... }

	if action == "Sync" then
		currentBackpackContents = args[1] or {}
		local uiHint = args[2]

		if uiHint then
			showUIHint(uiHint)
		end

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
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		local character = player.Character
		if character and character:FindFirstChild("Backpack") then
			storeCurrentObject()
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		local character = player.Character
		if character and character:FindFirstChild("Backpack") then
			retrieveTopObject()
		end
	end
end)

local function handleStoreAction(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		local character = player.Character
		if character and character:FindFirstChild("Backpack") then
			storeCurrentObject()
		end
	end
end

ContextActionService:BindAction("StoreObject", handleStoreAction, false, Enum.KeyCode.E)

local function handleRetrieveAction(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		local character = player.Character
		if character and character:FindFirstChild("Backpack") then
			retrieveTopObject()
		end
	end
end

ContextActionService:BindAction("RetrieveObject", handleRetrieveAction, false, Enum.KeyCode.F)

-- Mobile UI buttons (will be created when BackpackUI is implemented)
local function setupMobileButtons()
	if not isMobile then
		return
	end

	-- Mobile buttons will be handled by BackpackUI
	-- This is a placeholder for mobile-specific logic
end

-- Note: Retrieval is now handled by F key, not left click on Backpack tool
-- Tool activation handler removed - using F key instead

-- Initialize
setupMobileButtons()

BackpackEvent:FireServer("RequestSync")

_G.BackpackController = {
	storeCurrentObject = storeCurrentObject,
	retrieveTopObject = retrieveTopObject,
	getBackpackContents = function()
		return currentBackpackContents
	end,
	getLastUIHint = function()
		return lastUIHint
	end,
}
