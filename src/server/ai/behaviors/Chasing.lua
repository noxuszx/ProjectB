-- src/server/ai/behaviors/ChasingBehavior.lua
-- Simple chasing behavior - hostile creatures pursue target players
-- TODO: Add actual movement and better logic later

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIBehavior = require(script.Parent.AIBehavior)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)
local PathNav = require(script.Parent.Parent.PathNav)

local ChasingBehavior = setmetatable({}, {__index = AIBehavior})
ChasingBehavior.__index = ChasingBehavior

function ChasingBehavior.new(targetPlayer)
	local self = setmetatable(AIBehavior.new("Chasing"), ChasingBehavior)

	self.targetPlayer = targetPlayer
	self.chaseStartTime = 0
	self.maxChaseTime = 30

	return self
end

function ChasingBehavior:enter(creature)
	AIBehavior.enter(self, creature)

	self.chaseStartTime = os.clock()


	if AIConfig.Debug.LogBehaviorChanges then
		local targetName = self.targetPlayer and self.targetPlayer.Name or "Unknown"
		print("[ChasingBehavior] " .. creature.creatureType .. " chasing " .. targetName)
	end
end

function ChasingBehavior:update(creature, deltaTime)
	AIBehavior.update(self, creature, deltaTime)

	if os.clock() - self.chaseStartTime > self.maxChaseTime then
		self:giveUpChase(creature, "Chase timeout")
		return
	end

	if not self:isTargetValid() then
		self:giveUpChase(creature, "Target lost")
		return
	end

	if not (self.targetPlayer and self.targetPlayer.Character and self.targetPlayer.Character.PrimaryPart) then
		self:giveUpChase(creature, "Target invalid")
		return
	end

	local targetPosition = self.targetPlayer.Character.PrimaryPart.Position
	local currentPosition = creature.model.PrimaryPart.Position
	local distance = (targetPosition - currentPosition).Magnitude

	if distance > creature.detectionRange * 1.5 then
		self:giveUpChase(creature, "Target out of range")
		return
	end

	local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]
	local chaseSpeed = creatureConfig and creatureConfig.ChaseSpeed or creature.moveSpeed * 1.2

	if creature.usePathfinding then
		-- Repath cadence + target movement threshold
		local should = PathNav.shouldRepath(creature, targetPosition, 1.2, 8)
		if should then
			local waypoints = select(1, PathNav.computePath(currentPosition, targetPosition))
			if waypoints and #waypoints > 0 then
				PathNav.setPath(creature, waypoints)
				PathNav.markTarget(creature, targetPosition)
			end
		end
		local following = PathNav.step(creature, chaseSpeed)
		if not following then
			-- Try one immediate repath if budget allows
			local waypoints = select(1, PathNav.computePath(currentPosition, targetPosition))
			if waypoints and #waypoints > 0 then
				PathNav.setPath(creature, waypoints)
				PathNav.markTarget(creature, targetPosition)
				PathNav.step(creature, chaseSpeed)
			else
				-- Fallback to direct MoveTo to avoid freezing in place
				self:moveTowards(creature, targetPosition, chaseSpeed, deltaTime)
			end
		end
	else
		self:moveTowards(creature, targetPosition, chaseSpeed, deltaTime)
	end

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

	local RoamingBehavior = require(script.Parent.Roaming)
	creature:setBehavior(RoamingBehavior.new())
end

return ChasingBehavior
