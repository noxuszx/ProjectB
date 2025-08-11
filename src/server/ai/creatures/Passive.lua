-- src/server/ai/creatures/PassiveCreature.lua
-- Simple passive creature AI - roams around and flees when hurt
-- Uses behavior system for state management

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseCreature = require(script.Parent.Base)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)

local RoamingBehavior = require(script.Parent.Parent.behaviors.Roaming)
local FleeingBehavior = require(script.Parent.Parent.behaviors.Fleeing)

local PassiveCreature = setmetatable({}, {__index = BaseCreature})
PassiveCreature.__index = PassiveCreature


function PassiveCreature.new(model, creatureType, spawnPosition)

	local self = setmetatable(BaseCreature.new(model, creatureType, spawnPosition), PassiveCreature)
	
	local config = AIConfig.CreatureTypes[creatureType] or {}
	self.fleeSpeed = config.FleeSpeed or 24
	self.fleeDuration = config.FleeDuration or 10
	self.roamRadius = config.RoamRadius or 15

	self.originalPosition = spawnPosition
	self:setBehavior(RoamingBehavior.new())
	return self

end


function PassiveCreature:update(deltaTime)
	BaseCreature.update(self, deltaTime)
end


function PassiveCreature:takeDamage(amount, threatSource)
	BaseCreature.takeDamage(self, amount)

	if self.health > 0 then
		self:setBehavior(FleeingBehavior.new(threatSource))
	end
end

function PassiveCreature:restorePostMountBehavior()
	-- Restore to roaming behavior after being dismounted
	if not self.currentBehavior or self.currentBehavior.behaviorName ~= "Roaming" then
		self:setBehavior(RoamingBehavior.new())
	end
end

return PassiveCreature
