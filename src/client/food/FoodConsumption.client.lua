-- src/client/food/FoodConsumption.client.lua
-- Communicates with server to handle hunger restoration

local Players 				= game:GetService("Players")
local UserInputService 		= game:GetService("UserInputService")
local ContextActionService 	= game:GetService("ContextActionService")
local CollectionService 	= game:GetService("CollectionService")
local ReplicatedStorage 	= game:GetService("ReplicatedStorage")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local EconomyConfig 		= require(ReplicatedStorage.Shared.config.EconomyConfig)

local player 			= Players.LocalPlayer

-- Get ConsumeFood RemoteEvent (defined in default.project.json)
local remotesFolder 	= ReplicatedStorage:WaitForChild("Remotes")
local consumeFoodRemote = remotesFolder:WaitForChild("ConsumeFood")

local FoodConsumption = {}

--=====================================================================

local Config = {
	InteractionDistance = 10,
	InteractionKey = Enum.KeyCode.E,
}

local highlightedFood = nil
local highlight = nil

--=====================================================================

function FoodConsumption.init()
	FoodConsumption.bindInput()
	FoodConsumption.setupFoodHighlighting()
	if _G.SystemLoadMonitor then
		_G.SystemLoadMonitor.reportSystemLoaded("FoodConsumption")
	end
end

function FoodConsumption.bindInput()
	local function handler(actionName, inputState, inputObj)
		if inputState == Enum.UserInputState.Begin then
			-- Check if sack is equipped - if so, pass input to BackpackController
			if FoodConsumption.isSackEquipped() then
				return Enum.ContextActionResult.Pass -- Let BackpackController handle it
			end

			-- Only attempt consumption if we have highlighted food
			if highlightedFood and highlightedFood.Parent then
				FoodConsumption.attemptConsumption()
				return Enum.ContextActionResult.Sink -- We handled it
			else
				-- No food to consume, pass to other handlers
				return Enum.ContextActionResult.Pass
			end
		end
		return Enum.ContextActionResult.Pass
	end
	ContextActionService:BindActionAtPriority(
		"ConsumeFood",
		handler,
		false,
		Enum.ContextActionPriority.Default.Value + 1,
		Config.InteractionKey
	)
end

function FoodConsumption.setupFoodHighlighting()
	highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(0, 255, 0)
	highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.2
	game:GetService("RunService").Heartbeat:Connect(function()
		FoodConsumption.updateHighlight()
	end)
end

function FoodConsumption.updateHighlight()
	if not player.Character or not player.Character.PrimaryPart then
		FoodConsumption.clearHighlight()
		return
	end

	local playerPosition = player.Character.PrimaryPart.Position
	local nearestFood = nil
	local nearestDistance = math.huge

	for _, consumable in pairs(CollectionService:GetTagged(CollectionServiceTags.CONSUMABLE)) do
		if consumable.Parent then
			local candidatePosition = nil
			if consumable:IsA("Model") and consumable.PrimaryPart then
				candidatePosition = consumable.PrimaryPart.Position
			elseif consumable:IsA("BasePart") then
				candidatePosition = consumable.Position
			end
			if candidatePosition then
				local distance = (candidatePosition - playerPosition).Magnitude
				if distance <= Config.InteractionDistance and distance < nearestDistance then
					nearestDistance = distance
					nearestFood = consumable
				end
			end
		end
	end

	if nearestFood ~= highlightedFood then
		if nearestFood then
			FoodConsumption.highlightFood(nearestFood)
		else
			FoodConsumption.clearHighlight()
		end
	end
end

-- Highlight a specific food item
function FoodConsumption.highlightFood(food)
	highlightedFood = food
	if food:IsA("Model") then
		highlight.Parent = food
	elseif food:IsA("BasePart") then
		highlight.Parent = food
	else
		highlight.Parent = nil
	end
	-- You could create a GUI hint here instead of printing
end

function FoodConsumption.clearHighlight()
	highlightedFood = nil
	highlight.Parent = nil
end

-- Helper function to check if sack tool is currently equipped
function FoodConsumption.isSackEquipped()
	if not player.Character then
		return false
	end

	-- Check for equipped Tool
	local equippedTool = player.Character:FindFirstChildOfClass("Tool")
	if equippedTool then
		local toolName = equippedTool.Name:lower()
		local isSack = toolName == "sack"
			or toolName == "backpack"
			or toolName:find("sack")
			or toolName:find("backpack")


		return isSack
	end

	return false
end

function FoodConsumption.attemptConsumption()
	if not highlightedFood or not highlightedFood.Parent then
		return
	end

	-- Proceed with food consumption (sack check now handled in input handler)
	consumeFoodRemote:FireServer(highlightedFood)
	FoodConsumption.clearHighlight()
end

FoodConsumption.init()

return FoodConsumption
