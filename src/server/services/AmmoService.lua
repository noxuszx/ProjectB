-- src/server/services/AmmoService.lua
-- Memory-based ammo tracking service for roguelike gameplay
-- Manages per-player ammo counts that reset on disconnect

local Players = game:GetService("Players")

local AmmoService = {}

-- Per-player ammo storage: playerAmmo[player][ammoType] = amount
local playerAmmo = {}

-- Initialize ammo tracking for new players
local function onPlayerAdded(player)
	playerAmmo[player] = {}
end

-- Clean up ammo data when player leaves
local function onPlayerRemoving(player)
	playerAmmo[player] = nil
end

-- Public API Functions

-- Add ammo to a player's inventory
function AmmoService.addAmmo(player, ammoType, amount)
	if not player or not ammoType or not amount then
		warn("[AmmoService] Invalid parameters for addAmmo")
		return false
	end

	if not playerAmmo[player] then
		warn("[AmmoService] Player not found in ammo tracking:", player.Name)
		return false
	end

	local currentAmount = playerAmmo[player][ammoType] or 0
	playerAmmo[player][ammoType] = currentAmount + amount

	print("[AmmoService] Added", amount, ammoType, "to", player.Name, "- Total:", playerAmmo[player][ammoType])
	return true
end

-- Get current ammo count for a player
function AmmoService.getAmmo(player, ammoType)
	if not player or not ammoType then
		return 0
	end

	if not playerAmmo[player] then
		return 0
	end

	return playerAmmo[player][ammoType] or 0
end

-- TODO: Consume ammo (for crossbow firing integration)
-- This will be called by weapon scripts when firing
function AmmoService.consumeAmmo(player, ammoType, amount)
	-- TODO: Implement when crossbow system is integrated
	-- Should check if player has enough ammo, then deduct amount
	-- Return true if successful, false if insufficient ammo
	warn("[AmmoService] consumeAmmo not yet implemented - TODO for crossbow integration")
	return false
end

-- Get all ammo types and counts for a player (for UI display)
function AmmoService.getAllAmmo(player)
	if not player or not playerAmmo[player] then
		return {}
	end

	return playerAmmo[player]
end

-- Initialize the service
local function init()
	-- Connect to player events
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Initialize existing players (if any)
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	print("[AmmoService] Initialized - Memory-based ammo tracking active")
	print("==================================================")
end

init()

return AmmoService
