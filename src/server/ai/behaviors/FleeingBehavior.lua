-- src/server/ai/behaviors/FleeingBehavior.lua
-- Simple fleeing behavior - creature runs away for a set time
-- TODO: Add actual movement later

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIBehavior = require(script.Parent.AIBehavior)
local AIConfig = require(ReplicatedStorage.Shared.config.AIConfig)

local FleeingBehavior = setmetatable({}, {__index = AIBehavior})
FleeingBehavior.__index = FleeingBehavior

function FleeingBehavior.new(threatSource)
	local self = setmetatable(AIBehavior.new("Fleeing"), FleeingBehavior)

	self.threatSource = threatSource
	self.fleeDuration = 0
	self.fleeStartTime = 0

	return self
end

function FleeingBehavior:enter(creature)
	AIBehavior.enter(self, creature)

	-- Get flee duration from creature config
	local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]
	self.fleeDuration = creatureConfig and creatureConfig.FleeDuration or 10
	self.fleeStartTime = tick()

	if AIConfig.Debug.LogBehaviorChanges then
		local threatName = "Unknown"
		if self.threatSource and self.threatSource.Name then
			threatName = self.threatSource.Name
		end
		print("[FleeingBehavior] " .. creature.creatureType .. " fleeing from " .. threatName .. " for " .. self.fleeDuration .. " seconds")
	end
end

function FleeingBehavior:update(creature, deltaTime)
	AIBehavior.update(self, creature, deltaTime)

	-- Check if flee duration has elapsed
	local timeElapsed = tick() - self.fleeStartTime
	if timeElapsed >= self.fleeDuration then
		self:stopFleeing(creature)
		return
	end

	-- TODO: Add actual flee movement here
end

function FleeingBehavior:stopFleeing(creature)
	if AIConfig.Debug.LogBehaviorChanges then
		print("[FleeingBehavior] " .. creature.creatureType .. " stopping flee")
	end

	-- Go back to roaming
	local RoamingBehavior = require(script.Parent.RoamingBehavior)
	creature:setBehavior(RoamingBehavior.new())
end

return FleeingBehavior
