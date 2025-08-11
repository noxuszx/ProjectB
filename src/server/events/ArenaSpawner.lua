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
	for _, inst in ipairs(CollectionService:GetTagged(CS_tags.ARENA_SPAWN)) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
			markers[inst.Name] = inst
		end
	end
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
	print("[ArenaSpawner] DEBUG: spawnOneAtMarker called with:", creatureType, "at marker:", markerInstance.Name)
	local pos = markerInstance.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
	print("[ArenaSpawner] DEBUG: Spawn position:", tostring(pos))
	
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
	print("[ArenaSpawner] DEBUG: Mapped", creatureType, "to", arenaCreatureType)
	
	-- Spawn using the new Arena system
	print("[ArenaSpawner] DEBUG: Calling ArenaCreatureSpawner.spawnCreature...")
	local creature = ArenaCreatureSpawner.spawnCreature(arenaCreatureType, pos)
	if creature and creature.model then
		print("[ArenaSpawner] DEBUG: Creature spawned successfully, tagging as arena enemy")
		tagArenaEnemy(creature.model)
		return true
	else
		print("[ArenaSpawner] DEBUG: Failed to spawn creature")
	end
	return false
end

local function spawnPhase(phaseName, phaseWaves, markerOrder)
	print("[ArenaSpawner] DEBUG: spawnPhase called for:", phaseName)
	print("[ArenaSpawner] DEBUG: markerOrder:", table.concat(markerOrder, ", "))
	
	local markers = getTaggedSpawnMarkers()
	print("[ArenaSpawner] DEBUG: Found markers:")
	for name, marker in pairs(markers) do
		print("  -", name, "at", tostring(marker.Position))
	end
	
	local stagger = (ArenaConfig.SpawnStaggerSeconds and ArenaConfig.SpawnStaggerSeconds[phaseName]) or 0.2
	print("[ArenaSpawner] DEBUG: Stagger time:", stagger)
	
	local plan = buildSpawnPlanRoundRobin(phaseWaves, markerOrder)
	print("[ArenaSpawner] DEBUG: Spawn plan has", #plan, "entries")

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
	print("[ArenaSpawner] DEBUG: spawnSkeletonMummyWave called")
	
	local aiManager = ArenaAIManager.getInstance()
	print("[ArenaSpawner] DEBUG: ArenaAIManager isActive:", aiManager.isActive)
	if not aiManager.isActive then
		print("[ArenaSpawner] DEBUG: Starting ArenaAIManager...")
		local success = aiManager:start()
		print("[ArenaSpawner] DEBUG: ArenaAIManager start result:", success)
	end
	
	local w = ArenaConfig.Waves.Phase1
	print("[ArenaSpawner] DEBUG: Phase1 wave config:")
	for spawnerName, spawns in pairs(w) do
		print("  ", spawnerName, ":", #spawns, "spawn groups")
		for i, spawn in ipairs(spawns) do
			print("    ", spawn.Type, "x", spawn.Count)
		end
	end
	
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
