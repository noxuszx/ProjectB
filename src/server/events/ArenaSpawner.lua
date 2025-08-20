-- src/server/events/ArenaSpawner.server.lua
-- Spawns arena waves at predefined Workspace.ArenaSpawns markers
-- Now uses dedicated Arena AI system for better performance and behavior

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ArenaConfig = require(ReplicatedStorage.Shared.config.ArenaConfig)
local CS_tags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

-- Use the new Arena AI system
local ArenaAIManager = require(script.Parent.Parent.ai.arena.ArenaAIManager)
local ArenaCreatureSpawner = require(script.Parent.Parent.ai.arena.ArenaCreatureSpawner)

local ArenaSpawner = {}

----------------------------------------------------------------------------------------

local function getTaggedSpawnMarkers()
	local markers = {}
	local tagged = CollectionService:GetTagged(CS_tags.ARENA_SPAWN)
	if #tagged == 0 then
		warn("[ArenaSpawner] No ARENA_SPAWN-tagged markers found. Ensure markers are tagged and in Workspace.")
	end
	for _, inst in ipairs(tagged) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
			markers[inst.Name] = inst
		else
			warn("[ArenaSpawner] Ignoring non-BasePart or non-live marker:", inst:GetFullName())
		end
	end
	local names = {}
	for k in pairs(markers) do table.insert(names, k) end
	print("[ArenaSpawner] Found markers:", table.concat(names, ", "))
	return markers
end

-- Enhanced aggro is now handled by the Arena AI system
local function tagArenaEnemy(model)
	if model then
		CollectionService:AddTag(model, CS_tags.ARENA_ENEMY)
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
	
	-- Map old creature types to new Arena variants
	local arenaCreatureType = creatureType
	if creatureType == "EgyptianSkeleton" then
		arenaCreatureType = "ArenaEgyptianSkeleton"
	elseif creatureType == "EgyptianSkeleton2" then
		arenaCreatureType = "ArenaEgyptianSkeleton2"
	elseif creatureType == "Scorpion" then
		arenaCreatureType = "ArenaScorpion"
	elseif creatureType == "Mummy" then
		-- If Mummy is used, default to ArenaEgyptianSkeleton
		arenaCreatureType = "ArenaEgyptianSkeleton"
	end
	
	-- Spawn using the new Arena system
	print(string.format("[ArenaSpawner] Spawning '%s' at %s (marker=%s)", tostring(arenaCreatureType), tostring(pos), tostring(markerInstance.Name)))
	local creature = ArenaCreatureSpawner.spawnCreature(arenaCreatureType, pos)
	if creature and creature.model then
		tagArenaEnemy(creature.model)
		return true
	else
		warn("[ArenaSpawner] Failed to spawn creature of type ", tostring(arenaCreatureType), " at marker ", tostring(markerInstance.Name))
	end
	return false
end

local function spawnPhase(phaseName, phaseWaves, markerOrder)
	
	local markers = getTaggedSpawnMarkers()
	
	local stagger = (ArenaConfig.SpawnStaggerSeconds and ArenaConfig.SpawnStaggerSeconds[phaseName]) or 0.2
	
	local plan = buildSpawnPlanRoundRobin(phaseWaves, markerOrder)
	print(string.format("[ArenaSpawner] Phase '%s': plan size=%d, stagger=%.2fs", tostring(phaseName), #plan, stagger))

	local spawned = 0
	for idx, item in ipairs(plan) do
		print(string.format("[ArenaSpawner] (%s) #%d -> marker=%s type=%s", tostring(phaseName), idx, tostring(item.marker), tostring(item.creatureType)))
		local marker = markers[item.marker]
		if marker and marker:IsA("BasePart") then
			if spawnOneAtMarker(marker, item.creatureType) then
				spawned += 1
			else
				warn(string.format("[ArenaSpawner] (%s) Spawn failed at marker=%s type=%s", tostring(phaseName), tostring(item.marker), tostring(item.creatureType)))
			end
			if stagger and stagger > 0 then
				task.wait(stagger)
			end
		end
	end
	print(string.format("[ArenaSpawner] Phase '%s' spawned count=%d", tostring(phaseName), spawned))
	return spawned
end

function ArenaSpawner.spawnSkeletonMummyWave()
	
	local aiManager = ArenaAIManager.getInstance()
	if not aiManager.isActive then
		local success = aiManager:start()
	end
	
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

-- Clean up function for when arena ends
function ArenaSpawner.cleanup()
	local aiManager = ArenaAIManager.getInstance()
	if aiManager.isActive then
		aiManager:stop()
	end
	ArenaCreatureSpawner.cleanupAllCreatures()
end

return ArenaSpawner
