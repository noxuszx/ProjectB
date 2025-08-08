-- src/server/loot/FoodDropSystem.lua
-- Handles food drops from animal creatures when they die
-- Integrates with existing drag-drop system via CollectionServiceTags

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace 		= game:GetService("Workspace")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local FoodDropSystem = {}

local FoodConfig = {

	AnimalFoods = {
		Rabbit = "RabbitMeat",
		Coyote = "CoyoteMeat",
		Scorpion = "ScorpionMeat",
		Camel = "CamelMeat",
	},

	FoodProperties = {
		RabbitMeat = {
			RawHunger = 15,
			CookedHunger = 25,
			RawColor = Color3.fromRGB(200, 100, 100),
			CookedColor = Color3.fromRGB(139, 69, 19),
		},
		CoyoteMeat = {
			RawHunger = 20,
			CookedHunger = 35,
			RawColor = Color3.fromRGB(180, 80, 80),
			CookedColor = Color3.fromRGB(120, 60, 20),
		},
		ScorpionMeat = {
			RawHunger = 12,
			CookedHunger = 20,
			RawColor = Color3.fromRGB(220, 120, 120),
			CookedColor = Color3.fromRGB(150, 75, 25),
		},
		CamelMeat = {
			RawHunger = 30,
			CookedHunger = 50,
			RawColor = Color3.fromRGB(160, 70, 70),
			CookedColor = Color3.fromRGB(110, 50, 15),
		},
	},

	DropSettings = {
		DropHeight = 2,
		ScatterRadius = 3,
		MaxDropAttempts = 5,
	},

}

local foodFolder = Instance.new("Folder")
foodFolder.Name = "DroppedFood"
foodFolder.Parent = workspace

----------------------------------------------------------------------------------
----------------------- INIT -----------------------------------------------------
----------------------------------------------------------------------------------


function FoodDropSystem.init()
	FoodDropSystem.setupCookingDetection()
	print("[FoodDropSystem] Food drop system Initialized")
	return true
end

function FoodDropSystem.dropFood(creatureType, position, dyingCreatureModel)
	
	local totalStart = os.clock()
	local foodType = FoodConfig.AnimalFoods[creatureType]
	
	if not foodType then
		warn("[FoodDropSystem] No food configured for creature type:", creatureType)
		return false
	end

	local templateStart = os.clock()
	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	if not itemsFolder then
		warn("[FoodDropSystem] Items folder not found in ReplicatedStorage")
		return false
	end

	local foodTemplateFolder = itemsFolder:FindFirstChild("Food")
	if not foodTemplateFolder then
		warn("[FoodDropSystem] Food folder not found in ReplicatedStorage/Items")
		return false
	end

	local foodTemplate = foodTemplateFolder:FindFirstChild(foodType)
	if not foodTemplate then
		warn("[FoodDropSystem] Food model not found:", foodType)
		return false
	end

	local foodModel = foodTemplate:Clone()
	foodModel.Name = foodType .. "_" .. os.clock()

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

	local setupStart = os.clock()
	FoodDropSystem.setupFoodModel(foodModel, foodType)
	print("[FoodDropSystem] Model setup took:", (os.clock() - setupStart) * 1000, "ms")

	foodModel.Parent = foodFolder

	print("[FoodDropSystem] Total dropFood took:", (os.clock() - totalStart) * 1000, "ms")
	print("[FoodDropSystem] Dropped", foodType, "at", dropPosition)
	return true
end


function FoodDropSystem.setupFoodModel(foodModel, foodType)
	local config = FoodConfig.FoodProperties[foodType]
	if not config then
		warn("[FoodDropSystem] No config found for food type:", foodType)
		return
	end

	FoodDropSystem.setFoodState(foodModel, foodType, "raw")

	foodModel:SetAttribute("FoodType", foodType)
	foodModel:SetAttribute("IsCooked", false)
	foodModel:SetAttribute("HungerValue", config.RawHunger)

	CollectionServiceTags.addTag(foodModel, CollectionServiceTags.DRAGGABLE)
	CollectionServiceTags.addTag(foodModel, CollectionServiceTags.WELDABLE)
	CollectionServiceTags.addTag(foodModel, CollectionServiceTags.STORABLE)

	CollectionService:AddTag(foodModel, "Consumable")
	CollectionService:AddTag(foodModel, "RawMeat")
