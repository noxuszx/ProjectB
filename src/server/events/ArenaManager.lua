local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local ArenaConfig = require(ReplicatedStorage.Shared.config.ArenaConfig)
local CS_tags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local ArenaAIManager = require(script.Parent.Parent.ai.arena.ArenaAIManager)

local ArenaManager = {}

local State  = {
	Inactive = "Inactive",
	Active   = "Active",
	Paused   = "Paused",
	Victory  = "Victory",
}

local currentState = State.Inactive
local arenaStarted = false
local arenaMusic = nil
local startTime, endTime
local remainingDuration = ArenaConfig.DurationSeconds
local waveTriggered = {
						Phase2 = false,
						Phase3 = false
					  }

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
	if ArenaConfig.Paths.TreasureDoor then
		local ok, inst = pcall(function()
			return game:GetService("Workspace"):FindFirstChild(ArenaConfig.Paths.TreasureDoor, true)
		end)
		if ok and inst and inst:IsA("BasePart") then
			return inst
		end
	end
	local tagged = CollectionService:GetTagged(CS_tags.TREASURE_DOOR)
	for _, inst in ipairs(tagged) do
		if inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

local function openTreasureDoor()
	local door = getTreasureDoor()
	if not door then
		return false
	end
	local goal = door.CFrame * CFrame.new(0, -door.Size.Y - 0.1, 0)
	local tween =
		TweenService:Create(door, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal })
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
				EgyptDoor.closeDoor()
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
	startTime = os.clock()
	endTime = startTime + remainingDuration
	waveTriggered = { Phase2 = false, Phase3 = false }

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
	end

	setSealEnabled(true)
	fireAll(ArenaConfig.Remotes.StartTimer, { startTime = startTime, endTime = endTime })

	task.spawn(function()
		while currentState == State.Active do
			if currentState == State.Paused then
				task.wait(0.5)
				continue
			end

			local now = os.clock()
			local remaining = math.max(0, endTime - now)

			local secs = math.floor(remaining + 0.5)
			if not waveTriggered.Phase2 and secs == ArenaConfig.PhaseTimes.Reinforcement then
				local spawner = require(script.Parent.ArenaSpawner)
				pcall(function()
					spawner.spawnSkeleton2Wave()
				end)
				waveTriggered.Phase2 = true
			elseif not waveTriggered.Phase3 and secs == ArenaConfig.PhaseTimes.Elites then
				local spawner = require(script.Parent.ArenaSpawner)
				pcall(function()
					spawner.spawnScorpionElites()
				end)
				waveTriggered.Phase3 = true
			end

			if secs % 3 == 0 then
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
	remainingDuration = math.max(0, endTime - os.clock())
	fireAll(ArenaConfig.Remotes.Pause)
	return true
end

function ArenaManager.resume()
	if currentState ~= State.Paused then
		return false
	end
	currentState = State.Active
	startTime = os.clock()
	endTime = startTime + remainingDuration
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
		local fadeOut = TweenService:Create(arenaMusic, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0
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
	if choice == "lobby" then
		-- teleportToLobby not implemented
	elseif choice == "continue" then
		openTreasureDoor()
	end
end

function ArenaManager.NotifyPlayerDowned(player)
	if not player or not inArena[player.UserId] then
		return
	end
	downedCount += 1
	if downedCount > 0 and currentState == State.Active then
		ArenaManager.pause()
	end
end

function ArenaManager.NotifyPlayerRespawned(player)
	if not player or not inArena[player.UserId] then
		return
	end
	if downedCount > 0 then
		downedCount -= 1
	end
	if downedCount <= 0 and currentState == State.Paused then
		ArenaManager.resume()
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
			ArenaManager.onPlayerChoice(player, choice)
		end)
	end
end

connectRemotes()

return ArenaManager
