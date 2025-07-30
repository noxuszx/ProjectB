-- src/server/ai/behaviors/RoamingBehavior.lua
-- Roaming behavior - creatures wander around randomly with idle periods
-- Includes random waypoint selection, idle states, and smooth movement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIBehavior = require(script.Parent.AIBehavior)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)

local RoamingBehavior = setmetatable({}, {__index = AIBehavior})
RoamingBehavior.__index = RoamingBehavior

-- Roaming states
local RoamingState = {
	IDLE = "Idle",
	MOVING = "Moving",
	CHOOSING_DESTINATION = "ChoosingDestination"
}

function RoamingBehavior.new()
	local self = setmetatable(AIBehavior.new("Roaming"), RoamingBehavior)

	self.state = RoamingState.IDLE
	self.targetPosition = nil
	self.idleStartTime = 0
	self.idleDuration = 0
	-- Removed unused variables: lastPosition, stuckCheckTime, lastStuckTime, stuckAttempts

	return self
end

function RoamingBehavior:enter(creature)
	AIBehavior.enter(self, creature)

	self.state = RoamingState.IDLE
	self:startIdling(creature)

	if AIConfig.Debug.LogBehaviorChanges then
		print("[RoamingBehavior] " .. creature.creatureType .. " starting to roam")
	end
end

function RoamingBehavior:update(creature, deltaTime)
	AIBehavior.update(self, creature, deltaTime)

	-- Check for threats/players first
	local nearestPlayer, distance = self:findNearestPlayer(creature)
	if nearestPlayer then
		local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]

		if creatureConfig and creatureConfig.Type == "Passive" then
			-- Check if this creature should flee on proximity (default: true)
			local fleeOnProximity = creatureConfig.FleeOnProximity
			if fleeOnProximity == nil then
				fleeOnProximity = true -- Default behavior
			end
			
			if fleeOnProximity then
				-- Passive creatures only flee if player gets very close (within personal space)
				local personalSpaceDistance = creatureConfig.DetectionRange * 0.4 -- 40% of detection range
				if distance <= personalSpaceDistance then
					local FleeingBehavior = require(script.Parent.Fleeing)
					creature:setBehavior(FleeingBehavior.new(nearestPlayer))
					return
				end
			end
			-- If FleeOnProximity is false, creature won't flee from player proximity

		elseif creatureConfig and creatureConfig.Type == "Hostile" then
			local ChasingBehavior = require(script.Parent.Chasing)
			creature:setBehavior(ChasingBehavior.new(nearestPlayer))
			return
		end
	end

	if self.state == RoamingState.IDLE then
		self:updateIdling()
	elseif self.state == RoamingState.CHOOSING_DESTINATION then
		self:updateChoosingDestination(creature)
	elseif self.state == RoamingState.MOVING then
		self:updateMoving(creature, deltaTime)
	end
end

function RoamingBehavior:startIdling(creature)
	self.state = RoamingState.IDLE
	self.idleStartTime = os.clock()

	local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]
	local idleTimeRange = creatureConfig and creatureConfig.IdleTime or {5, 15}
	self.idleDuration = self:getRandomTime(idleTimeRange)


	if AIConfig.Debug.LogBehaviorChanges then
		print("[RoamingBehavior] " .. creature.creatureType .. " idling for " .. string.format("%.1f", self.idleDuration) .. " seconds")
	end
end

function RoamingBehavior:updateIdling()
	local timeIdling = os.clock() - self.idleStartTime

	if timeIdling >= self.idleDuration then
		self.state = RoamingState.CHOOSING_DESTINATION
	end
end

function RoamingBehavior:updateChoosingDestination(creature)
	local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]
	local roamRadius = creatureConfig and creatureConfig.RoamRadius or 20

	-- Use spawn position as center for roaming area
	local centerPosition = creature.spawnPosition

	-- Simple random target selection (no multiple attempts)
	local randomAngle = math.random() * math.pi * 2
	local randomDistance = math.random() * roamRadius
	local targetX = centerPosition.X + math.cos(randomAngle) * randomDistance
	local targetZ = centerPosition.Z + math.sin(randomAngle) * randomDistance
	self.targetPosition = Vector3.new(targetX, centerPosition.Y, targetZ)

	self.state = RoamingState.MOVING


	if AIConfig.Debug.LogBehaviorChanges then
		local distance = (self.targetPosition - creature.model.PrimaryPart.Position).Magnitude
		print("[RoamingBehavior] " .. creature.creatureType .. " moving to new destination " .. string.format("%.1f", distance) .. " studs away")
	end
end

function RoamingBehavior:updateMoving(creature, deltaTime)
	if not self.targetPosition then
		self.state = RoamingState.CHOOSING_DESTINATION
		return
	end

	local currentPosition = creature.model.PrimaryPart.Position
	local distanceToTarget = (self.targetPosition - currentPosition).Magnitude

	-- Check if we've reached the destination
	if distanceToTarget < 3 then
		self:startIdling(creature)
		return
	end

	-- REMOVED: Complex stuck detection - Humanoid:MoveTo handles this automatically

	-- Move towards target
	self:moveTowards(creature, self.targetPosition, creature.moveSpeed, deltaTime)
end

return RoamingBehavior
