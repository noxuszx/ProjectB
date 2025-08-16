-- src/client/ui/core/RemoteRegistry.lua
-- Resolve and cache remotes in one place

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaConfig = require(ReplicatedStorage.Shared.config.ArenaConfig)

local Registry = {}
Registry.__index = Registry

local function waitForChildTimeout(parent, name, timeout)
	local inst = parent:FindFirstChild(name)
	if inst then return inst end
	local ok, res = pcall(function()
		return parent:WaitForChild(name, timeout)
	end)
	if ok then return res end
	return nil
end

function Registry.new()
	local self = setmetatable({}, Registry)
	self.Arena = {}
	self.Death = {}
	return self
end

function Registry:init(timeout)
	timeout = timeout or 10
	local remotes = waitForChildTimeout(ReplicatedStorage, "Remotes", timeout)
	if not remotes then return false end
	-- Arena
	local arenaFolder = waitForChildTimeout(remotes, ArenaConfig.Remotes.Folder, timeout)
	if arenaFolder then
		self.Arena.StartTimer = waitForChildTimeout(arenaFolder, ArenaConfig.Remotes.StartTimer, timeout)
		self.Arena.Pause = waitForChildTimeout(arenaFolder, ArenaConfig.Remotes.Pause, timeout)
		self.Arena.Resume = waitForChildTimeout(arenaFolder, ArenaConfig.Remotes.Resume, timeout)
		self.Arena.Sync = waitForChildTimeout(arenaFolder, ArenaConfig.Remotes.Sync, timeout)
		self.Arena.Victory = waitForChildTimeout(arenaFolder, ArenaConfig.Remotes.Victory, timeout)
		self.Arena.PostGameChoice = waitForChildTimeout(arenaFolder, ArenaConfig.Remotes.PostGameChoice, timeout)
	end
	-- Death
	local deathFolder = remotes:FindFirstChild("Death")
	if deathFolder then
		self.Death.ShowUI = deathFolder:FindFirstChild("ShowUI")
		self.Death.RequestRespawn = deathFolder:FindFirstChild("RequestRespawn")
		self.Death.RevivalFeedback = deathFolder:FindFirstChild("RevivalFeedback")
	end
	return true
end

return Registry

