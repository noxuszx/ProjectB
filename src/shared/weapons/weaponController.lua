--[[
	weaponController.lua
	Client-side weapon controller for handling input, animations, and visual feedback
	This module is shared between client and server for consistent weapon logic
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local weapons = require(ReplicatedStorage.Shared.config.weapons)

local weaponController = {}

-- Client-side state
local currentWeapon = nil
local currentWeaponConfig = nil
local lastAttackTime = 0
local isOnCooldown = false
local currentAnimation = nil
local animationTrack = nil

-- Remote events (will be created by server)
local weaponRemotes = {
	AttackRemote = nil,
	EquipRemote = nil,
	UnequipRemote = nil
}

-- Initialize remote events
local function initializeRemotes()
	local remoteFolder = ReplicatedStorage:WaitForChild("WeaponRemotes", 10)
	if remoteFolder then
		weaponRemotes.AttackRemote = remoteFolder:WaitForChild("AttackRemote")
		weaponRemotes.EquipRemote = remoteFolder:WaitForChild("EquipRemote")
		weaponRemotes.UnequipRemote = remoteFolder:WaitForChild("UnequipRemote")
	else
		warn("[WeaponController] WeaponRemotes folder not found!")
	end
end

local function debugPrint(message)
	if weapons.Settings.DebugMode then
		print("[WeaponController]", message)
	end
end

local function isWeaponReady()
	if not currentWeaponConfig then return false end
	
	local currentTime = tick()
	local timeSinceLastAttack = currentTime - lastAttackTime
	return timeSinceLastAttack >= currentWeaponConfig.Cooldown
end

local function playWeaponAnimation()
	local player = Players.LocalPlayer
	if not player or not player.Character then return end
	
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	if animationTrack then
		animationTrack:Stop()
		animationTrack = nil
	end
	
	if currentWeaponConfig and currentWeaponConfig.Animation then
		local animation = Instance.new("Animation")
		animation.AnimationId = currentWeaponConfig.Animation
		
		animationTrack = humanoid:LoadAnimation(animation)
		if animationTrack then
			animationTrack:Play()
			debugPrint("Playing animation: " .. currentWeaponConfig.Animation)
		end
	end
end

local function playWeaponSound(soundType)
	if not currentWeaponConfig then return end
	
	local soundId = nil
	if soundType == "swing" then
		soundId = currentWeaponConfig.SwingSound
	elseif soundType == "hit" then
		soundId = currentWeaponConfig.HitSound
	end
	
	if soundId then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = weapons.Settings.GlobalVolume
		sound.Parent = workspace
		sound:Play()
		
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
end

local function onWeaponActivated()
	if not currentWeapon or not currentWeaponConfig then
		debugPrint("No weapon equipped")
		return
	end
	
	if not isWeaponReady() then
		debugPrint("Weapon on cooldown")
		return
	end
	
	debugPrint("Weapon activated: " .. currentWeapon.Name)
	
	lastAttackTime = tick()
	isOnCooldown = true
	
	playWeaponAnimation()
	playWeaponSound("swing")
	
	if weaponRemotes.AttackRemote then
		weaponRemotes.AttackRemote:FireServer(currentWeapon.Name)
	else
		warn("[WeaponController] AttackRemote not found!")
	end
	
	task.wait(currentWeaponConfig.Cooldown)
	isOnCooldown = false
end

function weaponController.equip(tool)
	if not tool or not tool:IsA("Tool") then
		warn("[WeaponController] Invalid tool provided to equip")
		return
	end
	
	local weaponConfig = weapons.getWeaponConfig(tool.Name)
	if not weaponConfig then
		warn("[WeaponController] No configuration found for weapon: " .. tool.Name)
		return
	end
	
	local isValid, errorMessage = weapons.validateWeaponConfig(tool.Name)
	if not isValid then
		warn("[WeaponController] Invalid weapon config for " .. tool.Name .. ": " .. errorMessage)
		return
	end
	
	debugPrint("Equipping weapon: " .. tool.Name)
	
	-- Set current weapon
	currentWeapon = tool
	currentWeaponConfig = weaponConfig
	lastAttackTime = 0
	isOnCooldown = false
	
	-- Connect to tool activation
	if tool.Activated then
		tool.Activated:Connect(onWeaponActivated)
	end
	
	-- Notify server of weapon equip
	if weaponRemotes.EquipRemote then
		weaponRemotes.EquipRemote:FireServer(tool.Name)
	end
	
	debugPrint("Weapon equipped successfully: " .. tool.Name)
end

-- Unequip weapon
function weaponController.unequip(tool)
	if not tool or tool ~= currentWeapon then
		return
	end
	
	debugPrint("Unequipping weapon: " .. tool.Name)
	
	-- Stop any playing animation
	if animationTrack then
		animationTrack:Stop()
		animationTrack = nil
	end
	
	-- Clear current weapon
	currentWeapon = nil
	currentWeaponConfig = nil
	lastAttackTime = 0
	isOnCooldown = false
	
	-- Notify server of weapon unequip
	if weaponRemotes.UnequipRemote then
		weaponRemotes.UnequipRemote:FireServer(tool.Name)
	end
	
	debugPrint("Weapon unequipped successfully")
end

-- Get current weapon info (for UI/debugging)
function weaponController.getCurrentWeapon()
	return currentWeapon, currentWeaponConfig
end

-- Check if weapon is ready to attack (for UI cooldown indicators)
function weaponController.isReady()
	return isWeaponReady()
end

-- Get cooldown progress (0-1, for UI)
function weaponController.getCooldownProgress()
	if not currentWeaponConfig then return 1 end
	
	local currentTime = tick()
	local timeSinceLastAttack = currentTime - lastAttackTime
	local progress = math.min(timeSinceLastAttack / currentWeaponConfig.Cooldown, 1)
	return progress
end

-- Initialize the weapon controller
function weaponController.init()
	debugPrint("Initializing weapon controller...")
	initializeRemotes()
	debugPrint("Weapon controller initialized")
end

return weaponController
