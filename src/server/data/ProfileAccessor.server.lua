-- src/server/data/ProfileAccessor.server.lua
-- Bootstraps ProfileService usage and exposes a simple accessor on _G.ProfileAccessor.
-- Shared across systems that need to read/update player profile data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local okPS, ProfileService = pcall(function()
	return require(ServerScriptService.data:WaitForChild("ProfileService"))
end)
if not okPS then
	warn("[ProfileAccessor] Failed to require ProfileService:", ProfileService)
	return
end

local ProfileSchema = require(ReplicatedStorage.Shared.profile.ProfileSchema)

local STORE_NAME = "ProjectB_ProfileStore_v1"
local profileStore = ProfileService.GetProfileStore(STORE_NAME, ProfileSchema.Defaults)

local _profiles = {}

local function onPlayerAdded(player)
	local profileKey = tostring(player.UserId)
	local profile = profileStore:LoadProfileAsync("Player_" .. profileKey, "ForceLoad")
	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			_profiles[player] = nil
			-- Do not kick on data release; this commonly happens during teleports/handoffs
			print("[ProfileAccessor] Profile released for", player and player.Name)
		end)
		if player.Parent then
			_profiles[player] = profile
		else
			profile:Release()
		end
	else
		player:Kick("Could not load your data. Please rejoin.")
	end
end

local function onPlayerRemoving(player)
	local profile = _profiles[player]
	if profile then
		profile:Release()
		_profiles[player] = nil
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

local Accessor = {}

function Accessor:getProfileData(player)
	local profile = _profiles[player]
	return profile and profile.Data or nil
end

function Accessor:updateProfileData(player, mutator)
	local profile = _profiles[player]
	if not profile then
		return false
	end
	local ok, err = pcall(function()
		mutator(profile.Data)
	end)
	if not ok then
		warn("[ProfileAccessor] updateProfileData error:", err)
		return false
	end
	return true
end

_G.ProfileAccessor = Accessor

print("[ProfileAccessor] Initialized and _G.ProfileAccessor is available")
