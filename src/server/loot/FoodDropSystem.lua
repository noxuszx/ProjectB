-- src/server/loot/FoodDropSystem.lua
-- Handles food drops from animal creatures when they die
-- Integrates with existing drag-drop system via CollectionServiceTags

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local FoodDropSystem = {}

-- Food configuration
local FoodConfig = {
	-- Animal type to food model mapping
	AnimalFoods = {
		Rabbit = "RabbitMeat",
		Wolf = "WolfMeat", 
		Lizard = "LizardMeat"
	},
	
	-- Food properties
	FoodProperties = {
		RabbitMeat = {
			RawHunger = 15,
			CookedHunger = 25,
			RawColor = Color3.fromRGB(200, 100, 100), -- Pink/red
			CookedColor = Color3.fromRGB(139, 69, 19)  -- Brown
		},
		WolfMeat = {
			RawHunger = 20,
			CookedHunger = 35,
			RawColor = Color3.fromRGB(180, 80, 80),
			CookedColor = Color3.fromRGB(120, 60, 20)
		},
		LizardMeat = {
			RawHunger = 12,
			CookedHunger = 20,
			RawColor = Color3.fromRGB(220, 120, 120),
			CookedColor = Color3.fromRGB(150, 75, 25)
		}
	},
	
	-- Drop settings
	DropSettings = {
		DropHeight = 2,
		ScatterRadius = 3,
		MaxDropAttempts = 5
	},
	
	-- Note: Cooking surfaces should be tagged with "CookingSurface" tag
}

-- Food storage folder
local foodFolder = Instance.new("Folder")
foodFolder.Name = "DroppedFood"
foodFolder.Parent = workspace

-- Initialize the system
function FoodDropSystem.init()
	print("[FoodDropSystem] Initializing food drop system...")
	
	-- Set up cooking surface detection
	FoodDropSystem.setupCookingDetection()
	
	print("[FoodDropSystem] Food drop system ready!")
	return true
end

-- Drop food when an animal dies
function FoodDropSystem.dropFood(creatureType, position, dyingCreatureModel)
	local totalStart = os.clock()
	
	local foodType = FoodConfig.AnimalFoods[creatureType]
	if not foodType then
		warn("[FoodDropSystem] No food configured for creature type:", creatureType)
		return false
	end
	
	-- Get food template from ReplicatedStorage.Items
	local templateStart = os.clock()
	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	if not itemsFolder then
		warn("[FoodDropSystem] Items folder not found in ReplicatedStorage")
		return false
	end
	
	local foodTemplate = itemsFolder:FindFirstChild(foodType)
	if not foodTemplate then
		warn("[FoodDropSystem] Food model not found:", foodType)
		return false
	end
	
	-- Clone the food model
	local foodModel = foodTemplate:Clone()
	foodModel.Name = foodType .. "_" .. os.clock()
	print("[FoodDropSystem] Template/Clone took:", (os.clock() - templateStart) * 1000, "ms")
	
	-- Position the food near the death location
	local positionStart = os.clock()
	local dropPosition = FoodDropSystem.getDropPosition(position, dyingCreatureModel)
	print("[FoodDropSystem] Position calculation took:", (os.clock() - positionStart) * 1000, "ms")
	
	if foodModel.PrimaryPart then
		foodModel:SetPrimaryPartCFrame(CFrame.new(dropPosition))
	else
		warn("[FoodDropSystem] Food model missing PrimaryPart:", foodType)
		foodModel.Parent = foodFolder
		return false
	end
	
	-- Set up food properties
	local setupStart = os.clock()
	FoodDropSystem.setupFoodModel(foodModel, foodType)
	print("[FoodDropSystem] Model setup took:", (os.clock() - setupStart) * 1000, "ms")
	
	-- Parent to world
	foodModel.Parent = foodFolder
	
	print("[FoodDropSystem] Total dropFood took:", (os.clock() - totalStart) * 1000, "ms")
	print("[FoodDropSystem] Dropped", foodType, "at", dropPosition)
	return true
end

-- Set up a food model with proper properties and tags
function FoodDropSystem.setupFoodModel(foodModel, foodType)
	local config = FoodConfig.FoodProperties[foodType]
	if not config then
		warn("[FoodDropSystem] No config found for food type:", foodType)
		return
	end
	
	-- Set initial raw state
	FoodDropSystem.setFoodState(foodModel, foodType, "raw")
	
	-- Add food-specific attributes
	foodModel:SetAttribute("FoodType", foodType)
	foodModel:SetAttribute("IsCooked", false)
	foodModel:SetAttribute("HungerValue", config.RawHunger)
	
	-- Tag for drag-drop system integration
	CollectionServiceTags.addTag(foodModel, CollectionServiceTags.DRAGGABLE)
	CollectionServiceTags.addTag(foodModel, CollectionServiceTags.WELDABLE)
	
	-- Add consumption and meat state tags
	CollectionService:AddTag(foodModel, "Consumable")
	CollectionService:AddTag(foodModel, "RawMeat")
