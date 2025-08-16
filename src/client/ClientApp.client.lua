-- src/client/ClientApp.client.lua
-- Bootstraps the UI system without Fusion/Roact

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIRuntimeConfig = require(ReplicatedStorage.Shared.modules.UIRuntimeConfig)
local Store = require(ReplicatedStorage.Shared and script.Parent.ui.core.Store or script.Parent.ui.core.Store) -- fallback path handling
local RemoteRegistry = require(script.Parent.ui.core.RemoteRegistry)
local UIManager = require(script.Parent.ui.UIManager)
local ArenaController = require(script.Parent.controllers.ArenaController)
local DeathController = require(script.Parent.controllers.DeathController)

if not UIRuntimeConfig.UseUIManager then
	return
end

-- Init store
local store = Store.new(nil)

-- Init remote registry
local registry = RemoteRegistry.new()
registry:init(10)

-- Init UI manager
local uiManager = UIManager.new(store, registry)
uiManager:init()

-- Init controllers
local arenaCtl = ArenaController.new(store, registry)
arenaCtl:init()
local deathCtl = DeathController.new(store, registry)
deathCtl:init()

-- Heartbeat tick to update 'now' and drive derived timers
local lastUpdate = 0
RunService.Heartbeat:Connect(function(dt)
	lastUpdate += dt
	if lastUpdate > 0.1 then -- 10 Hz
		lastUpdate = 0
		store:set({ now = os.clock() })
	end
end)

