-- src/server/events/EgyptDoor.lua
-- Door animation module for the Egypt pyramid entrance
-- Handles smooth sliding door animation using TweenService

local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local EgyptDoor = {}

-- Animation settings
local TWEEN_DURATION = 13.0
local TWEEN_EASING_STYLE = Enum.EasingStyle.Sine
local TWEEN_EASING_DIRECTION = Enum.EasingDirection.InOut

-- Door state tracking
local doorPart = nil
local originalPosition = nil
local openPosition = nil
local currentTween = nil
local doorState = "closed" -- "closed", "opening", "open", "closing"
local doorSound = nil

-- Initialize door references and calculate positions
local function initializeDoor()
	local doors = CollectionServiceTags.getLiveTagged(CollectionServiceTags.EGYPT_DOOR)

	if #doors == 0 then
		warn("[EgyptDoor] No doors found with EGYPT_DOOR tag!")
		return false
	end

	-- Resolve to a BasePart; if the tag is on a Model, use its PrimaryPart
	local inst = doors[1]
	if inst:IsA("Model") then
		if inst.PrimaryPart then
			doorPart = inst.PrimaryPart
		else
			warn("[EgyptDoor] Tagged Model has no PrimaryPart: ", inst:GetFullName())
			return false
		end
	elseif inst:IsA("BasePart") then
		doorPart = inst
	else
		warn("[EgyptDoor] Tagged instance is not a BasePart or Model: ", inst.ClassName)
		return false
	end

	originalPosition = doorPart.Position

	-- Calculate open position (door slides down by its height + buffer)
	local doorHeight = doorPart.Size.Y
	openPosition = originalPosition - Vector3.new(0, doorHeight + 2, 0)

	-- Get reference sound from SoundService and create a copy in the door
	local referenceDoorSound = SoundService:FindFirstChild("Large-Stone-Door")
	if not referenceDoorSound then
		warn("[EgyptDoor] Large-Stone-Door sound not found in SoundService")
		return true
	end

	-- Create a Sound object in the door part for positional audio
	doorSound = Instance.new("Sound")
	doorSound.Name = "DoorSound"
	doorSound.SoundId = referenceDoorSound.SoundId
	doorSound.Volume = referenceDoorSound.Volume
	doorSound.Pitch = referenceDoorSound.Pitch
	doorSound.RollOffMode = Enum.RollOffMode.Linear
	doorSound.EmitterSize = 10
	doorSound.Parent = doorPart

	return true
end

-- Cancel current tween if running
local function cancelCurrentTween()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
end

-- Create tween info for door movement
local function createTweenInfo(durationSeconds)
	return TweenInfo.new(
		durationSeconds or TWEEN_DURATION,
		TWEEN_EASING_STYLE,
		TWEEN_EASING_DIRECTION,
		0, -- RepeatCount
		false, -- Reverses
		0 -- DelayTime
	)
end

-- Open the door (slide down)
function EgyptDoor.openDoor()
	if not doorPart then
		return
	end

	if doorState == "open" or doorState == "opening" then
		return
	end

	doorState = "opening"

	-- Play door sound
	if doorSound then
		doorSound:Play()
	end

	-- Cancel any existing tween
	cancelCurrentTween()

	-- Create and play opening tween
	local tweenInfo = createTweenInfo()
	currentTween = TweenService:Create(doorPart, tweenInfo, {
		Position = openPosition,
	})

	currentTween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			doorState = "open"
		end
		currentTween = nil
	end)

	currentTween:Play()
end

-- Close the door (slide up)
function EgyptDoor.closeDoor(durationSeconds)
	if not doorPart then
		return
	end

	if doorState == "closed" or doorState == "closing" then
		return -- Already closed or closing
	end

	doorState = "closing"

	-- Play door sound
	if doorSound then
		doorSound:Play()
	end

	-- Cancel any existing tween
	cancelCurrentTween()

	-- Create and play closing tween
	local tweenInfo = createTweenInfo(durationSeconds)
	currentTween = TweenService:Create(doorPart, tweenInfo, {
		Position = originalPosition,
	})

	currentTween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			doorState = "closed"
		end
		currentTween = nil
	end)

	currentTween:Play()
end

function EgyptDoor.getDoorState()
	return doorState
end

function EgyptDoor.getDoorPart()
	return doorPart
end

function EgyptDoor.init()
	if not initializeDoor() then
		warn("[EgyptDoor] Door initialization failed!")
		return false
	end

	return true
end

-- Expose tween settings for other systems (e.g., treasure door)
function EgyptDoor.getOpenTweenInfo()
	return createTweenInfo()
end

return EgyptDoor
