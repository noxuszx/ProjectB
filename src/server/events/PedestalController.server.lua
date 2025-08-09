-- src/server/events/PedestalController.server.lua
-- Main controller for pedestal ball detection system
-- Uses ZonePlus to detect TOWER_BALL objects on PEDESTAL parts

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local ZonePlus = require(ReplicatedStorage.Packages.zoneplus)
local EgyptDoor = require(script.Parent.EgyptDoor)

-- System state
local pedestals = {}
local pedestalZones = {}
local pedestalStates = {}
local ballCounts = {}

-- Initialize pedestal detection system
local function setupPedestals()
	local pedestalParts = CollectionService:GetTagged(CollectionServiceTags.PEDESTAL)

	if #pedestalParts == 0 then
		warn("[PedestalController] No pedestals found with PEDESTAL tag")
		return false
	end

	print("[PedestalController] Found", #pedestalParts, "pedestals")

	for i, pedestal in ipairs(pedestalParts) do
		if not pedestal:IsA("BasePart") then
			warn("[PedestalController] Pedestal", i, "is not a BasePart, skipping")
			continue
		end

		-- Store pedestal reference
		pedestals[i] = pedestal
		pedestalStates[i] = false
		ballCounts[i] = 0

		local zone = ZonePlus.new(pedestal)
		pedestalZones[i] = zone

		zone.partEntered:Connect(function(part)
			onBallEntered(zone, part, i)
		end)

		zone.partExited:Connect(function(part)
			onBallExited(zone, part, i)
		end)

		print("[PedestalController] Created ZonePlus zone for pedestal", i, "using pedestal part directly")
	end

	print("[PedestalController] Successfully set up", #pedestals, "pedestal zones")
	return true
end

function onBallEntered(zone, part, pedestalIndex)
	if not CollectionService:HasTag(part, CollectionServiceTags.TOWER_BALL) then
		return
	end

	ballCounts[pedestalIndex] = ballCounts[pedestalIndex] + 1

	local wasOccupied = pedestalStates[pedestalIndex]
	pedestalStates[pedestalIndex] = ballCounts[pedestalIndex] > 0

	print(
		"[PedestalController] Ball entered pedestal",
		pedestalIndex,
		"- Balls:",
		ballCounts[pedestalIndex],
		"- State changed:",
		wasOccupied,
		"→",
		pedestalStates[pedestalIndex]
	)

	evaluateDoorState()
end

function onBallExited(zone, part, pedestalIndex)
	if not CollectionService:HasTag(part, CollectionServiceTags.TOWER_BALL) then
		return
	end

	ballCounts[pedestalIndex] = math.max(0, ballCounts[pedestalIndex] - 1)

	local wasOccupied = pedestalStates[pedestalIndex]
	pedestalStates[pedestalIndex] = ballCounts[pedestalIndex] > 0

	print(
		"[PedestalController] Ball exited pedestal",
		pedestalIndex,
		"- Balls:",
		ballCounts[pedestalIndex],
		"- State changed:",
		wasOccupied,
		"→",
		pedestalStates[pedestalIndex]
	)

	evaluateDoorState()
end

function evaluateDoorState()
	local allOccupied = true
	local occupiedCount = 0

	for i = 1, #pedestals do
		if pedestalStates[i] then
			occupiedCount = occupiedCount + 1
		else
			allOccupied = false
		end
	end

	print("[PedestalController] Pedestal status:", occupiedCount, "of", #pedestals, "occupied")

	if allOccupied and #pedestals > 0 then
		print("[PedestalController] All pedestals occupied - Opening door")
		EgyptDoor.openDoor()
	else
		print("[PedestalController] Not all pedestals occupied - Closing door")
		EgyptDoor.closeDoor()
	end
end

local function getSystemStatus()
	local status = {
		pedestalCount = #pedestals,
		pedestalStates = {},
		ballCounts = {},
		doorState = EgyptDoor.getDoorState(),
	}

	for i = 1, #pedestals do
		status.pedestalStates[i] = pedestalStates[i]
		status.ballCounts[i] = ballCounts[i]
	end

	return status
end

-- Initialize the system
local function init()
	print("[PedestalController] Initializing pedestal ball detection system...")

	-- Wait for ZonePlus to be available
	if not ZonePlus then
		warn("[PedestalController] ZonePlus not found - cannot initialize")
		return false
	end

	-- Setup pedestal zones
	if not setupPedestals() then
		warn("[PedestalController] Failed to setup pedestals")
		return false
	end

	-- Initial door state evaluation
	evaluateDoorState()

	print("[PedestalController] System initialized successfully")
	return true
end

-- Handle cleanup when server shuts down
game:BindToClose(function()
	print("[PedestalController] Cleaning up zones...")
	for i, zone in ipairs(pedestalZones) do
		if zone and zone.destroy then
			zone:destroy()
		end
	end
end)

-- Public API for debugging
local PedestalController = {
	getSystemStatus = getSystemStatus,
	evaluateDoorState = evaluateDoorState,
}

if not init() then
	warn("[PedestalController] Failed to initialize pedestal controller")
end

return PedestalController
