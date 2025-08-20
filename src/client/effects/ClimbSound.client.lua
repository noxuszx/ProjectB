-- src/client/effects/ClimbSound.client.lua
-- Plays a climbing loop only while the player is Climbing AND holding a key
-- Rojo client script. Includes debug logs and a raycast check for climbable surfaces.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

-- Config
local DEBUG = true
local CLIMB_KEYS = { Enum.KeyCode.W, Enum.KeyCode.S }
local RAY_LENGTH = 3
local VOLUME = 1
local SOUND_ID = "rbxassetid://136648854966443"
local USE_TAGGED_CLIMBABLE = true
local CLIMBABLE_TAG = "Climbable"

local function dprint(...)
	if DEBUG then
		print("[ClimbSound]", ...)
	end
end

local player = Players.LocalPlayer

local function getCharacter()
	local c = player.Character or player.CharacterAdded:Wait()
	local humanoid = c:WaitForChild("Humanoid")
	if not humanoid.RootPart then
		humanoid:GetPropertyChangedSignal("RootPart"):Wait()
	end
	return c, humanoid, humanoid.RootPart
end

local character, humanoid, root = getCharacter()

-- Detect if the surface in front is a truss or tagged climbable
local function isNearClimbable(rootPart: BasePart)
	local dir = rootPart.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rootPart.Parent }
	local result = workspace:Raycast(rootPart.Position, dir * RAY_LENGTH, params)
	if not result then
		return false
	end
	local inst = result.Instance
	if inst:IsA("TrussPart") then
		return true
	end
	if USE_TAGGED_CLIMBABLE and CollectionService:HasTag(inst, CLIMBABLE_TAG) then
		return true
	end
	-- Also allow ladders built from Mesh/Parts if named with token
	local name = string.lower(inst.Name)
	if string.find(name, "ladder", 1, true) then
		return true
	end
	return false
end

-- Single reusable looped sound on the root
local climbLoop: Sound? = nil
local function ensureSound(parent: Instance)
	if climbLoop and climbLoop.Parent == parent then
		return climbLoop
	end
	if climbLoop then
		climbLoop:Destroy()
		climbLoop = nil
	end
	local s = Instance.new("Sound")
	s.Name = "ClimbLoop"
	s.SoundId = SOUND_ID
	s.Volume = VOLUME
	s.RollOffMode = Enum.RollOffMode.Inverse
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 40
	s.EmitterSize = 5
	s.Looped = true
	s.Parent = parent
	climbLoop = s
	return s
end

-- State
local keyHeldW = false
local keyHeldS = false
local climbing = false

-- Input tracking
UserInputService.InputBegan:Connect(function(input, gp)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.W then
			keyHeldW = true
		elseif input.KeyCode == Enum.KeyCode.S then
			keyHeldS = true
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.W then
			keyHeldW = false
		elseif input.KeyCode == Enum.KeyCode.S then
			keyHeldS = false
		end
	end
end)

-- Humanoid state
local function bindHumanoid(h: Humanoid)
	h.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Climbing then
			climbing = true
		else
			climbing = false
			if climbLoop and climbLoop.IsPlaying then
				climbLoop:Stop()
			end
		end
	end)
end

bindHumanoid(humanoid)

-- Handle respawn
player.CharacterAdded:Connect(function()
	character, humanoid, root = getCharacter()
	bindHumanoid(humanoid)
	climbLoop = nil -- will recreate on demand
	keyHeldW = false
	keyHeldS = false
	climbing = false
end)

-- Drive playback
RunService.Heartbeat:Connect(function()
	if not root or not humanoid then
		return
	end
	local keyHeld = keyHeldW or keyHeldS
	local shouldPlay = climbing and keyHeld and isNearClimbable(root)
	if shouldPlay then
		local s = ensureSound(root)
		if not s.IsPlaying then
			-- slight variance for less monotony
			s.PlaybackSpeed = 0.97 + math.random() * 0.06
			s:Play()
		end
	else
		if climbLoop and climbLoop.IsPlaying then
			climbLoop:Stop()
		end
	end
end)
