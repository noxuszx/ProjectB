-- src/client/food/FoodConsumption.client.lua
-- Communicates with server to handle hunger restoration

local Players 			= game:GetService("Players")
local UserInputService 	= game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local consumeFoodRemote = ReplicatedStorage:WaitForChild("ConsumeFood", 10)
if not consumeFoodRemote then
	consumeFoodRemote 			= Instance.new("RemoteEvent")
	consumeFoodRemote.Name 		= "ConsumeFood"
	consumeFoodRemote.Parent	= ReplicatedStorage
end

local FoodConsumption = {}

--=====================================================================

local Config = {
	InteractionDistance = 10,
	InteractionKey 		= Enum.KeyCode.E
}

local highlightedFood = nil
local highlight 	  = nil

--=====================================================================

function FoodConsumption.init()
	print("[FoodConsumption] Initialized.")
	UserInputService.InputBegan:Connect(FoodConsumption.onInputBegan)
	FoodConsumption.setupFoodHighlighting()
	print("[FoodConsumption] Ready.")
end

function FoodConsumption.onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Config.InteractionKey then
		FoodConsumption.attemptConsumption()
	end
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
	
	for _, consumable in pairs(CollectionService:GetTagged("Consumable")) do
		if consumable:IsA("Model") and consumable.PrimaryPart and consumable.Parent then
			local distance = (consumable.PrimaryPart.Position - playerPosition).Magnitude
			
			if distance <= Config.InteractionDistance and distance < nearestDistance then
				nearestDistance = distance
				nearestFood = consumable
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
highlight.Parent = food.PrimaryPart
	-- Show interaction hint (you could create a GUI for this)
	-- For now, just print to console
	local foodType = food:GetAttribute("FoodType") or "Food"
	local isCooked = food:GetAttribute("IsCooked") or false
	local hungerValue = food:GetAttribute("HungerValue") or 0
	local state = isCooked and "Cooked" or "Raw"
	
	-- You could create a GUI hint here instead of printing
	-- print("[FoodConsumption] Press E to consume", state, foodType, "(+" .. hungerValue, "hunger)")
end

function FoodConsumption.clearHighlight()
	highlightedFood = nil
highlight.Parent = nil
end

function FoodConsumption.attemptConsumption()
	if not highlightedFood or not highlightedFood.Parent then return end
	consumeFoodRemote:FireServer(highlightedFood)
	FoodConsumption.clearHighlight()
end

FoodConsumption.init()

return FoodConsumption