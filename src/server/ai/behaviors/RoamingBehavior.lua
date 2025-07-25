-- src/server/ai/behaviors/RoamingBehavior.lua
-- Simple roaming behavior - creature just stands still for now
-- TODO: Add actual roaming movement later

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIBehavior = require(script.Parent.AIBehavior)
local AIConfig = require(ReplicatedStorage.Shared.config.AIConfig)

local RoamingBehavior = setmetatable({}, {__index = AIBehavior})
RoamingBehavior.__index = RoamingBehavior

function RoamingBehavior.new()
	local self = setmetatable(AIBehavior.new("Roaming"), RoamingBehavior)
	return self
end

function RoamingBehavior:enter(creature)
	AIBehavior.enter(self, creature)

	if AIConfig.Debug.LogBehaviorChanges then
		print("[RoamingBehavior] " .. creature.creatureType .. " starting to roam")
	end
end

function RoamingBehavior:update(creature, deltaTime)
	AIBehavior.update(self, creature, deltaTime)

	-- Check for threats/players
	local nearestPlayer, distance = self:findNearestPlayer(creature)
	if nearestPlayer then
		if creature.creatureType == "Passive" then
			-- Passive creatures flee from players
			local FleeingBehavior = require(script.Parent.FleeingBehavior)
			creature:setBehavior(FleeingBehavior.new(nearestPlayer))
			return
		else
			-- Hostile creatures chase players
			local ChasingBehavior = require(script.Parent.ChasingBehavior)
			creature:setBehavior(ChasingBehavior.new(nearestPlayer))
			return
		end
	end

	-- TODO: Add actual roaming movement here
end

return RoamingBehavior
