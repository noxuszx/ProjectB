-- src/server/ai/behaviors/FleeingBehavior.lua
-- Simple fleeing behavior - creature runs away for a set time
-- TODO: Add actual movement later

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIBehavior = require(script.Parent.aiBehavior)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.ai)

local FleeingBehavior = setmetatable({}, {__index = AIBehavior})
FleeingBehavior.__index = FleeingBehavior

function FleeingBehavior.new(threatSource)
	local self = setmetatable(AIBehavior.new("Fleeing"), FleeingBehavior)

	self.threatSource = threatSource
	self.fleeDuration = 0
	self.fleeStartTime = 0
	self.initialThreatDistance = 0
	self.minFleeDistance = 25 -- Minimum distance to flee before considering stopping
	self.lastPosition = nil

	return self
end

function FleeingBehavior:enter(creature)
	AIBehavior.enter(self, creature)

	local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]
	self.fleeDuration = creatureConfig and creatureConfig.FleeDuration or 10
	self.fleeStartTime = tick()
	self.lastPosition = creature.model.PrimaryPart.Position

	local threatPosition = self:getThreatPosition()
	if threatPosition then
		self.initialThreatDistance = (creature.model.PrimaryPart.Position - threatPosition).Magnitude
	end

	if AIConfig.Debug.LogBehaviorChanges then
		local threatName = "Unknown"
		if self.threatSource and self.threatSource.Name then
			threatName = self.threatSource.Name
		end
		print("[FleeingBehavior] " .. creature.creatureType .. " fleeing from " .. threatName ..
			  " for " .. self.fleeDuration .. " seconds (initial distance: " ..
			  string.format("%.1f", self.initialThreatDistance) .. ")")
	end
end

function FleeingBehavior:update(creature, deltaTime)
	AIBehavior.update(self, creature, deltaTime)

	local timeElapsed = tick() - self.fleeStartTime
	if timeElapsed >= self.fleeDuration then
		self:stopFleeing(creature, "time expired")
		return
	end

	local threatPosition = self:getThreatPosition()
	if threatPosition then
		local currentDistance = (creature.model.PrimaryPart.Position - threatPosition).Magnitude
		local safeDistance = math.max(self.minFleeDistance, self.initialThreatDistance * 1.5)

		if currentDistance >= safeDistance and timeElapsed > 2 then -- Must flee for at least 2 seconds
			self:stopFleeing(creature, "reached safe distance")
			return
		end
	end

	-- REMOVED: Stuck detection - Humanoid:MoveTo handles this

	-- Calculate flee direction away from threat
	local fleeDirection = self:calculateFleeDirection(creature)
	if fleeDirection then
		local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]
		local fleeSpeed = creatureConfig and creatureConfig.FleeSpeed or creature.moveSpeed * 1.5

		-- Use normal moveTowards instead of manual calculation
		-- This ensures consistent movement with obstacle avoidance
		local currentPosition = creature.model.PrimaryPart.Position
		local fleeTargetPosition = currentPosition + (fleeDirection * 10) -- Look ahead 10 studs

		self:moveTowards(creature, fleeTargetPosition, fleeSpeed, deltaTime)
		self.lastPosition = currentPosition

		-- Debug logging (reduced frequency)
		if AIConfig.Debug.LogBehaviorChanges and math.random() < 0.01 then
			local remainingTime = self.fleeDuration - timeElapsed
			local currentDistance = threatPosition and (currentPosition - threatPosition).Magnitude or 0
			print("[FleeingBehavior] " .. creature.creatureType .. " fleeing (" ..
				  string.format("%.1f", remainingTime) .. "s remaining, distance: " ..
				  string.format("%.1f", currentDistance) .. ")")
		end
	end
end

function FleeingBehavior:calculateFleeDirection(creature)
	if not creature or not creature.model or not creature.model.PrimaryPart then
		warn("[FleeingBehavior] Invalid creature in calculateFleeDirection")
		return nil
	end

	local currentPosition = creature.model.PrimaryPart.Position
	local threatPosition = self:getThreatPosition()

	if threatPosition then
		-- Simple: run directly away from threat
		local fleeDirection = (currentPosition - threatPosition)
		fleeDirection = Vector3.new(fleeDirection.X, 0, fleeDirection.Z) -- Keep on ground

		if fleeDirection.Magnitude > 0.1 then
			return fleeDirection.Unit
		end
	end

	-- Fallback: random direction
	local randomAngle = math.random() * math.pi * 2
	return Vector3.new(math.cos(randomAngle), 0, math.sin(randomAngle))
end

-- Helper function to get threat position from various threat source types
function FleeingBehavior:getThreatPosition()
	if not self.threatSource then
		return nil
	end

	-- Player threat source
	if self.threatSource.Character and self.threatSource.Character.PrimaryPart then
		return self.threatSource.Character.PrimaryPart.Position
	end

	-- Model/Part threat source
	if self.threatSource.PrimaryPart then
		return self.threatSource.PrimaryPart.Position
	end

	-- Direct Vector3 position
	if typeof(self.threatSource) == "Vector3" then
		return self.threatSource
	end

	return nil
end


function FleeingBehavior:stopFleeing(creature, reason)
	if AIConfig.Debug.LogBehaviorChanges then
		local reasonText = reason and (" - " .. reason) or ""
		print("[FleeingBehavior] " .. creature.creatureType .. " stopping flee" .. reasonText)
	end

	local RoamingBehavior = require(script.Parent.roaming)
	creature:setBehavior(RoamingBehavior.new())
end

return FleeingBehavior
