-- src/client/ui/UIManager.lua
-- Binds PlayerGui, caches GUI refs, subscribes to store, and renders screens

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Store = require(script.Parent.core.Store)
local Maid = require(script.Parent.core.Maid)
local RemoteRegistry = require(script.Parent.core.RemoteRegistry)

local UIManager = {}
UIManager.__index = UIManager

export type Refs = {
	Arena: {
		Gui: ScreenGui?,
		MainText: TextLabel?,
		TimerText: TextLabel?,
	},
	Victory: {
		Gui: ScreenGui?,
		TextLabel: TextLabel?,
		TextTimer: TextLabel?,
		VictoryFrame: Frame?,
		LobbyBTN: TextButton?,
		ContinueBTN: TextButton?,
	},
	Death: {
		Gui: ScreenGui?,
	},
}

local function getPlayerGui()
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function bindRefs(): Refs
	local pg = getPlayerGui()
	local refs: Refs = {
		Arena = { Gui = pg:FindFirstChild("ArenaGui") :: ScreenGui },
		Victory = { Gui = pg:FindFirstChild("VictoryGui") :: ScreenGui },
		Death = { Gui = pg:FindFirstChild("DeathGui") :: ScreenGui },
	}
	if refs.Arena.Gui then
		refs.Arena.MainText = refs.Arena.Gui:FindFirstChild("MainText") :: TextLabel
		refs.Arena.TimerText = refs.Arena.Gui:FindFirstChild("TimerText") :: TextLabel
	end
	if refs.Victory.Gui then
		refs.Victory.TextLabel = refs.Victory.Gui:FindFirstChild("TextLabel") :: TextLabel
		refs.Victory.TextTimer = refs.Victory.Gui:FindFirstChild("TextTimer") :: TextLabel
		refs.Victory.VictoryFrame = refs.Victory.Gui:FindFirstChild("VictoryFrame") :: Frame
		if refs.Victory.VictoryFrame then
			refs.Victory.LobbyBTN = refs.Victory.VictoryFrame:FindFirstChild("LobbyBTN") :: TextButton
			refs.Victory.ContinueBTN = refs.Victory.VictoryFrame:FindFirstChild("ContinueBTN") :: TextButton
		end
	end
	return refs
end

local ArenaRenderer = require(script.Parent.renderers.ArenaRenderer)
local VictoryRenderer = require(script.Parent.renderers.VictoryRenderer)
local DeathRenderer = require(script.Parent.renderers.DeathRenderer)

function UIManager.new(store: any, registry: any)
	local self = setmetatable({}, UIManager)
	self._store = store
	self._registry = registry
	-- Separate maids: one for global lifetime, one for per-binding subscriptions/buttons
	self._maidGlobal = Maid.new()
	self._maidBindings = Maid.new()
	self.refs = bindRefs()
	return self
end

function UIManager:_wireButtons()
	local r = self.refs
	if r.Victory.Gui and r.Victory.LobbyBTN then
		self._maidBindings:give(r.Victory.LobbyBTN.MouseButton1Click:Connect(function()
			if self._registry.Arena.PostGameChoice then
				self._registry.Arena.PostGameChoice:FireServer({ choice = "lobby" })
			end
			-- hide via state
			self._store:set({ victory = { visible = false } })
		end))
	end
	if r.Victory.Gui and r.Victory.ContinueBTN then
		self._maidBindings:give(r.Victory.ContinueBTN.MouseButton1Click:Connect(function()
			if self._registry.Arena.PostGameChoice then
				self._registry.Arena.PostGameChoice:FireServer({ choice = "continue" })
			end
			self._store:set({ victory = { visible = false } })
		end))
	end
end

function UIManager:_subscribe()
	local unsubscribe = self._store:subscribe(function(state)
		local r = self.refs
		local arenaState = state.arena or {}
		local victoryState = state.victory or {}
		local deathState = state.death or {}
		local now = state.now or os.clock()

		-- Routing rules: Death UI overrides others; Arena hidden while death visible
		local arenaForRender = { active = (arenaState.active == true) and (deathState.visible ~= true), endTime = arenaState.endTime }
		local victoryForRender = { visible = (victoryState.visible == true) and (deathState.visible ~= true), message = victoryState.message }

		ArenaRenderer.render(r.Arena, arenaForRender, now)
		VictoryRenderer.render(r.Victory, victoryForRender, now)
		DeathRenderer.render(r.Death, deathState, now)
	end)
	self._maidBindings:give(unsubscribe)
end

function UIManager:_rebindOnRespawn()
	local player = Players.LocalPlayer
	-- Keep this connection for the lifetime of UIManager
	self._maidGlobal:give(player.CharacterAdded:Connect(function()
		-- Rebind refs after a short defer so PlayerGui children exist
		task.defer(function()
			self._maidBindings:clean()
			self.refs = bindRefs()
			self:_wireButtons()
			self:_subscribe()
			-- Force a render with current state
			self._store:set({})
		end)
	end))
	-- Also watch for GUI children appearing later (after PlayerGui reconstructs)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._maidGlobal:give(pg.ChildAdded:Connect(function(child)
		if child.Name == "ArenaGui" or child.Name == "VictoryGui" or child.Name == "DeathGui" then
			-- Rebind only lightweight: refresh refs and rewire buttons/subscriptions
			self._maidBindings:clean()
			self.refs = bindRefs()
			self:_wireButtons()
			self:_subscribe()
			self._store:set({})
		end
	end))
end

function UIManager:init()
	self:_wireButtons()
	self:_subscribe()
	self:_rebindOnRespawn()
end

return UIManager

