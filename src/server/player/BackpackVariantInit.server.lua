-- src/server/player/BackpackVariantInit.server.lua
-- Wires backpack variant resolution, per-player capacity, and equip-on-spawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BackpackPreferenceService = require(ServerScriptService.Server.services.BackpackPreferenceService)
local BackpackService = require(ServerScriptService.Server.player.BackpackService)

local function onCharacterAdded(player, character, variant, capacity)
	print("[BackpackVariantInit][DEBUG] CharacterAdded", player.Name, "variant=", variant)
	-- wait for Backpack container to exist to move/equip tools
	local tries = 0
	while not player:FindFirstChild("Backpack") and tries < 100 do
		tries += 1
		task.wait(0.05)
	end
	local ok, err = pcall(function()
		BackpackPreferenceService.equipChosenBackpack(player, variant)
	end)
	if not ok then
		warn("[BackpackVariantInit][DEBUG] equipChosenBackpack error:", err)
	end
	BackpackService.setPlayerCapacity(player, capacity)
end

local function waitForProfile(player, timeout)
	timeout = timeout or 12 -- increase tolerance for profile handoff after teleport
	local start = os.clock()
	while os.clock() - start < timeout do
		if _G.ProfileAccessor and _G.ProfileAccessor.getProfileData then
			local data = _G.ProfileAccessor:getProfileData(player)
			if data then return data end
		end
		task.wait(0.05)
	end
	return nil
end

local function reResolveWhenProfileReady(player, initialVariant, initialCapacity)
	task.spawn(function()
		local data = waitForProfile(player, 15)
		if not data then return end
		-- Now that profile is available, resolve again; if different, re-apply
		local newVariant = BackpackPreferenceService.resolveVariant(player)
		if newVariant ~= initialVariant then
			local newCapacity = BackpackPreferenceService.getCapacityForVariant(newVariant)
			print("[BackpackVariantInit][DEBUG] Re-resolve after profile ready:", player.Name, "from", initialVariant, "to", newVariant)
			BackpackService.setPlayerCapacity(player, newCapacity)
			local char = player.Character
			if char then
				onCharacterAdded(player, char, newVariant, newCapacity)
			end
		end
	end)
end

local function onPlayerAdded(player)
	-- Wait for profile accessor and data to be ready to avoid defaulting incorrectly
	local data = waitForProfile(player, 12)
	if not data then
		warn("[BackpackVariantInit][DEBUG] Profile data not ready for", player.Name, "- proceeding with resolver")
	end
	-- Resolve variant and capacity
	local variant = BackpackPreferenceService.resolveVariant(player)
	local capacity = BackpackPreferenceService.getCapacityForVariant(variant)
	print("[BackpackVariantInit][DEBUG] PlayerAdded", player.Name, "variant=", variant, "capacity=", capacity)
	BackpackService.setPlayerCapacity(player, capacity)

	-- Equip on spawn
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char, variant, capacity)
	end)
	-- If character already exists (joined via respawn), handle immediately
	if player.Character then
		task.defer(function()
			onCharacterAdded(player, player.Character, variant, capacity)
		end)
	end

	-- After initial equip, re-resolve once profile becomes available to correct variant if needed
	reResolveWhenProfileReady(player, variant, capacity)
end

for _, plr in ipairs(Players:GetPlayers()) do
	onPlayerAdded(plr)
end
Players.PlayerAdded:Connect(onPlayerAdded)
