local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")

local ArenaConfig = require(ReplicatedStorage.Shared.config.ArenaConfig)
local CS_tags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local ArenaAIManager = require(script.Parent.Parent.ai.arena.ArenaAIManager)

local ArenaManager = {}

local State = {
	Inactive = "Inactive",
	Active = "Active",
	Paused = "Paused",
	Victory = "Victory",
}

-- Single-player lobby teleport settings
local LOBBY_PLACE_ID = 104756079644077 -- provided by user
local _teleporting = {}

local function teleportPlayerToLobby(player)
	if not player or player.Parent ~= Players then
		return false
	end
	local userId = player.UserId
	if _teleporting[userId] then
		return false
	end
	_teleporting[userId] = true
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(LOBBY_PLACE_ID, { player })
	end)
	if not ok then
		warn("[Arena] Teleport to lobby failed for", player.Name, "error:", err)
		_teleporting[userId] = nil
		return false
	end
	return true
end
-- Returns a list of Vector3 positions for teleporting players into the arena
local function getTeleportPositions()
	local okTagged, tagged = pcall(function()
		return CollectionService:GetTagged(CS_tags.ARENA_TELEPORT_MARKER)
	end)
	local positions = {}
	if okTagged and tagged then
		for _, inst in ipairs(tagged) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
				table.insert(positions, inst.Position)
			end
		end
	end
	if #positions > 0 then
		return positions
	end
	-- Fallback to explicit folder path if configured
	if ArenaConfig.Paths.TeleportMarkersFolder then
		local okFolder, folder = pcall(function()
			return workspace:FindFirstChild(ArenaConfig.Paths.TeleportMarkersFolder, true)
		end)
		if okFolder and folder then
			for _, part in ipairs(folder:GetChildren()) do
				if part:IsA("BasePart") then
					table.insert(positions, part.Position)
				end
			end
		end
		if #positions > 0 then
			return positions
		end
	end
	-- Final fallback to static config
	return ArenaConfig.TeleportPositions or {}
end

