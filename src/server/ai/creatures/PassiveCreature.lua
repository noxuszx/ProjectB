-- src/server/ai/creatures/PassiveCreature.lua
-- Simple passive creature AI - roams around and flees when hurt
-- Uses behavior system for state management

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseCreature = require(script.Parent.BaseCreature)
local AIConfig = require(ReplicatedStorage.Shared.config.AIConfig)

-- Import behavior classes
local RoamingBehavior = require(script.Parent.Parent.behaviors.RoamingBehavior)
local FleeingBehavior = require(script.Parent.Parent.behaviors.FleeingBehavior)

local PassiveCreature = setmetatable({}, {__index = BaseCreature})
PassiveCreature.__index = PassiveCreature

function PassiveCreature.new(model, creatureType, spawnPosition)
	local self = setmetatable(BaseCreature.new(model, creatureType, spawnPosition), PassiveCreature)

	-- Passive creature specific properties
	local config = AIConfig.CreatureTypes[creatureType] or {}
	self.fleeSpeed = config.FleeSpeed or 24
	self.fleeDuration = config.FleeDuration or 10
	self.roamRadius = config.RoamRadius or 15
	self.originalPosition = spawnPosition

	-- Start with roaming behavior
	self:setBehavior(RoamingBehavior.new())

	return self
end

function PassiveCreature:update(deltaTime)
	BaseCreature.update(self, deltaTime)
end

-- Override takeDamage to trigger fleeing behavior
function PassiveCreature:takeDamage(amount)
	BaseCreature.takeDamage(self, amount)

	if self.health > 0 then
		-- Switch to fleeing behavior when damaged
		self:setBehavior(FleeingBehavior.new())
	end
end

return PassiveCreature
