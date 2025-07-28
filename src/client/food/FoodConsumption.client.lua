-- src/client/food/FoodConsumption.client.lua
-- Handles food consumption with E key interaction
-- Communicates with server to handle hunger restoration

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Create RemoteEvent for food consumption
local consumeFoodRemote = ReplicatedStorage:WaitForChild("ConsumeFood", 10)
if not consumeFoodRemote then
	-- Create the RemoteEvent if it doesn't exist
	consumeFoodRemote = Instance.new("RemoteEvent")
	consumeFoodRemote.Name = "ConsumeFood"
	consumeFoodRemote.Parent = ReplicatedStorage
end

local FoodConsumption = {}

-- Configuration
local Config = {
	InteractionDistance = 10, -- Maximum distance to consume food
	InteractionKey = Enum.KeyCode.E
}

-- Currently highlighted food (for UI feedback)
local highlightedFood = nil
local selectionBox = nil

-- Initialize the consumption system
function FoodConsumption.init()
	print("[FoodConsumption] Initializing food consumption system...")
	
	-- Set up input handling
	UserInputService.InputBegan:Connect(FoodConsumption.onInputBegan)
	
	-- Set up food highlighting
	FoodConsumption.setupFoodHighlighting()
	
	print("[FoodConsumption] Food consumption system ready!")
end

-- Handle input events
function FoodConsumption.onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Config.InteractionKey then
		FoodConsumption.attemptConsumption()
	end
end

-- Set up food highlighting system
function FoodConsumption.setupFoodHighlighting()
	-- Create selection box for highlighting
	selectionBox = Instance.new("SelectionBox")
	selectionBox.Color3 = Color3.fromRGB(0, 255, 0) -- Green highlight
	selectionBox.Transparency = 0.7
	selectionBox.Parent = workspace -- SelectionBox should be parented to workspace
	
	-- Update highlighting every frame
	game:GetService("RunService").Heartbeat:Connect(function()
		FoodConsumption.updateHighlight()
	end)
end

-- Update food highlighting based on proximity
function FoodConsumption.updateHighlight()
	if not player.Character or not player.Character.PrimaryPart then
		FoodConsumption.clearHighlight()
		return
	end
	
	local playerPosition = player.Character.PrimaryPart.Position
	local nearestFood = nil
	local nearestDistance = math.huge
	
	-- Find nearest consumable food
	for _, consumable in pairs(CollectionService:GetTagged("Consumable")) do
		if consumable:IsA("Model") and consumable.PrimaryPart and consumable.Parent then
			local distance = (consumable.PrimaryPart.Position - playerPosition).Magnitude
			
			if distance <= Config.InteractionDistance and distance < nearestDistance then
				nearestDistance = distance
				nearestFood = consumable
			end
		end
	end
	
	-- Update highlight
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
	selectionBox.Adornee = food.PrimaryPart
	
	-- Show interaction hint (you could create a GUI for this)
	-- For now, just print to console
	local foodType = food:GetAttribute("FoodType") or "Food"
	local isCooked = food:GetAttribute("IsCooked") or false
	local hungerValue = food:GetAttribute("HungerValue") or 0
	local state = isCooked and "Cooked" or "Raw"
	
	-- You could create a GUI hint here instead of printing
	-- print("[FoodConsumption] Press E to consume", state, foodType, "(+" .. hungerValue, "hunger)")
end

-- Clear food highlighting
function FoodConsumption.clearHighlight()
	highlightedFood = nil
	selectionBox.Adornee = nil
end

-- Attempt to consume food
function FoodConsumption.attemptConsumption()
	if not highlightedFood or not highlightedFood.Parent then return end
	
	-- Send consumption request to server
	consumeFoodRemote:FireServer(highlightedFood)
	
	-- Clear highlight since food will be consumed
	FoodConsumption.clearHighlight()
end

-- Initialize when script loads
FoodConsumption.init()

return FoodConsumption