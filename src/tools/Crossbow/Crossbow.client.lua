--[[
    Crossbow.client.lua
    Ranged weapon system with hitscan mechanics and realistic bullet tracers
    Uses instant hit detection with visual tracer animation for best gameplay feel
]]
--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local tool = script.Parent
local player = Players.LocalPlayer

local WeaponConfig = require(ReplicatedStorage.Shared.config.WeaponConfig)
local weaponName = tool.Name
local config = WeaponConfig.getRangedWeaponConfig(weaponName)

if not config then
	error("[" .. weaponName .. "] No ranged weapon configuration found!")
end

local lastFireTime = 0
local isEquipped = false
local currentCharacter = nil
local weaponRemote = nil

local function initializeRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		weaponRemote = remotes:FindFirstChild("WeaponDamage")
		if not weaponRemote then
			warn("[" .. weaponName .. "] WeaponDamage remote not found!")
		end
	end
end

local function isOnCooldown()
	local currentTime = tick()
	local timeSinceLastFire = currentTime - lastFireTime
	return timeSinceLastFire < config.Cooldown
end

local function getCooldownRemaining()
	local currentTime = tick()
	local timeSinceLastFire = currentTime - lastFireTime
	return math.max(0, config.Cooldown - timeSinceLastFire)
end

local function findMuzzlePoint()
	local muzzlePart = tool:FindFirstChild("Muzzle") or tool:FindFirstChild("Barrel")
	if muzzlePart then
		return muzzlePart.CFrame
	end
	local handle = tool:FindFirstChild("Handle")
	if handle then
		return handle.CFrame * CFrame.new(0, 0, -handle.Size.Z / 2 - 0.5)
	end

	if currentCharacter and currentCharacter.PrimaryPart then
		return currentCharacter.PrimaryPart.CFrame * CFrame.new(0, 1, -2)
	end

	return CFrame.new()
end

local function getZoneParts()
	local zoneParts = {}
	
	-- Find all zone trigger parts (used by ZonePlus)
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == "Trigger" and obj.CanQuery then
			table.insert(zoneParts, obj)
		end
	end
	
	return zoneParts
end

local function performHitscan(muzzlePos, mouseHitPos)
	if not currentCharacter or not currentCharacter.PrimaryPart then
		return nil, nil
	end

	local rayDirection = (mouseHitPos - muzzlePos).Unit * config.Range
	local raycastParams = RaycastParams.new()

	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	-- Filter out character, tool, and zone parts so we can hit targets inside zones
	local filterList = { currentCharacter, tool }
	local zoneParts = getZoneParts()
	for _, zonePart in pairs(zoneParts) do
		table.insert(filterList, zonePart)
	end
	
	raycastParams.FilterDescendantsInstances = filterList

	local raycastResult = workspace:Raycast(muzzlePos, rayDirection, raycastParams)

	if raycastResult then
		return raycastResult.Instance, raycastResult.Position
	else
		return nil, mouseHitPos
	end
end

-- Create toolbox-style bullet tracer
local function createTracer(startPos, hitPos)
	local beam = Instance.new("Part", workspace)
	beam.BrickColor = BrickColor.new("Ghost grey")
	beam.FormFactor = "Custom"
	beam.Material = "SmoothPlastic"
	beam.Transparency = 0
	beam.Anchored = true
	beam.Locked = true
	beam.CanCollide = false

	local distance = (hitPos - startPos).Magnitude
	beam.Size = Vector3.new(0.1, 0.1, distance)
	beam.CFrame = CFrame.new(startPos, hitPos) * CFrame.new(0, 0, -distance / 2)

	Debris:AddItem(beam, 0.05)
end

local function playFireSound()
	local zonePart = tool:FindFirstChild("Zone")
	if zonePart and zonePart:FindFirstChild("Sound") then
		local sound = zonePart.Sound:Clone()
		sound.Name = "Shoot"
		sound.Parent = zonePart
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
end

local function findTargetModel(hitPart)
	if not hitPart then
		return nil
	end

	local targetModel = hitPart:FindFirstAncestorOfClass("Model")
	return targetModel
end

local function executeFire()
	if isOnCooldown() then
		return false
	end

	lastFireTime = tick()

	local mouse = player:GetMouse()
	local mouseHitPos = mouse.Hit.Position
	local muzzlePos = findMuzzlePoint()
	local startPos = muzzlePos.Position
	local hitPart, hitPos = performHitscan(startPos, mouseHitPos)

	createTracer(startPos, hitPos)
	playFireSound()

	if hitPart then
		local targetModel = findTargetModel(hitPart)
		if targetModel and weaponRemote then
			weaponRemote:FireServer(targetModel, config.Damage)
		end
	end

	return true
end

tool.Equipped:Connect(function()
	isEquipped = true
	currentCharacter = player.Character
	if not weaponRemote then
		initializeRemote()
	end
end)

tool.Unequipped:Connect(function()
	isEquipped = false
	currentCharacter = nil
end)

tool.Activated:Connect(function()
	if not isEquipped then
		return
	end

	executeFire()
end)

player.CharacterAdded:Connect(function(character)
	if isEquipped then
		currentCharacter = character
	end
end)

initializeRemote()