function ArenaManager.teleportPlayerToArena(player)
	if not player or not player.Character then
		return false
	end
	local model = player.Character
	if not model.PrimaryPart then
		return false
	end
	local positions = getTeleportPositions()
	if #positions == 0 then
		warn("[Arena] teleportPlayerToArena: No teleport positions available")
		return false
	end
	local target = positions[math.random(1, #positions)]
	local ok, err = pcall(function()
		model:PivotTo(CFrame.new(target))
	end)
	if not ok then
		warn("[Arena] teleportPlayerToArena failed:", err)
		return false
	end
	return true
end

local currentState = State.Inactive
local arenaStarted = false
local arenaMusic = nil
local startTime, endTime
local remainingDuration = ArenaConfig.DurationSeconds
local waveTriggered = {
	Phase2 = false,
	Phase3 = false,
}
-- Track last whole-second remaining to detect threshold crossings robustly
local _lastRemainingSecs = nil

local inArena = {}
local downedCount = 0

----------------------------------------------------------------------------------------

local function getArenaRemote(name)
	local arenaFolder = ReplicatedStorage:FindFirstChild("Remotes")
		and ReplicatedStorage.Remotes:FindFirstChild(ArenaConfig.Remotes.Folder)
	if not arenaFolder then
		return nil
	end
	return arenaFolder:FindFirstChild(name)
end

local function fireAll(remoteName, payload)
	local r = getArenaRemote(remoteName)
	if r then
		r:FireAllClients(payload)
	end
end

local function getTreasureDoor()
	-- Prefer an explicit path if provided, but ensure it's in the live world
	if ArenaConfig.Paths.TreasureDoor then
		local ok, inst = pcall(function()
			return game:GetService("Workspace"):FindFirstChild(ArenaConfig.Paths.TreasureDoor, true)
		end)
		if ok and inst then
			if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
				return inst
			elseif inst:IsA("Model") and inst.PrimaryPart and inst.PrimaryPart:IsDescendantOf(workspace) then
				return inst.PrimaryPart
			end
		end
	end
	-- Match EgyptDoor logic: only use live, in-world tagged instances
	local liveTagged = CS_tags.getLiveTagged(CS_tags.TREASURE_DOOR)
	for _, inst in ipairs(liveTagged) do
		if not inst:IsDescendantOf(workspace) then
			continue
		end
		if inst:IsA("BasePart") then
			return inst
		elseif inst:IsA("Model") and inst.PrimaryPart and inst.PrimaryPart:IsDescendantOf(workspace) then
			return inst.PrimaryPart
		end
	end
	return nil
end

local function openTreasureDoor()
	local door = getTreasureDoor()
	if not door then
		local taggedCount = 0
		local okTagged, tagged = pcall(function()
			return CollectionService:GetTagged(CS_tags.TREASURE_DOOR)
		end)
		if okTagged and tagged then
			taggedCount = #tagged
		end
		warn(
			"[Arena] openTreasureDoor: No door found. ArenaConfig.Paths.TreasureDoor=",
			tostring(ArenaConfig.Paths.TreasureDoor),
			" taggedCount=",
			taggedCount
		)
		return false
	end
	-- Basic sanity checks that commonly block movement
	if door.Anchored then
		warn(
			"[Arena] openTreasureDoor: Door is Anchored (",
			door:GetFullName(),
			") — tween may have no visible effect."
		)
	end
	local okConn, connected = pcall(function()
		return door:GetConnectedParts(true)
	end)
	if okConn and connected then
		for _, p in ipairs(connected) do
			if p ~= door and p.Anchored then
				warn(
					"[Arena] openTreasureDoor: Door is connected to an anchored part (",
					p:GetFullName(),
					") — CFrame tween may be blocked."
				)
				break
			end
		end
	end
	-- Compute target position (match EgyptDoor behavior: slide down by height + small buffer)
	local goalPos = door.Position + Vector3.new(0, -door.Size.Y - 0.1, 0)
	-- Play the same door sound used by EgyptDoor, if available
	local referenceDoorSound = SoundService:FindFirstChild("Large-Stone-Door")
	if referenceDoorSound then
		local s = Instance.new("Sound")
		s.Name = "TreasureDoorSound"
		s.SoundId = referenceDoorSound.SoundId
		s.Volume = referenceDoorSound.Volume
		s.Pitch = referenceDoorSound.Pitch
		s.RollOffMode = Enum.RollOffMode.Linear
		s.EmitterSize = 10
		s.Parent = door
		s:Play()
		s.Ended:Connect(function()
			s:Destroy()
		end)
	end
	warn("[Arena] openTreasureDoor: Tweening door ", door:GetFullName(), " down by height.")
	-- Use EgyptDoor's opening tween settings if available; fallback to previous quick tween
	local tweenInfo
	do
		local okEgypt, EgyptDoor = pcall(function()
			return require(script.Parent.EgyptDoor)
		end)
		if okEgypt and EgyptDoor and EgyptDoor.getOpenTweenInfo then
			local okInfo, info = pcall(function()
				return EgyptDoor.getOpenTweenInfo()
			end)
			if okInfo and info then
				tweenInfo = info
			end
		end
	end
	if not tweenInfo then
		-- Fallback: 2s Quad Out (legacy)
		tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	local tween = TweenService:Create(door, tweenInfo, { Position = goalPos })
	tween:Play()
	return true
end

local function setSealEnabled(enabled)
	local ok, EgyptDoor = pcall(function()
		return require(script.Parent.EgyptDoor)
	end)
	if ok and EgyptDoor then
		if enabled then
			pcall(function()
				-- Close quickly at arena start (3s)
				EgyptDoor.closeDoor(3.0)
			end)
		else
			pcall(function()
				EgyptDoor.openDoor()
			end)
		end
		return
	end
	local seals = CollectionService:GetTagged(CS_tags.PYRAMID_SEAL)
	for _, part in ipairs(seals) do
		if part:IsA("BasePart") then
			part.CanCollide = enabled
			part.Transparency = enabled and 0 or 1
		end
	end
end

function ArenaManager.getState()
	return currentState
end

function ArenaManager.start()
	if arenaStarted or not ArenaConfig.Enabled then
		return false
	end
	arenaStarted = true
	currentState = State.Active
	remainingDuration = ArenaConfig.DurationSeconds
	-- Use server-synchronized time so clients can render countdown correctly
	startTime = workspace:GetServerTimeNow()
endTime = startTime + remainingDuration
waveTriggered = { Phase2 = false, Phase3 = false }
_lastRemainingSecs = math.huge
print(
	string.format(
		"[Arena][start] dur=%ss start=%.3f end=%.3f players=%d",
		tostring(remainingDuration),
		startTime,
		endTime,
		#Players:GetPlayers()
		)
)

	-- Play arena sounds
	local arenaStartSound = SoundService:FindFirstChild("ArenaStart")
	if arenaStartSound then
		arenaStartSound:Play()
	end

	arenaMusic = SoundService:FindFirstChild("ArenaMusic")
	if arenaMusic then
		arenaMusic.Looped = true
		arenaMusic:Play()
	end

	for _, p in ipairs(Players:GetPlayers()) do
		inArena[p.UserId] = true
	end

	-- Start the Arena AI Manager
	local aiManager = ArenaAIManager.getInstance()
	if not aiManager.isActive then
		aiManager:start()
	else
		aiManager:resume()
	end

	setSealEnabled(true)
	fireAll(ArenaConfig.Remotes.StartTimer, { startTime = startTime, endTime = endTime })

	task.spawn(function()
		while currentState == State.Active do
			if currentState == State.Paused then
				task.wait(0.5)
				continue
			end

			-- Compute remaining using server time, not os.clock()
			local now = workspace:GetServerTimeNow()
			local remaining = math.max(0, endTime - now)

			local secs = math.floor(remaining + 0.5)
			-- Robust threshold crossing detection so pauses don't skip spawns
			local reinforceAt = ArenaConfig.PhaseTimes.Reinforcement
			local elitesAt = ArenaConfig.PhaseTimes.Elites
			if not waveTriggered.Phase2 and secs <= reinforceAt and (_lastRemainingSecs == nil or _lastRemainingSecs > reinforceAt) then
				local spawner = require(script.Parent.ArenaSpawner)
				print(string.format("[Arena][spawn] Reinforcement at %ds (prev=%s)", secs, tostring(_lastRemainingSecs)))
				pcall(function()
					spawner.spawnSkeleton2Wave()
				end)
				waveTriggered.Phase2 = true
			end
			if not waveTriggered.Phase3 and secs <= elitesAt and (_lastRemainingSecs == nil or _lastRemainingSecs > elitesAt) then
				local spawner = require(script.Parent.ArenaSpawner)
				print(string.format("[Arena][spawn] Elites at %ds (prev=%s)", secs, tostring(_lastRemainingSecs)))
				pcall(function()
					spawner.spawnScorpionElites()
				end)
				waveTriggered.Phase3 = true
			end
			_lastRemainingSecs = secs

			if secs % 3 == 0 then
				print(
					string.format(
						"[Arena][sync] now=%.3f end=%.3f remaining=%ds state=%s",
						now,
						endTime,
						secs,
						tostring(currentState)
					)
				)
				fireAll(ArenaConfig.Remotes.Sync, { endTime = endTime })
			end

			if remaining <= 0 then
				break
			end

			task.wait(1)
		end

		if currentState == State.Active then
			ArenaManager.victory()
		end
	end)
	local spawner = require(script.Parent.ArenaSpawner)
	pcall(function()
		spawner.spawnSkeletonMummyWave()
	end)

	return true
end

function ArenaManager.pause()
	if currentState ~= State.Active then
		return false
	end
	currentState = State.Paused
	remainingDuration = math.max(0, endTime - workspace:GetServerTimeNow())
	print(string.format("[Arena][pause] remaining=%ds downed=%d", math.floor(remainingDuration + 0.5), downedCount))
	pcall(function()
		local ai = ArenaAIManager.getInstance()
		ai:pause()
	end)
	fireAll(ArenaConfig.Remotes.Pause)
	return true
end

function ArenaManager.resume()
	if currentState ~= State.Paused then
		return false
	end
	currentState = State.Active
	startTime = workspace:GetServerTimeNow()
endTime = startTime + remainingDuration
-- Reset last-secs tracker to a sentinel so any missed thresholds can fire once after resume.
-- waveTriggered flags prevent double-firing if a phase already triggered before the pause.
_lastRemainingSecs = math.huge
print(
	string.format(
		"[Arena][resume] start=%.3f end=%.3f remaining=%ds downed=%d",
		startTime,
		endTime,
		math.floor(remainingDuration + 0.5),
		downedCount
		)
)
pcall(function()
	local ai = ArenaAIManager.getInstance()
	ai:resume()
end)
fireAll(ArenaConfig.Remotes.Resume, { startTime = startTime, endTime = endTime })
return true
end

function ArenaManager.victory()
	if currentState == State.Victory then
		return false
	end
	currentState = State.Victory

	-- Fade out arena music
	if arenaMusic and arenaMusic.IsPlaying then
		local fadeOut =
			TweenService:Create(arenaMusic, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Volume = 0,
			})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			arenaMusic:Stop()
			arenaMusic.Volume = arenaMusic.Volume > 0 and arenaMusic.Volume or 0.5 -- Reset volume for next time
		end)
	end

	-- Stop the Arena AI Manager and clean up creatures
	local aiManager = ArenaAIManager.getInstance()
	if aiManager.isActive then
		aiManager:stop()
	end

	-- Increment wins for players who are still in the arena (considered winners)
	do
		local accessor = _G and _G.ProfileAccessor
		if accessor and accessor.updateProfileData then
			for _, p in ipairs(Players:GetPlayers()) do
				if inArena[p.UserId] and p.Parent ~= nil then
					pcall(function()
						accessor:updateProfileData(p, function(data)
							data.Wins = (tonumber(data.Wins) or 0) + 1
						end)
					end)
				end
			end
		else
			warn("[Arena] ProfileAccessor not available; cannot increment Wins")
		end
	end

	-- Clean up arena spawner
	local ArenaSpawner = require(script.Parent.ArenaSpawner)
	if ArenaSpawner.cleanup then
		ArenaSpawner.cleanup()
	end

	setSealEnabled(false)
	fireAll(ArenaConfig.Remotes.Victory, { message = ArenaConfig.UI.VictoryMessage })
	return true
