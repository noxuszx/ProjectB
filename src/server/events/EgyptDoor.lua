-- src/server/events/EgyptDoor.lua
-- Door animation module for the Egypt pyramid entrance
-- Handles smooth sliding door animation using TweenService

local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local EgyptDoor = {}

-- Animation settings
local TWEEN_DURATION = 4.0
local TWEEN_EASING_STYLE = Enum.EasingStyle.Sine
local TWEEN_EASING_DIRECTION = Enum.EasingDirection.InOut

-- Door state tracking
local doorPart = nil
local originalPosition = nil
local openPosition = nil
local currentTween = nil
local doorState = "closed" -- "closed", "opening", "open", "closing"

-- Initialize door references and calculate positions
local function initializeDoor()
	local doors = CollectionServiceTags.getLiveTagged(CollectionServiceTags.EGYPT_DOOR)

	if #doors == 0 then
		return false
	end


	doorPart = doors[1]
	originalPosition = doorPart.Position

	-- Calculate open position (door slides down by its height + buffer)
	local doorHeight = doorPart.Size.Y
	openPosition = originalPosition - Vector3.new(0, doorHeight + 2, 0)

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
local function createTweenInfo()
	return TweenInfo.new(
		TWEEN_DURATION,
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
function EgyptDoor.closeDoor()
	if not doorPart then
		return
	end

	if doorState == "closed" or doorState == "closing" then
		return -- Already closed or closing
	end

	doorState = "closing"

	-- Cancel any existing tween
	cancelCurrentTween()

	-- Create and play closing tween
	local tweenInfo = createTweenInfo()
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

local function init()
	if not initializeDoor() then
		return false
	end

	return true
end

-- Initialize on module load
init()

return EgyptDoor