end

-- Set food state (raw or cooked)
function FoodDropSystem.setFoodState(foodModel, foodType, state)
	local config = FoodConfig.FoodProperties[foodType]
	if not config then return end
	
	local isCooked = (state == "cooked")
	local color = isCooked and config.CookedColor or config.RawColor
	local hungerValue = isCooked and config.CookedHunger or config.RawHunger
	
	-- Only color the "Meat" part, not bones or other parts
	local meatPart = foodModel:FindFirstChild("Meat")
	if meatPart and meatPart:IsA("BasePart") then
		meatPart.Color = color
	else
		-- Fallback: if no "Meat" part found, color PrimaryPart
		if foodModel.PrimaryPart then
			foodModel.PrimaryPart.Color = color
		end
		warn("[FoodDropSystem] No 'Meat' part found in", foodModel.Name, "- using PrimaryPart")
	end
	
	-- Update attributes
	foodModel:SetAttribute("IsCooked", isCooked)
	foodModel:SetAttribute("HungerValue", hungerValue)
	
	-- Update meat state tags
	if isCooked then
		CollectionService:RemoveTag(foodModel, "RawMeat")
		CollectionService:AddTag(foodModel, "CookedMeat")
	else
		CollectionService:RemoveTag(foodModel, "CookedMeat")
		CollectionService:AddTag(foodModel, "RawMeat")
	end
	
	print("[FoodDropSystem] Set", foodModel.Name, "to", state, "state (Hunger:", hungerValue .. ")")
end


-- Find a valid drop position near the death location
function FoodDropSystem.getDropPosition(centerPosition, dyingCreatureModel)
	local settings = FoodConfig.DropSettings
	
	for attempt = 1, settings.MaxDropAttempts do
		-- Random position within scatter radius
		local angle = math.random() * math.pi * 2
		local distance = math.random() * settings.ScatterRadius
		local offsetX = math.sin(angle) * distance
		local offsetZ = math.cos(angle) * distance
		
		local testPosition = Vector3.new(
			centerPosition.X + offsetX,
			centerPosition.Y + settings.DropHeight,
			centerPosition.Z + offsetZ
		)
		
		-- Raycast to find ground
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		local blacklist = {foodFolder}
		if dyingCreatureModel then
			table.insert(blacklist, dyingCreatureModel)
		end
		raycastParams.FilterDescendantsInstances = blacklist
		
		local rayOrigin = testPosition + Vector3.new(0, 10, 0)
		local rayDirection = Vector3.new(0, -20, 0)
		local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
		
		if raycastResult then
			return raycastResult.Position + Vector3.new(0, 1, 0)
		end
	end
	
	-- Fallback to original position if raycast fails
	return centerPosition + Vector3.new(0, settings.DropHeight, 0)
end

-- Set up cooking surface detection
function FoodDropSystem.setupCookingDetection()
	-- Monitor all consumable food items for cooking surface contact
	local function onConsumableAdded(instance)
		if instance:IsA("Model") and instance:GetAttribute("FoodType") then
			FoodDropSystem.setupCookingForFood(instance)
		end
	end
	
	-- Connect to existing consumables
	for _, consumable in pairs(CollectionService:GetTagged("Consumable")) do
		onConsumableAdded(consumable)
	end
	
	-- Connect to new consumables
	CollectionService:GetInstanceAddedSignal("Consumable"):Connect(onConsumableAdded)
end

-- Set up cooking detection for a specific food item
function FoodDropSystem.setupCookingForFood(foodModel)
	if not foodModel.PrimaryPart then return end
	
	local function onTouched(hit)
		-- Check if the hit part or its parent is tagged as a cooking surface
		local isCookingSurface = CollectionService:HasTag(hit, "CookingSurface") or 
								 CollectionService:HasTag(hit.Parent, "CookingSurface")
		
		if not isCookingSurface then return end
		
		-- Only cook if it's raw
		local isCooked = foodModel:GetAttribute("IsCooked")
		if isCooked then return end
		
		-- Cook the food
		local foodType = foodModel:GetAttribute("FoodType")
		if foodType then
			FoodDropSystem.setFoodState(foodModel, foodType, "cooked")
			print("[FoodDropSystem]", foodModel.Name, "was cooked by", hit.Parent.Name or hit.Name)
		end
	end
	
	-- Connect touch event to primary part
	foodModel.PrimaryPart.Touched:Connect(onTouched)
end

-- Get food folder for external access
function FoodDropSystem.getFoodFolder()
	return foodFolder
end

-- Clean up all dropped food (utility function)
function FoodDropSystem.cleanup()
	if foodFolder then
		foodFolder:ClearAllChildren()
	end
	print("[FoodDropSystem] Cleaned up all dropped food")
end

return FoodDropSystem