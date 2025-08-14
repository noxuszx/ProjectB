-- src/server/events/PedestalController.server.lua
-- Main controller for pedestal ball detection system
-- Uses ZonePlus to detect TOWER_BALL objects on PEDESTAL parts

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local ZonePlus = require(ReplicatedStorage.Shared.modules.Zone)
local EgyptDoor = require(script.Parent.EgyptDoor)

-- System state
local pedestals = {}
local pedestalZones = {}
local pedestalStates = {}
local ballCounts = {}

-- Initialize pedestal detection system
local function setupPedestals()
	-- Use utility to get only workspace pedestals
	local pedestalParts = CollectionServiceTags.getLiveTagged(CollectionServiceTags.PEDESTAL)
	
	if #pedestalParts == 0 then
		return false
	end

	for i, pedestal in ipairs(pedestalParts) do
		if not pedestal:IsA("BasePart") then
			continue
		end

		-- Remove protection that blocks ZonePlus detection
		if CollectionService:HasTag(pedestal, "CMS:ProtectedCore") then
			CollectionService:RemoveTag(pedestal, "CMS:ProtectedCore")
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
	end
	
	return true
end

function onBallEntered(zone, part, pedestalIndex)
	if not CollectionService:HasTag(part, CollectionServiceTags.TOWER_BALL) then
		return
	end

	ballCounts[pedestalIndex] = ballCounts[pedestalIndex] + 1
	pedestalStates[pedestalIndex] = ballCounts[pedestalIndex] > 0
	
	evaluateDoorState()
end

function onBallExited(zone, part, pedestalIndex)
	if not CollectionService:HasTag(part, CollectionServiceTags.TOWER_BALL) then
		return
	end

	ballCounts[pedestalIndex] = math.max(0, ballCounts[pedestalIndex] - 1)
	pedestalStates[pedestalIndex] = ballCounts[pedestalIndex] > 0
	
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

	if allOccupied and #pedestals > 0 then
		EgyptDoor.openDoor()
	else
		EgyptDoor.closeDoor()
	end
end

-- Initialize the system
local function init()
	print("[PedestalController] Initializing pedestal detection system...")
	
	-- Wait for ZonePlus to be available
	if not ZonePlus then
		warn("[PedestalController] ZonePlus not available!")
		return false
	end

	-- Initialize the Egypt door system first
	if not EgyptDoor.init() then
		warn("[PedestalController] Failed to initialize Egypt door!")
		return false
	end

	-- Setup pedestal zones
	if not setupPedestals() then
		warn("[PedestalController] Failed to setup pedestals!")
		return false
	end

	-- Initial door state evaluation
	evaluateDoorState()
	
	print("[PedestalController] Pedestal system initialized successfully!")
	return true
end

-- Wait for initialization signal from ChunkInit
local function waitForInitSignal()
	-- Check if event already exists
	local existingEvent = ReplicatedStorage:FindFirstChild("InitPedestal")
	if existingEvent then
		init()
		return
	end
	
	-- Otherwise wait for it
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "InitPedestal" and child:IsA("BindableEvent") then
			init()
		end
	end)
end

-- Add small delay to ensure ChunkInit runs first, then check for signal
task.wait(1)
waitForInitSignal()

-- Handle cleanup when server shuts down
game:BindToClose(function()
	for i, zone in ipairs(pedestalZones) do
		if zone and zone.destroy then
			zone:destroy()
		end
	end
end)
