-- src/server/ai/behaviors/ChasingBehavior.lua
-- Simple chasing behavior - hostile creatures pursue target players
-- TODO: Add actual movement and better logic later

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIBehavior = require(script.Parent.aiBehavior)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.ai)

local ChasingBehavior = setmetatable({}, {__index = AIBehavior})
ChasingBehavior.__index = ChasingBehavior

function ChasingBehavior.new(targetPlayer)
	local self = setmetatable(AIBehavior.new("Chasing"), ChasingBehavior)

	self.targetPlayer = targetPlayer
	self.chaseStartTime = 0
	self.maxChaseTime = 30 -- Give up chase after 30 seconds

	return self
end

function ChasingBehavior:enter(creature)
	AIBehavior.enter(self, creature)

	self.chaseStartTime = tick()

	if AIConfig.Debug.LogBehaviorChanges then
		local targetName = self.targetPlayer and self.targetPlayer.Name or "Unknown"
		print("[ChasingBehavior] " .. creature.creatureType .. " chasing " .. targetName)
	end
end

function ChasingBehavior:update(creature, deltaTime)
	AIBehavior.update(self, creature, deltaTime)

	-- Check if we've been chasing too long
	if tick() - self.chaseStartTime > self.maxChaseTime then
		self:giveUpChase(creature, "Chase timeout")
		return
	end

	-- Check if target is still valid
	if not self:isTargetValid() then
		self:giveUpChase(creature, "Target lost")
		return
	end

	-- Check if target is still within range and get position
	if not (self.targetPlayer and self.targetPlayer.Character and self.targetPlayer.Character.PrimaryPart) then
		self:giveUpChase(creature, "Target invalid")
		return
	end

	local targetPosition = self.targetPlayer.Character.PrimaryPart.Position
	local currentPosition = creature.model.PrimaryPart.Position
	local distance = (targetPosition - currentPosition).Magnitude

	-- Check if target is too far away
	if distance > creature.detectionRange * 1.5 then
		self:giveUpChase(creature, "Target out of range")
		return
	end

	-- REMOVED: Line of sight check - simplified for reliability

	-- Move towards the target using chase speed
	local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]
	local chaseSpeed = creatureConfig and creatureConfig.ChaseSpeed or creature.moveSpeed * 1.2

	self:moveTowards(creature, targetPosition, chaseSpeed, deltaTime)

	-- Optional: Add some debug info
	if AIConfig.Debug.LogBehaviorChanges and math.random() < 0.01 then -- Log occasionally
		print("[ChasingBehavior] " .. creature.creatureType .. " chasing " .. self.targetPlayer.Name ..
			  " (distance: " .. string.format("%.1f", distance) .. ")")
	end
end

function ChasingBehavior:isTargetValid()
	return self.targetPlayer and
		   self.targetPlayer.Parent and
		   self.targetPlayer.Character and
		   self.targetPlayer.Character.PrimaryPart and
		   self.targetPlayer.Character:FindFirstChild("Humanoid") and
		   self.targetPlayer.Character.Humanoid.Health > 0
end

function ChasingBehavior:giveUpChase(creature, reason)
	if AIConfig.Debug.LogBehaviorChanges then
		print("[ChasingBehavior] " .. creature.creatureType .. " giving up chase: " .. reason)
	end

	local RoamingBehavior = require(script.Parent.roaming)
	creature:setBehavior(RoamingBehavior.new())
end

return ChasingBehavior
