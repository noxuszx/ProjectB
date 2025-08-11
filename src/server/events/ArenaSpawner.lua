-- src/server/events/ArenaSpawner.server.lua
-- Spawns arena waves at predefined Workspace.ArenaSpawns markers

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace 		= game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ArenaConfig 	  = require(ReplicatedStorage.Shared.config.ArenaConfig)
local CS_tags 	 	  = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local CreatureSpawner = require(script.Parent.Parent.ai.CreatureSpawner)

local ArenaSpawner = {}

----------------------------------------------------------------------------------------

local function getTaggedSpawnMarkers()
	local markers = {}
	for _, inst in ipairs(CollectionService:GetTagged(CS_tags.ARENA_SPAWN)) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
			markers[inst.Name] = inst
		end
	end
	return markers
end

local function enhanceEnemyAggro(aiController)
	if not aiController then
		return
	end
	local model = aiController.model or aiController.Model or nil
	if model then
		CollectionService:AddTag(model, CS_tags.ARENA_ENEMY)
	end
	if aiController.DetectionRange ~= nil then
		aiController.DetectionRange = ArenaConfig.Aggro.DetectionRange
	end
	if aiController.ChaseRange ~= nil then
		aiController.ChaseRange = ArenaConfig.Aggro.ChaseRange
	end
	aiController.detectionRange = ArenaConfig.Aggro.DetectionRange
	if tostring(aiController.creatureType) ~= "Scorpion" then
		aiController.usePathfinding = true
	else
		aiController.usePathfinding = false
	end
end


-- Flatten per-marker entries into counts
local function expandEntriesForMarker(markerName, entries)
	local list = {}
	for _, e in ipairs(entries) do
		local count = math.max(1, e.Count or 1)
		for i = 1, count do
			table.insert(list, { marker = markerName, creatureType = e.Type })
		end
	end
	return list
end

local function buildSpawnPlanRoundRobin(phaseWaves, markerOrder)
	-- phaseWaves is ArenaConfig.Waves.PhaseX
	-- markerOrder is an array of marker names to consider
	local buckets = {}
	local total = 0
	for _, markerName in ipairs(markerOrder) do
		local entries = phaseWaves[markerName]
		if entries then
			local expanded = expandEntriesForMarker(markerName, entries)
			if #expanded > 0 then
				table.insert(buckets, expanded)
				total += #expanded
			end
		end
	end
	-- round-robin pick
	local plan = {}
	local idx = 1
	while total > 0 do
		local b = buckets[idx]
		if b and #b > 0 then
			table.insert(plan, table.remove(b, 1))
			total -= 1
		end
		idx += 1
		if idx > #buckets then
			idx = 1
		end
	end
	return plan
end

local function spawnOneAtMarker(markerInstance, creatureType)
	local pos = markerInstance.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
	local ok, ai = pcall(function()
		return CreatureSpawner.spawnCreature(creatureType, pos, { activationMode = "Zone" })
	end)
	if ok and ai then
		enhanceEnemyAggro(ai)
		local AIManager = require(script.Parent.Parent.ai.AIManager)
		local manager = AIManager.getInstance()
		if manager and manager.registerCreature then
			manager:registerCreature(ai)
		end
		return true
	end
	return false
end

local function spawnPhase(phaseName, phaseWaves, markerOrder)
	local markers = getTaggedSpawnMarkers()
	local stagger = (ArenaConfig.SpawnStaggerSeconds and ArenaConfig.SpawnStaggerSeconds[phaseName]) or 0.2
	local plan = buildSpawnPlanRoundRobin(phaseWaves, markerOrder)

	local spawned = 0
	for _, item in ipairs(plan) do
		local marker = markers[item.marker]
		if marker and marker:IsA("BasePart") then
			if spawnOneAtMarker(marker, item.creatureType) then
				spawned += 1
				task.wait(stagger)
			end
		end
	end
	return spawned
end

function ArenaSpawner.spawnSkeletonMummyWave()
	local w = ArenaConfig.Waves.Phase1
	return spawnPhase("Phase1", w, { "WideSpawner1", "WideSpawner2" })
end

function ArenaSpawner.spawnSkeleton2Wave()
	local w = ArenaConfig.Waves.Phase2
	return spawnPhase("Phase2", w, { "WideSpawner1", "WideSpawner2" })
end

function ArenaSpawner.spawnScorpionElites()
	local w = ArenaConfig.Waves.Phase3
	local order = {}
	for i = 1, 5 do
		table.insert(order, "ScorpionSpawner" .. i)
	end
	return spawnPhase("Phase3", w, order)
end

return ArenaSpawner