end

function FoodDropSystem.setFoodState(foodModel, foodType, state)
	local config = FoodConfig.FoodProperties[foodType]
	if not config then
		return
	end

	local isCooked = (state == "cooked")
	local color = isCooked and config.CookedColor or config.RawColor
	local hungerValue = isCooked and config.CookedHunger or config.RawHunger
	local meatPart = foodModel:FindFirstChild("Meat")

	if meatPart and meatPart:IsA("BasePart") then
		meatPart.Color = color
	else

		if foodModel.PrimaryPart then
		   foodModel.PrimaryPart.Color = color
		end
		warn("[FoodDropSystem] No 'Meat' part found in", foodModel.Name, "- using PrimaryPart")

	end

	foodModel:SetAttribute("IsCooked", isCooked)
	foodModel:SetAttribute("HungerValue", hungerValue)

	if isCooked then
		CollectionService:RemoveTag(foodModel, "RawMeat")
		CollectionService:AddTag   (foodModel, "CookedMeat")
	else
		CollectionService:RemoveTag(foodModel, "CookedMeat")
		CollectionService:AddTag   (foodModel, "RawMeat")
	end

	print("[FoodDropSystem] Set", foodModel.Name, "to", state, "state (Hunger:", hungerValue .. ")")
end

function FoodDropSystem.getDropPosition(centerPosition, dyingCreatureModel)
	local settings = FoodConfig.DropSettings

	for attempt = 1, settings.MaxDropAttempts do
		-- Random position within scatter radius
		local angle = math.random() * math.pi * 2
		local distance = math.random() * settings.ScatterRadius
		local offsetX = math.sin(angle) * distance
		local offsetZ = math.cos(angle) * distance

		local testPosition =
			Vector3.new(centerPosition.X + offsetX, centerPosition.Y + settings.DropHeight, centerPosition.Z + offsetZ)

		-- Raycast to find ground
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local blacklist = { foodFolder }
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

	return centerPosition + Vector3.new(0, settings.DropHeight, 0)
end

function FoodDropSystem.setupCookingDetection()

	local function onConsumableAdded(instance)
		if instance:IsA("Model") and instance:GetAttribute("FoodType") then
			FoodDropSystem.setupCookingForFood(instance)
		end
	end

	for _, consumable in pairs(CollectionService:GetTagged("Consumable")) do
		onConsumableAdded(consumable)
	end

	CollectionService:GetInstanceAddedSignal("Consumable"):Connect(onConsumableAdded)
end

function FoodDropSystem.setupCookingForFood(foodModel)
	if not foodModel.PrimaryPart then
		return
	end

	local function onTouched(hit)
		local isCookingSurface = CollectionService:HasTag(hit, "CookingSurface")
			or CollectionService:HasTag(hit.Parent, "CookingSurface")

		if not isCookingSurface then
			return
		end

		local isCooked = foodModel:GetAttribute("IsCooked")
		if isCooked then
			return
		end

		local foodType = foodModel:GetAttribute("FoodType")
		if foodType then
			FoodDropSystem.setFoodState(foodModel, foodType, "cooked")
			print("[FoodDropSystem]", foodModel.Name, "was cooked by", hit.Parent.Name or hit.Name)
		end
	end

	foodModel.PrimaryPart.Touched:Connect(onTouched)
end

function FoodDropSystem.getFoodFolder()
	return foodFolder
end

function FoodDropSystem.cleanup()
	if foodFolder then
		foodFolder:ClearAllChildren()
	end
	print("[FoodDropSystem] Cleaned up all dropped food")
end

return FoodDropSystem
