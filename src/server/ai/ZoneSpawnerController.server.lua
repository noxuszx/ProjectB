-- ZoneSpawnerController.server.lua
-- Tower spawning system controller using ZonePlus for proximity detection
-- Integrates with existing AIManager through event-based spawn source registration

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ZonePlus = require(ReplicatedStorage.Shared.modules.Zone)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local AIManager = require(script.Parent.AIManager)

local ZoneSpawnerController = {}

-- Tower state tracking
local towers = {}
local activeSpawners = {}
local debounceTimers = {}

-- Performance tracking
local updateConnection = nil
local lastCleanupTime  = 0
local cleanupInterval  = 30



function ZoneSpawnerController.init()
	print("[ZoneSpawnerController] Initializing tower spawning system...")

	ZoneSpawnerController.discoverTowers()

	CollectionService:GetInstanceAddedSignal(CollectionServiceTags.TOWER):Connect(function(towerModel)
		if towerModel:IsDescendantOf(workspace) then
			print("[ZoneSpawnerController] New tower detected:", towerModel.Name)
			ZoneSpawnerController.setupTower(towerModel)
		end
	end)

	CollectionService:GetInstanceRemovedSignal(CollectionServiceTags.TOWER):Connect(function(towerModel)
		local towerId = tostring(towerModel)
		if towers[towerId] then
			print("[ZoneSpawnerController] Tower removed:", towerModel.Name)
			ZoneSpawnerController.cleanupTower(towerId)
		end
	end)

	local aiManager = AIManager.getInstance()
	if aiManager.RegisterSpawnSource then
		aiManager:RegisterSpawnSource("TowerSpawning", ZoneSpawnerController.handleSpawnRequest)
		print("[ZoneSpawnerController] Registered with AIManager as spawn source")
	else
		warn("[ZoneSpawnerController] AIManager does not support RegisterSpawnSource - using fallback")
	end

	updateConnection = RunService.Heartbeat:Connect(function()
		ZoneSpawnerController.periodicUpdate()
	end)

	print("[ZoneSpawnerController] Tower spawning system initialized")
end

