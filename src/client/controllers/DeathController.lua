-- src/client/controllers/DeathController.lua
-- Listens to Death remotes and updates Store state

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathController = {}
DeathController.__index = DeathController

function DeathController.new(store, registry)
	local self = setmetatable({}, DeathController)
	self._store = store
	self._registry = registry
	return self
end

function DeathController:init()
	local r = self._registry.Death
	if r.ShowUI then
r.ShowUI.OnClientEvent:Connect(function(timeoutSeconds)
			print("[DeathController] ShowUI:", timeoutSeconds)
			-- Show Death UI and hide Victory if necessary
			self._store:set({ death = { visible = true, timeoutSeconds = timeoutSeconds or 0 } })
		end)
	end
	if r.RequestRespawn then
		-- RequestRespawn is a client->server event; button wiring is in UIManager or legacy script
	end
	if r.RevivalFeedback then
		-- Hide Death UI when the server confirms a revival (covers revive flows without CharacterAdded firing)
r.RevivalFeedback.OnClientEvent:Connect(function(payload)
			print("[DeathController] RevivalFeedback payload=", payload)
			self._store:set({ death = { visible = false } })
		end)
	end
	-- Hide death UI on character spawn
	local player = Players.LocalPlayer
player.CharacterAdded:Connect(function(char)
		print("[DeathController] CharacterAdded:", char and char.Name)
		self._store:set({ death = { visible = false } })
	end)
end

return DeathController

