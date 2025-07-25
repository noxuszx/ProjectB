--[[
	pickups.server.lua
	Server-side weapon pickup system
	Handles weapon pickup interactions using ProximityPrompts
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local weapons = require(ReplicatedStorage.Shared.config.weapons)

-- Debug print function
local function debugPrint(message)
	if weapons.Settings.DebugMode then
		print("[WeaponPickups]", message)
	end
end

-- Create a proximity prompt for a weapon
local function createPickupPrompt(weaponTool)
	if not weaponTool or not weaponTool:IsA("Tool") then
		warn("[WeaponPickups] Invalid weapon tool provided")
		return nil
	end
	
	local handle = weaponTool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		warn("[WeaponPickups] Weapon tool missing Handle: " .. weaponTool.Name)
		return nil
	end
	
	-- Get weapon config for display info
	local weaponConfig = weapons.getWeaponConfig(weaponTool.Name)
	if not weaponConfig then
		warn("[WeaponPickups] No config found for weapon: " .. weaponTool.Name)
		return nil
	end
	
	-- Create proximity prompt
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.ActionText = "Pick up"
	proximityPrompt.ObjectText = weaponConfig.DisplayName or weaponTool.Name
	proximityPrompt.HoldDuration = 0.5 -- Half second hold to pick up
	proximityPrompt.MaxActivationDistance = 8 -- 8 studs pickup range
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.Parent = handle
	
	debugPrint("Created pickup prompt for: " .. weaponTool.Name)
	return proximityPrompt
end

-- Handle weapon pickup
local function onWeaponPickup(proximityPrompt, player)
	local weaponTool = proximityPrompt.Parent.Parent
	
	if not weaponTool or not weaponTool:IsA("Tool") then
		warn("[WeaponPickups] Invalid weapon tool in pickup")
		return
	end
	
	debugPrint("Player " .. player.Name .. " picking up " .. weaponTool.Name)
	
	-- Validate weapon config
	local weaponConfig = weapons.getWeaponConfig(weaponTool.Name)
	if not weaponConfig then
		warn("[WeaponPickups] No config found for weapon: " .. weaponTool.Name)
		return
	end
	
	-- Check if player has backpack
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		warn("[WeaponPickups] Player " .. player.Name .. " has no backpack")
		return
	end
	
	-- Check if player already has this weapon
	local existingWeapon = backpack:FindFirstChild(weaponTool.Name)
	if existingWeapon then
		debugPrint("Player " .. player.Name .. " already has " .. weaponTool.Name)
		-- Could implement stacking or replacement logic here
		return
	end
	
	-- Also check if weapon is currently equipped
	if player.Character then
		local equippedWeapon = player.Character:FindFirstChild(weaponTool.Name)
		if equippedWeapon then
			debugPrint("Player " .. player.Name .. " already has " .. weaponTool.Name .. " equipped")
			return
		end
	end
	
	-- Get clean master copy from ReplicatedStorage instead of cloning the pickup
	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	if not itemsFolder then
		warn("[WeaponPickups] Items folder not found in ReplicatedStorage")
		return
	end

	local masterWeapon = itemsFolder:FindFirstChild(weaponTool.Name)
	if not masterWeapon then
		warn("[WeaponPickups] Master weapon not found in Items folder: " .. weaponTool.Name)
		return
	end

	-- Clone the clean master copy (no ProximityPrompt)
	local weaponClone = masterWeapon:Clone()

	-- Add the tool loader script to the weapon
	local toolLoaderScript = ReplicatedStorage.Shared.weapons.toolLoaderScript:Clone()
	toolLoaderScript.Parent = weaponClone

	-- Give weapon to player
	weaponClone.Parent = backpack
	
	-- Remove the original weapon from the world
	weaponTool:Destroy()
	
	debugPrint("Successfully gave " .. weaponTool.Name .. " to " .. player.Name)
end

-- Handle when a weapon is tagged for pickup
local function onWeaponTagged(weaponTool)
	if not weaponTool or not weaponTool:IsA("Tool") then
		return
	end
	
	debugPrint("Setting up pickup for weapon: " .. weaponTool.Name)
	
	-- Create pickup prompt
	local proximityPrompt = createPickupPrompt(weaponTool)
	if not proximityPrompt then
		return
	end
	
	-- Connect pickup event
	proximityPrompt.Triggered:Connect(function(player)
		onWeaponPickup(proximityPrompt, player)
	end)
	
	debugPrint("Weapon pickup configured: " .. weaponTool.Name)
end

-- Handle when a weapon pickup tag is removed
local function onWeaponUntagged(weaponTool)
	if not weaponTool or not weaponTool:IsA("Tool") then
		return
	end
	
	debugPrint("Removing pickup for weapon: " .. weaponTool.Name)
	
	-- Find and remove proximity prompt
	local handle = weaponTool:FindFirstChild("Handle")
	if handle then
		local proximityPrompt = handle:FindFirstChild("ProximityPrompt")
		if proximityPrompt then
			proximityPrompt:Destroy()
			debugPrint("Removed pickup prompt for: " .. weaponTool.Name)
		end
	end
end

-- Initialize pickup system for existing weapons
local function initializeExistingWeapons()
	local existingWeapons = CollectionServiceTags.getTaggedObjects(CollectionServiceTags.WEAPON_PICKUP)
	debugPrint("Found " .. #existingWeapons .. " existing weapon pickups")
	
	for _, weapon in pairs(existingWeapons) do
		onWeaponTagged(weapon)
	end
end

-- Connect to collection service events
CollectionService:GetInstanceAddedSignal(CollectionServiceTags.WEAPON_PICKUP):Connect(onWeaponTagged)
CollectionService:GetInstanceRemovedSignal(CollectionServiceTags.WEAPON_PICKUP):Connect(onWeaponUntagged)

-- Initialize system
debugPrint("Initializing weapon pickup system...")
initializeExistingWeapons()
debugPrint("Weapon pickup system ready")
print("[WeaponPickups] Weapon pickup system initialized")
