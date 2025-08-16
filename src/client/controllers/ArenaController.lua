-- src/client/controllers/ArenaController.lua
-- Listens to Arena remotes and updates Store state

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaConfig = require(ReplicatedStorage.Shared.config.ArenaConfig)

local ArenaController = {}
ArenaController.__index = ArenaController

function ArenaController.new(store, registry)
	local self = setmetatable({}, ArenaController)
	self._store = store
	self._registry = registry
	return self
end

function ArenaController:init()
	local r = self._registry.Arena
	if r.StartTimer then
		r.StartTimer.OnClientEvent:Connect(function(data)
			self._store:set({ arena = { active = true, endTime = data.endTime } })
		end)
	end
	if r.Sync then
		r.Sync.OnClientEvent:Connect(function(data)
			self._store:set({ arena = { active = true, endTime = data.endTime } })
		end)
	end
	if r.Resume then
		r.Resume.OnClientEvent:Connect(function(data)
			self._store:set({ arena = { active = true, endTime = data.endTime } })
		end)
	end
	if r.Pause then
		r.Pause.OnClientEvent:Connect(function()
			-- Keep active flag but freeze endTime by not updating it; renderer derives from now
		end)
	end
	if r.Victory then
		r.Victory.OnClientEvent:Connect(function(data)
			self._store:set({ arena = { active = false }, victory = { visible = true, message = (data and data.message) or "VICTORY!" } })
		end)
	end
end

return ArenaController

