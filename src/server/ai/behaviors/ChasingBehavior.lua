-- src/server/ai/behaviors/ChasingBehavior.lua
-- Simple chasing behavior - hostile creatures pursue target players
-- TODO: Add actual movement and better logic later

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIBehavior = require(script.Parent.AIBehavior)
local AIConfig = require(ReplicatedStorage.Shared.config.AIConfig)

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

	-- Check if target is still within range
	if self.targetPlayer and self.targetPlayer.Character and self.targetPlayer.Character.PrimaryPart then
		local targetPosition = self.targetPlayer.Character.PrimaryPart.Position
		local distance = (targetPosition - creature.model.PrimaryPart.Position).Magnitude

		if distance > creature.detectionRange * 1.5 then -- Give some leeway
			self:giveUpChase(creature, "Target out of range")
			return
		end

		-- TODO: Add actual chase movement here
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

	-- Go back to roaming
	local RoamingBehavior = require(script.Parent.RoamingBehavior)
	creature:setBehavior(RoamingBehavior.new())
end

return ChasingBehavior
