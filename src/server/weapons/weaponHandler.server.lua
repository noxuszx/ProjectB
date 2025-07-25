--[[
	weaponHandler.server.lua
	Server-side weapon handler for damage validation, hit detection, and security
	Handles all weapon attacks and ensures no exploiting
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local weapons = require(ReplicatedStorage.Shared.config.weapons)

-- Server state tracking
local playerWeapons = {} -- Track what weapon each player has equipped
local playerCooldowns = {} -- Track attack cooldowns per player

-- Create remote events folder
local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "WeaponRemotes"
remoteFolder.Parent = ReplicatedStorage

-- Create remote events
local attackRemote = Instance.new("RemoteEvent")
attackRemote.Name = "AttackRemote"
attackRemote.Parent = remoteFolder

local equipRemote = Instance.new("RemoteEvent")
equipRemote.Name = "EquipRemote"
equipRemote.Parent = remoteFolder

local unequipRemote = Instance.new("RemoteEvent")
unequipRemote.Name = "UnequipRemote"
unequipRemote.Parent = remoteFolder

-- Debug print function
local function debugPrint(message)
	if weapons.Settings.DebugMode then
		print("[WeaponHandler]", message)
	end
end

-- Validate that player actually has the weapon equipped
local function validatePlayerWeapon(player, weaponName)
	-- Check if player has weapon in backpack or character
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")
	
	local hasWeapon = false
	
	-- Check character (currently equipped)
	if character then
		local tool = character:FindFirstChild(weaponName)
		if tool and tool:IsA("Tool") then
			hasWeapon = true
		end
	end
	
	-- Check backpack (not currently equipped but owned)
	if not hasWeapon and backpack then
		local tool = backpack:FindFirstChild(weaponName)
		if tool and tool:IsA("Tool") then
			hasWeapon = true
		end
	end
	
	return hasWeapon
end

-- Check if player is on cooldown
local function isPlayerOnCooldown(player, weaponName)
	local playerId = tostring(player.UserId)
	local cooldownKey = playerId .. "_" .. weaponName
	
	if not playerCooldowns[cooldownKey] then
		return false
	end
	
	local weaponConfig = weapons.getWeaponConfig(weaponName)
	if not weaponConfig then
		return true -- If no config, assume on cooldown for safety
	end
	
	local currentTime = tick()
	local timeSinceLastAttack = currentTime - playerCooldowns[cooldownKey]
	
	return timeSinceLastAttack < weaponConfig.Cooldown
end

-- Set player cooldown
local function setPlayerCooldown(player, weaponName)
	local playerId = tostring(player.UserId)
	local cooldownKey = playerId .. "_" .. weaponName
	playerCooldowns[cooldownKey] = tick()
end

-- Perform hit detection using raycast
local function performHitDetection(player, weaponConfig)
	local character = player.Character
	if not character then return {} end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return {} end
	
	-- Create raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {character}
	
	-- Cast ray forward from player
	local origin = humanoidRootPart.Position
	local direction = humanoidRootPart.CFrame.LookVector * weaponConfig.Range
	
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)
	
	local hits = {}
	if raycastResult then
		local hitPart = raycastResult.Instance
		local hitModel = hitPart.Parent
		
		-- Check if we hit a valid target (has Humanoid)
		local humanoid = hitModel:FindFirstChild("Humanoid")
		if humanoid and hitModel ~= character then
			table.insert(hits, {
				model = hitModel,
				humanoid = humanoid,
				hitPart = hitPart,
				position = raycastResult.Position
			})
			
			debugPrint("Hit detected: " .. hitModel.Name)
		end
	end
	
	return hits
end

-- Apply damage to target
local function applyDamage(target, damage, attacker)
	if not target.humanoid or not target.humanoid.Parent then
		return
	end
	
	debugPrint("Applying " .. damage .. " damage to " .. target.model.Name)
	
	-- Apply damage
	target.humanoid:TakeDamage(damage)
	
	-- Create damage indicator (optional visual feedback)
	if weapons.Settings.ShowDamageNumbers then
		-- TODO: Create floating damage number GUI
		-- This would be a client-side effect triggered by a remote event
	end
	
	-- Play hit sound effect
	-- TODO: Play hit sound at target location
	
	-- Check if target was killed
	if target.humanoid.Health <= 0 then
		debugPrint(target.model.Name .. " was defeated by " .. attacker.Name)
		-- TODO: Handle death/defeat logic
	end
end

-- Handle attack remote event
local function onAttackRemote(player, weaponName)
	debugPrint("Attack request from " .. player.Name .. " with " .. weaponName)
	
	-- Validate weapon name
	if type(weaponName) ~= "string" then
		warn("[WeaponHandler] Invalid weapon name from " .. player.Name)
		return
	end
	
	-- Get weapon configuration
	local weaponConfig = weapons.getWeaponConfig(weaponName)
	if not weaponConfig then
		warn("[WeaponHandler] Unknown weapon: " .. weaponName .. " from " .. player.Name)
		return
	end
	
	-- Validate player has the weapon
	if not validatePlayerWeapon(player, weaponName) then
		warn("[WeaponHandler] Player " .. player.Name .. " doesn't have weapon: " .. weaponName)
		return
	end
	
	-- Check cooldown
	if isPlayerOnCooldown(player, weaponName) then
		debugPrint("Player " .. player.Name .. " is on cooldown for " .. weaponName)
		return
	end
	
	-- Set cooldown
	setPlayerCooldown(player, weaponName)
	
	-- Perform hit detection
	local hits = performHitDetection(player, weaponConfig)
	
	-- Apply damage to all valid targets
	for _, target in ipairs(hits) do
		applyDamage(target, weaponConfig.Damage, player)
	end
	
	debugPrint("Attack processed for " .. player.Name .. " with " .. weaponName .. " (" .. #hits .. " hits)")
end

-- Handle equip remote event
local function onEquipRemote(player, weaponName)
	debugPrint("Equip request from " .. player.Name .. " for " .. weaponName)
	
	-- Validate weapon exists
	local weaponConfig = weapons.getWeaponConfig(weaponName)
	if not weaponConfig then
		warn("[WeaponHandler] Unknown weapon equip: " .. weaponName .. " from " .. player.Name)
		return
	end
	
	-- Track equipped weapon
	playerWeapons[tostring(player.UserId)] = weaponName
	debugPrint("Player " .. player.Name .. " equipped " .. weaponName)
end

-- Handle unequip remote event
local function onUnequipRemote(player, weaponName)
	debugPrint("Unequip request from " .. player.Name .. " for " .. weaponName)
	
	-- Clear equipped weapon
	playerWeapons[tostring(player.UserId)] = nil
	debugPrint("Player " .. player.Name .. " unequipped " .. weaponName)
end

-- Clean up player data when they leave
local function onPlayerRemoving(player)
	local playerId = tostring(player.UserId)
	
	-- Clear equipped weapon
	playerWeapons[playerId] = nil
	
	-- Clear cooldowns
	for cooldownKey, _ in pairs(playerCooldowns) do
		if string.find(cooldownKey, playerId .. "_") then
			playerCooldowns[cooldownKey] = nil
		end
	end
	
	debugPrint("Cleaned up weapon data for " .. player.Name)
end

-- Connect remote events
attackRemote.OnServerEvent:Connect(onAttackRemote)
equipRemote.OnServerEvent:Connect(onEquipRemote)
unequipRemote.OnServerEvent:Connect(onUnequipRemote)

-- Connect player events
Players.PlayerRemoving:Connect(onPlayerRemoving)

debugPrint("Weapon handler initialized")
print("[WeaponHandler] Server-side weapon system ready")
