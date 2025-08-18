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
		DeathFrame: Frame?,
		ReviveBTN: TextButton?,
		LobbyBTN: TextButton?,
		ReviveAllBTN: TextButton?,
	},
}

local function getPlayerGui()
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function findVictoryGui(pg): ScreenGui?
	local exact = (pg:FindFirstChild("VictoryGui") or pg:FindFirstChild("VictoryUI"))
	if exact and exact:IsA("ScreenGui") then return exact end
	-- Heuristic: any ScreenGui with name containing "victor"
	for _, child in ipairs(pg:GetChildren()) do
		if child:IsA("ScreenGui") then
			local name = string.lower(child.Name)
			if string.find(name, "victor") then return child end
			-- Or any ScreenGui with a child TextLabel named Victory/Title
			local tl = child:FindFirstChild("TextLabel") or child:FindFirstChild("Title")
			if tl and tl:IsA("TextLabel") then
				local txt = string.lower(tl.Text or "")
				if string.find(txt, "victor") or string.find(txt, "win") then
					return child
				end
			end
		end
	end
	return nil
end

local function bindRefs(): Refs
	local pg = getPlayerGui()
	-- Allow common alias names and heuristics to reduce configuration errors
	local victoryGui = findVictoryGui(pg) :: ScreenGui
	local deathGui = (pg:FindFirstChild("DeathGui") or pg:FindFirstChild("DeathUI")) :: ScreenGui
	local refs: Refs = {
		Arena = { Gui = pg:FindFirstChild("ArenaGui") :: ScreenGui },
		Victory = { Gui = victoryGui },
		Death = { Gui = deathGui },
	}
	if refs.Arena.Gui then
		refs.Arena.MainText = refs.Arena.Gui:FindFirstChild("MainText") :: TextLabel
		refs.Arena.TimerText = refs.Arena.Gui:FindFirstChild("TimerText") :: TextLabel
	end
	if refs.Victory.Gui then
		refs.Victory.TextLabel = (refs.Victory.Gui:FindFirstChild("TextLabel") or refs.Victory.Gui:FindFirstChild("Title")) :: TextLabel
		refs.Victory.TextTimer = (refs.Victory.Gui:FindFirstChild("TextTimer") or refs.Victory.Gui:FindFirstChild("Timer")) :: TextLabel
		refs.Victory.VictoryFrame = (refs.Victory.Gui:FindFirstChild("VictoryFrame") or refs.Victory.Gui:FindFirstChild("Frame")) :: Frame
		if refs.Victory.VictoryFrame then
			refs.Victory.LobbyBTN = (refs.Victory.VictoryFrame:FindFirstChild("LobbyBTN") or refs.Victory.VictoryFrame:FindFirstChild("Lobby") or refs.Victory.VictoryFrame:FindFirstChild("LobbyButton")) :: TextButton
			refs.Victory.ContinueBTN = (refs.Victory.VictoryFrame:FindFirstChild("ContinueBTN") or refs.Victory.VictoryFrame:FindFirstChild("Continue") or refs.Victory.VictoryFrame:FindFirstChild("ContinueButton")) :: TextButton
		end
	end
	if refs.Death.Gui then
		refs.Death.DeathFrame = (refs.Death.Gui:FindFirstChild("DeathFrame") or refs.Death.Gui:FindFirstChild("Frame")) :: Frame
		if refs.Death.DeathFrame then
			refs.Death.ReviveBTN = (refs.Death.DeathFrame:FindFirstChild("ReviveBTN") or refs.Death.DeathFrame:FindFirstChild("Revive") or refs.Death.DeathFrame:FindFirstChild("ReviveButton")) :: TextButton
			refs.Death.LobbyBTN = (refs.Death.DeathFrame:FindFirstChild("LobbyBTN") or refs.Death.DeathFrame:FindFirstChild("Lobby") or refs.Death.DeathFrame:FindFirstChild("LobbyButton")) :: TextButton
			refs.Death.ReviveAllBTN = (refs.Death.DeathFrame:FindFirstChild("ReviveAllBTN") or refs.Death.DeathFrame:FindFirstChild("RevivAllBTN")) :: TextButton
		end
	end
	return refs
end

local function waitForVictoryRefsAsync(self)
	if self._waitingVictory then return end
	self._waitingVictory = true
	task.spawn(function()
		local pg = getPlayerGui()
		local deadline = os.clock() + 3
		while os.clock() < deadline do
			local gui = findVictoryGui(pg)
			if gui then
				-- Refresh refs and trigger a re-render
				self.refs = bindRefs()
				self._waitingVictory = false
				-- Nudge store to re-render with same state
				self._store:set({})
				return
			end
			task.wait(0.1)
		end
		self._waitingVictory = false
	end)
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
	self._lastDebugKey = nil -- for state-change debug logging
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
	-- Wire Death UI developer product buttons centrally
	if r.Death.Gui and r.Death.ReviveBTN then
		local deathRemotes = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Death")
		local requestPurchase = deathRemotes and deathRemotes:FindFirstChild("RequestPurchase")
		if requestPurchase then
			self._maidBindings:give(r.Death.ReviveBTN.MouseButton1Click:Connect(function()
				requestPurchase:FireServer("SELF_REVIVE")
			end))
			if r.Death.ReviveAllBTN then
				self._maidBindings:give(r.Death.ReviveAllBTN.MouseButton1Click:Connect(function()
					requestPurchase:FireServer("REVIVE_ALL")
				end))
			end
		end
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

		-- If victory should be visible but we don't have refs yet, try to rebind or wait briefly for it
		if victoryForRender.visible and (not r or not r.Victory or not r.Victory.Gui) then
			local newRefs = bindRefs()
			if newRefs and newRefs.Victory and newRefs.Victory.Gui then
				self.refs = newRefs
				r = self.refs
			else
				if not self._warnedVictoryMissing then
					self._warnedVictoryMissing = true
					local pg = getPlayerGui()
					local names = {}
					for _, c in ipairs(pg:GetChildren()) do table.insert(names, c.Name) end
					print("[UIManager][warn] Victory visible but VictoryGui not found. PlayerGui children:", table.concat(names, ", "))
				end
				-- Start an async wait to bind when it appears
				waitForVictoryRefsAsync(self)
			end
		elseif not victoryForRender.visible then
			self._warnedVictoryMissing = false
		end

		-- Debug: log state changes succinctly
		local dbgKey = string.format("arena:%s end:%s | victory:%s | death:%s",
			 tostring(arenaForRender.active), tostring(arenaForRender.endTime), tostring(victoryForRender.visible), tostring(deathState.visible))
		if self._lastDebugKey ~= dbgKey then
			self._lastDebugKey = dbgKey
			print("[UIManager]", dbgKey)
		end

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