end

function ArenaManager.openTreasureDoor()
	return openTreasureDoor()
end

function ArenaManager.onPlayerChoice(player, choice)
	warn("[Arena] PostGameChoice from ", player and player.Name or "?", " choice:", tostring(choice))
	if choice == "lobby" then
		teleportPlayerToLobby(player) -- single-player teleport only
	elseif choice == "continue" then
		local ok, res = pcall(openTreasureDoor)
		if not ok then
			warn("[Arena] openTreasureDoor failed:", res)
		end
	end
end

function ArenaManager.NotifyPlayerDowned(player)
	if not player or not inArena[player.UserId] then
		return
	end
	downedCount += 1
	print(
		string.format(
			"[Arena][downed] %s downed; downedCount=%d state=%s",
			player.Name,
			downedCount,
			tostring(currentState)
		)
	)
	-- Only pause when ALL players in the arena are downed.
	if currentState == State.Active then
		local totalInArena = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if inArena[p.UserId] then
				totalInArena += 1
			end
		end
		print(string.format("[Arena][check] totalInArena=%d downed=%d", totalInArena, downedCount))
		if totalInArena > 0 and downedCount >= totalInArena then
			ArenaManager.pause()
		end
	end
end

function ArenaManager.NotifyPlayerRespawned(player)
	if not player or not inArena[player.UserId] then
		return
	end
	if downedCount > 0 then
		downedCount -= 1
	end
	print(
		string.format(
			"[Arena][respawn] %s respawned; downedCount=%d state=%s",
			player.Name,
			downedCount,
			tostring(currentState)
		)
	)
	-- Resume as soon as at least one player is alive (i.e., not all are down).
	if currentState == State.Paused then
		local totalInArena = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if inArena[p.UserId] then
				totalInArena += 1
			end
		end
		print(string.format("[Arena][check] totalInArena=%d downed=%d", totalInArena, downedCount))
		if totalInArena > 0 and downedCount < totalInArena then
			ArenaManager.resume()
		end
	end
end

-- Remote hookup
local function connectRemotes()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
		and ReplicatedStorage.Remotes:FindFirstChild(ArenaConfig.Remotes.Folder)
	if not folder then
		return
	end
	local post = folder:FindFirstChild(ArenaConfig.Remotes.PostGameChoice)
	if post then
		post.OnServerEvent:Connect(function(player, payload)
			local choice = payload and payload.choice
			warn(
				"[Arena] Received PostGameChoice remote from ",
				player and player.Name or "?",
				" with choice:",
				tostring(choice)
			)
			ArenaManager.onPlayerChoice(player, choice)
		end)
	else
		warn("[Arena] PostGameChoice remote not found under Remotes/", tostring(ArenaConfig.Remotes.Folder))
	end
end

connectRemotes()

return ArenaManager