function ZoneSpawnerController.discoverTowers()
	local towerModels = CollectionService:GetTagged(CollectionServiceTags.TOWER)
	print("[ZoneSpawnerController] Found", #towerModels, "towers")

	for _, towerModel in ipairs(towerModels) do
		if towerModel:IsDescendantOf(workspace) then
			ZoneSpawnerController.setupTower(towerModel)
		end
	end
end

function ZoneSpawnerController.setupTower(towerModel)
	local towerId = tostring(towerModel)
	print("[ZoneSpawnerController] Setting up tower:", towerModel.Name)

	towers[towerId] = {
		model = towerModel,
		floors = {},
		zones = {},
		activeCreatures = {},
		totalCreatures = 0,
	}

	local floors = {}
	for _, child in ipairs(towerModel:GetDescendants()) do
		local floorIndex = child:GetAttribute("FloorIndex")
		if floorIndex and type(floorIndex) == "number" then
			floors[floorIndex] = child
		end
	end

	for floorIndex, floorModel in pairs(floors) do
		ZoneSpawnerController.setupFloor(towerId, floorIndex, floorModel)
	end

	ZoneSpawnerController.activateFloor(towerId, 1)
end

function ZoneSpawnerController.setupFloor(towerId, floorIndex, floorModel)
	print("[ZoneSpawnerController] Setting up floor", floorIndex, "in tower", towers[towerId].model.Name)

	local triggerPart = floorModel:FindFirstChild("Trigger")
	if not triggerPart or not triggerPart:IsA("BasePart") then
		warn("[ZoneSpawnerController] Floor", floorIndex, "missing Trigger part")
		return
	end

	local spawner = nil
	for _, child in ipairs(floorModel:GetChildren()) do
		if CollectionService:HasTag(child, CollectionServiceTags.MOB_SPAWNER) then
			spawner = child
			break
		end
	end

	if not spawner then
		warn("[ZoneSpawnerController] Floor", floorIndex, "missing MobSpawner")
		return
	end

	local spawnInterval = spawner:GetAttribute("SpawnInterval") or 3.0
	local maxActive = spawner:GetAttribute("MaxActive") or 3

	-- Store floor data
	local floorData = {
		floorIndex = floorIndex,
		floorModel = floorModel,
		triggerPart = triggerPart,
		spawner = spawner,
		spawnInterval = spawnInterval,
		maxActive = maxActive,
		active = false,
		lastSpawnTime = 0,
		creatures = {},
		zone = nil,
	}

	towers[towerId].floors[floorIndex] = floorData
	ZoneSpawnerController.createZone(towerId, floorData)
end

function ZoneSpawnerController.createZone(towerId, floorData)
	local triggerPart = floorData.triggerPart

	local function recreateZone()
		if floorData.zone then
			floorData.zone:destroy()
		end

		local zone = ZonePlus.new(triggerPart)
		floorData.zone = zone
		towers[towerId].zones[floorData.floorIndex] = zone

		zone.playerEntered:Connect(function(player)
			ZoneSpawnerController.handlePlayerEnteredZone(towerId, floorData.floorIndex, player)
		end)

		zone.playerExited:Connect(function(player)
			ZoneSpawnerController.handlePlayerExitedZone(towerId, floorData.floorIndex, player)
		end)

		print("[ZoneSpawnerController] Created zone for floor", floorData.floorIndex)
	end

	recreateZone()

	triggerPart.AncestryChanged:Connect(function()
		if triggerPart.Parent then
			recreateZone()
		end
	end)
end

function ZoneSpawnerController.handlePlayerEnteredZone(towerId, floorIndex, player)
	local debounceKey = towerId .. "_" .. floorIndex .. "_" .. player.Name / l
	if debounceTimers[debounceKey] then
		return
	end

	debounceTimers[debounceKey] = true
	task.wait(AIConfig.TowerSpawning.Settings.ZoneDebounceTime)
	debounceTimers[debounceKey] = nil

	print("[ZoneSpawnerController] Player", player.Name, "entered floor", floorIndex, "zone")

	local nextFloor = floorIndex + 1
	if towers[towerId].floors[nextFloor] then
		ZoneSpawnerController.activateFloor(towerId, nextFloor)
	end
end

function ZoneSpawnerController.handlePlayerExitedZone(towerId, floorIndex, player)
	-- Could implement deactivation logic here if needed
	-- For now, floors remain active once unlocked
end

function ZoneSpawnerController.activateFloor(towerId, floorIndex)
	local tower = towers[towerId]
	local floorData = tower.floors[floorIndex]

	if not floorData then
		warn("[ZoneSpawnerController] Floor", floorIndex, "not found in tower")
		return
	end

	if floorData.active then
		return
	end

	print("[ZoneSpawnerController] Activating floor", floorIndex, "in tower", tower.model.Name)
	floorData.active = true
	floorData.lastSpawnTime = os.clock()

	-- Start spawning coroutine
	task.spawn(function()
		ZoneSpawnerController.floorSpawningLoop(towerId, floorIndex)
	end)
end

function ZoneSpawnerController.floorSpawningLoop(towerId, floorIndex)
	local tower = towers[towerId]
	local floorData = tower.floors[floorIndex]

	while floorData.active and tower.model.Parent do
		local aiManager = AIManager.getInstance()
		if aiManager:getCreatureCount() >= AIConfig.Settings.MaxCreatures then
			task.wait(10)
			continue
		end

		if
			#floorData.creatures < floorData.maxActive
			and tower.totalCreatures < AIConfig.TowerSpawning.Settings.MaxTowerCreatures
		then
			local currentTime = os.clock()
			if currentTime - floorData.lastSpawnTime >= floorData.spawnInterval then
				ZoneSpawnerController.spawnCreatureOnFloor(towerId, floorIndex)
				floorData.lastSpawnTime = currentTime
			end
		end

		task.wait(1)
	end
end

function ZoneSpawnerController.spawnCreatureOnFloor(towerId, floorIndex)
	local tower = towers[towerId]
	local floorData = tower.floors[floorIndex]

	local creatureType
	local towerName = tower.model.Name
	local towerConfig = AIConfig.TowerSpawning.Towers[towerName]

	if towerConfig and towerConfig.CreatureTypes then
		creatureType = towerConfig.CreatureTypes[math.random(#towerConfig.CreatureTypes)]
	else
		local defaultTypes = { "TowerSkeleton", "TowerMummy" }
		creatureType = defaultTypes[math.random(#defaultTypes)]
	end

	local spawnPosition = floorData.spawner:IsA("BasePart") and floorData.spawner.Position
		or floorData.spawner:FindFirstChild("Position") and floorData.spawner.Position.Value
		or floorData.floorModel:GetBoundingBox()

	local offset = Vector3.new(math.random(-5, 5), 2, math.random(-5, 5))
	spawnPosition = spawnPosition + offset

	ZoneSpawnerController.handleSpawnRequest(creatureType, spawnPosition, {
		towerId = towerId,
		floorIndex = floorIndex,
		source = "TowerSpawning",
	})
end

function ZoneSpawnerController.handleSpawnRequest(creatureType, position, context)
	-- This is called by AIManager when we're registered as a spawn source
	-- Or we call it directly for tower spawning

	print("[ZoneSpawnerController] Spawn request:", creatureType, "at", position)

	-- For now, integrate directly with CreatureSpawner
	local CreatureSpawner = require(script.Parent.CreatureSpawner)
	local aiController = CreatureSpawner.spawnCreature(creatureType, position, {
		activationMode = "Zone",
	})

	if aiController and context then
		-- Track the creature for this tower/floor
		if context.towerId and context.floorIndex then
			local tower = towers[context.towerId]
			local floorData = tower.floors[context.floorIndex]

			table.insert(floorData.creatures, aiController)
			table.insert(tower.activeCreatures, aiController)
			tower.totalCreatures = tower.totalCreatures + 1

			aiController.isIndoorCreature = true
		end

		local aiManager = AIManager.getInstance()
		aiManager:registerCreature(aiController)
	end

	return aiController
end

function ZoneSpawnerController.periodicUpdate()
	local currentTime = os.clock()

	if currentTime - lastCleanupTime >= cleanupInterval then
		ZoneSpawnerController.cleanupDeadCreatures()
		ZoneSpawnerController.checkForceDeactivation()
		lastCleanupTime = currentTime
	end
end

function ZoneSpawnerController.checkForceDeactivation()
	-- Safety mechanism: Force deactivation if zones empty too long
	local forceDeactivationTime = AIConfig.TowerSpawning.Settings.ForceDeactivationTime
	local currentTime = os.clock()

	for towerId, tower in pairs(towers) do
		for floorIndex, floorData in pairs(tower.floors) do
			if floorData.active and #floorData.creatures == 0 then
				-- Check if zone has been empty for too long
				if not floorData.emptyStartTime then
					floorData.emptyStartTime = currentTime
				elseif currentTime - floorData.emptyStartTime >= forceDeactivationTime then
					print("[ZoneSpawnerController] Force deactivating floor", floorIndex, "- empty too long")
					floorData.active = false
					floorData.emptyStartTime = nil
				end
			else
				-- Reset empty timer if floor has creatures
				floorData.emptyStartTime = nil
			end
		end
	end
end


function ZoneSpawnerController.cleanupTower(towerId)
	
	local tower = towers[towerId]
	if not tower then
		return
	end

	print("[ZoneSpawnerController] Cleaning up tower:", tower.model.Name)

	for floorIndex, zone in pairs(tower.zones) do
		if zone and zone.destroy then
			zone:destroy()
		end
	end

	for floorIndex, floorData in pairs(tower.floors) do
		floorData.active = false
	end
	towers[towerId] = nil
end

function ZoneSpawnerController.cleanupDeadCreatures()
	for towerId, tower in pairs(towers) do
		-- Clean up tower-level creature list
		for i = #tower.activeCreatures, 1, -1 do
			local creature = tower.activeCreatures[i]
			if not creature.isActive or not creature.model.Parent then
				table.remove(tower.activeCreatures, i)
				tower.totalCreatures = math.max(0, tower.totalCreatures - 1)
			end
		end

		-- Clean up floor-level creature lists
		for floorIndex, floorData in pairs(tower.floors) do
			for i = #floorData.creatures, 1, -1 do
				local creature = floorData.creatures[i]
				if not creature.isActive or not creature.model.Parent then
					table.remove(floorData.creatures, i)
				end
			end
		end
	end
end

function ZoneSpawnerController.shutdown()
	print("[ZoneSpawnerController] Shutting down...")

	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	-- Cleanup all zones
	for towerId, tower in pairs(towers) do
		for floorIndex, zone in pairs(tower.zones) do
			if zone and zone.destroy then
				zone:destroy()
			end
		end
	end

	towers = {}
	activeSpawners = {}
	debounceTimers = {}
end

-- Initialize on script run
ZoneSpawnerController.init()

return ZoneSpawnerController
