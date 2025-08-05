local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIBehavior = require(script.Parent.AIBehavior)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)

local RangedChasing = setmetatable({}, { __index = AIBehavior })
RangedChasing.__index = RangedChasing

function RangedChasing.new(targetPlayer)
	local self = setmetatable(AIBehavior.new("RangedChasing"), RangedChasing)

	self.targetPlayer = targetPlayer
	self.chaseStartTime = 0
	self.maxChaseTime = 60
	self.lastPositionUpdate = 0
	-- How often (seconds) we will issue a new MoveTo when adjusting range.
	-- Was 0.1 (10× a second) which looked too jittery; bumped to 3 for calmer repositioning.
	self.positionUpdateRate = 3

	return self
end

function RangedChasing:enter(creature)
	AIBehavior.enter(self, creature)
	self.chaseStartTime = os.clock()

	if AIConfig.Debug.LogBehaviorChanges then
		local targetName =
			self.targetPlayer and self.targetPlayer.Name or "Unknown"
		print(
			"[RangedChasing] " .. creature.creatureType .. " moving to optimal range of " .. targetName
		)
	end
end

function RangedChasing:update(creature, deltaTime)
	AIBehavior.update(self, creature, deltaTime)

	-- Cache current time once for this tick so all comparisons use the same value.
	local currentTime = os.clock()

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

	local optimalRange =
		creature.getOptimalRange and creature:getOptimalRange() or 50

	-- Only re-evaluate range and potentially move/attack on the same cadence
	-- as position updates to avoid jitter (positionUpdateRate seconds).
	if currentTime - self.lastPositionUpdate >= self.positionUpdateRate then
		if distance <= optimalRange + 8 and distance >= optimalRange - 8 then
			-- In the sweet spot; stop chasing and just stand ground while shooting
			-- (Shooting is handled by RangedHostile base class now)
			local RoamingBehavior = require(script.Parent.Roaming)
			creature:setBehavior(RoamingBehavior.new())
			return
		end
	end

	local movePosition
	if distance > optimalRange then
		movePosition = targetPosition
	else
		local direction = (currentPosition - targetPosition).Unit
		movePosition = currentPosition + direction * optimalRange
	end

	local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]
	local chaseSpeed =
		creatureConfig and creatureConfig.ChaseSpeed or creature.moveSpeed * 1.2

	-- currentTime already captured near top of function
	if currentTime - self.lastPositionUpdate >= self.positionUpdateRate then
		self:moveTowards(creature, movePosition, chaseSpeed, deltaTime)
		self.lastPositionUpdate = currentTime
	end
end


function RangedChasing:isTargetValid()
	return self.targetPlayer and self.targetPlayer.Parent and self.targetPlayer.Character and self.targetPlayer.Character.PrimaryPart and self.targetPlayer.Character:FindFirstChild(
		"Humanoid"
	) and self.targetPlayer.Character.Humanoid.Health > 0
end

function RangedChasing:giveUpChase(creature, reason)
	if AIConfig.Debug.LogBehaviorChanges then
		print(
			"[RangedChasing] " .. creature.creatureType .. " giving up chase: " .. reason
		)
	end

	local RoamingBehavior = require(script.Parent.Roaming)
	creature:setBehavior(RoamingBehavior.new())
end

return RangedChasing
