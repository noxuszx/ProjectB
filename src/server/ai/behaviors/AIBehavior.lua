-- src/server/ai/behaviors/AIBehavior.lua
-- Abstract base class for all AI behaviors using Strategy pattern
-- Provides the interface that all concrete behaviors must implement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)

local AIBehavior = {}
AIBehavior.__index = AIBehavior

function AIBehavior.new(behaviorName)
	
	local self = setmetatable({}, AIBehavior)
	self.behaviorName = behaviorName or "Unknown"
	self.isActive = false
	self.enterTime = 0
	self.lastTransitionTime = 0

	return self
end

function AIBehavior:enter(creature)
	if AIConfig.Debug.LogBehaviorChanges then
		print(
			"[AIBehavior] " .. creature.creatureType .. " entering " .. self.behaviorName .. " behavior"
		)
	end

	self.isActive = true
	self.enterTime = os.clock()
	self.lastTransitionTime = os.clock()
end

function AIBehavior:update(creature, deltaTime)
	-- Base implementation does nothing
	-- Concrete behaviors should override this method
end

function AIBehavior:exit(creature)
	if AIConfig.Debug.LogBehaviorChanges then
		print(
			"[AIBehavior] " .. creature.creatureType .. " exiting " .. self.behaviorName .. " behavior"
		)
	end

	self.isActive = false
end

function AIBehavior:getActiveTime()
	if not self.isActive then
		return 0
	end
	return os.clock() - self.enterTime
end

function AIBehavior:hasBeenActiveFor(seconds)
	return self:getActiveTime() >= seconds
end

function AIBehavior:getRandomTime(minMax)
	if type(minMax) == "table" and #minMax == 2 then
		return math.random() * (minMax[2] - minMax[1]) + minMax[1]
	end
	return minMax or 0
end

function AIBehavior:findNearestPlayer(creature)
	if not creature or not creature.model or not creature.model.PrimaryPart then
		warn(
			"[AIBehavior] Invalid creature or missing PrimaryPart in findNearestPlayer"
		)
		return nil, math.huge
	end

	local nearestPlayer = nil
	local nearestDistance = math.huge
	local creaturePosition = creature.model.PrimaryPart.Position

	for _, player in pairs(game.Players:GetPlayers()) do
		if player.Character and player.Character.PrimaryPart then
			local distance =
				(player.Character.PrimaryPart.Position - creaturePosition).Magnitude

			if distance < nearestDistance and distance <= creature.detectionRange then
				nearestPlayer = player
				nearestDistance = distance
			end
		end
	end

	return nearestPlayer, nearestDistance
end

function AIBehavior:moveTowards(creature, targetPosition, speed, deltaTime)
	if not creature or not creature.model or not creature.model.PrimaryPart then
		warn(
			"[AIBehavior] Invalid creature or missing PrimaryPart in moveTowards"
		)
		return
	end

	local humanoid = creature.model:FindFirstChild("Humanoid")
	if humanoid then
		-- Debounce MoveTo calls to prevent pathfinding thrashing
		if not self.lastMoveGoal or (targetPosition - self.lastMoveGoal).Magnitude > 1 then
			humanoid:MoveTo(targetPosition)
			self.lastMoveGoal = targetPosition
		end
		humanoid.WalkSpeed = speed
		if creature.model.PrimaryPart then
			creature.position = creature.model.PrimaryPart.Position
		end
	else
		warn(
			"[AIBehavior] No Humanoid found in creature model: " .. creature.creatureType
		)
	end
end

return AIBehavior
