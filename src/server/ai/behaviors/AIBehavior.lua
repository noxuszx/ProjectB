-- src/server/ai/behaviors/AIBehavior.lua
-- Abstract base class for all AI behaviors using Strategy pattern
-- Provides the interface that all concrete behaviors must implement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIConfig = require(ReplicatedStorage.Shared.config.AIConfig)

local AIBehavior = {}
AIBehavior.__index = AIBehavior

-- Abstract base class - should not be instantiated directly
function AIBehavior.new(behaviorName)
	local self = setmetatable({}, AIBehavior)
	
	self.behaviorName = behaviorName or "Unknown"
	self.isActive = false
	self.enterTime = 0
	self.lastTransitionTime = 0
	
	return self
end

-- Called when the behavior becomes active
-- Override in concrete implementations
function AIBehavior:enter(creature)
	if AIConfig.Debug.LogBehaviorChanges then
		print("[AIBehavior] " .. creature.creatureType .. " entering " .. self.behaviorName .. " behavior")
	end
	
	self.isActive = true
	self.enterTime = tick()
	self.lastTransitionTime = tick()
end

-- Called every frame while the behavior is active
-- Override in concrete implementations
function AIBehavior:update(creature, deltaTime)
	-- Base implementation does nothing
	-- Concrete behaviors should override this method
end

-- Called when the behavior becomes inactive
-- Override in concrete implementations
function AIBehavior:exit(creature)
	if AIConfig.Debug.LogBehaviorChanges then
		print("[AIBehavior] " .. creature.creatureType .. " exiting " .. self.behaviorName .. " behavior")
	end
	
	self.isActive = false
end

-- Check if this behavior can transition to another behavior
-- Override in concrete implementations for custom validation
function AIBehavior:canTransition(creature, newBehavior)
	-- Check minimum transition delay to prevent rapid state switching
	local timeSinceLastTransition = tick() - self.lastTransitionTime
	if timeSinceLastTransition < AIConfig.BehaviorSettings.StateTransitionDelay then
		return false
	end
	
	-- Base implementation allows all transitions
	return true
end

-- Get how long this behavior has been active
function AIBehavior:getActiveTime()
	if not self.isActive then
		return 0
	end
	return tick() - self.enterTime
end

-- Utility method for behaviors to check if enough time has passed
function AIBehavior:hasBeenActiveFor(seconds)
	return self:getActiveTime() >= seconds
end

-- Utility method to get random time within a range
function AIBehavior:getRandomTime(minMax)
	if type(minMax) == "table" and #minMax == 2 then
		return math.random() * (minMax[2] - minMax[1]) + minMax[1]
	end
	return minMax or 0
end

-- Utility method for line-of-sight checks
function AIBehavior:hasLineOfSight(creature, targetPosition)
	if not AIConfig.BehaviorSettings.LineOfSightEnabled then
		return true
	end

	-- Safety check: ensure creature and model exist
	if not creature or not creature.model or not creature.model.PrimaryPart then
		warn("[AIBehavior] Invalid creature or missing PrimaryPart in hasLineOfSight")
		return false
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {creature.model}

	local origin = creature.model.PrimaryPart.Position + Vector3.new(0, 2, 0) -- Slightly above ground
	local direction = (targetPosition - origin).Unit * creature.detectionRange

	local raycastResult = workspace:Raycast(origin, direction, raycastParams)

	-- If we hit something, check if it's the target or an obstacle
	if raycastResult then
		local distance = (raycastResult.Position - origin).Magnitude
		local targetDistance = (targetPosition - origin).Magnitude

		-- If we hit something closer than the target, line of sight is blocked
		return distance >= targetDistance - 2 -- Small tolerance
	end

	return true
end

-- Utility method to find nearest player
function AIBehavior:findNearestPlayer(creature)
	-- Safety check: ensure creature and model exist
	if not creature or not creature.model or not creature.model.PrimaryPart then
		warn("[AIBehavior] Invalid creature or missing PrimaryPart in findNearestPlayer")
		return nil, math.huge
	end

	local nearestPlayer = nil
	local nearestDistance = math.huge
	local creaturePosition = creature.model.PrimaryPart.Position

	for _, player in pairs(game.Players:GetPlayers()) do
		if player.Character and player.Character.PrimaryPart then
			local distance = (player.Character.PrimaryPart.Position - creaturePosition).Magnitude

			if distance < nearestDistance and distance <= creature.detectionRange then
				-- Check line of sight if enabled
				if self:hasLineOfSight(creature, player.Character.PrimaryPart.Position) then
					nearestPlayer = player
					nearestDistance = distance
				end
			end
		end
	end

	return nearestPlayer, nearestDistance
end

-- Utility method for obstacle avoidance
function AIBehavior:getObstacleAvoidanceDirection(creature, targetDirection)
	-- Safety check: ensure creature and model exist
	if not creature or not creature.model or not creature.model.PrimaryPart then
		warn("[AIBehavior] Invalid creature or missing PrimaryPart in getObstacleAvoidanceDirection")
		return targetDirection -- Return original direction as fallback
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {creature.model}

	local origin = creature.model.PrimaryPart.Position + Vector3.new(0, 1, 0)
	local checkDistance = AIConfig.BehaviorSettings.ObstacleAvoidanceRange
	
	-- Check forward direction
	local forwardRay = workspace:Raycast(origin, targetDirection.Unit * checkDistance, raycastParams)
	
	if not forwardRay then
		return targetDirection -- No obstacle, continue forward
	end
	
	-- Try left and right directions
	local rightDirection = Vector3.new(-targetDirection.Z, 0, targetDirection.X).Unit
	local leftDirection = Vector3.new(targetDirection.Z, 0, -targetDirection.X).Unit
	
	local rightRay = workspace:Raycast(origin, rightDirection * checkDistance, raycastParams)
	local leftRay = workspace:Raycast(origin, leftDirection * checkDistance, raycastParams)
	
	-- Choose the direction with no obstacle, or the one with the furthest obstacle
	if not rightRay and not leftRay then
		-- Both sides clear, choose randomly
		return math.random() > 0.5 and rightDirection or leftDirection
	elseif not rightRay then
		return rightDirection
	elseif not leftRay then
		return leftDirection
	else
		-- Both sides have obstacles, choose the one with the furthest obstacle
		local rightDistance = (rightRay.Position - origin).Magnitude
		local leftDistance = (leftRay.Position - origin).Magnitude
		return rightDistance > leftDistance and rightDirection or leftDirection
	end
end

-- Utility method to move creature towards a target
function AIBehavior:moveTowards(creature, targetPosition, speed, deltaTime)
	local currentPosition = creature.model.PrimaryPart.Position
	local direction = (targetPosition - currentPosition)
	direction = Vector3.new(direction.X, 0, direction.Z).Unit -- Keep on ground plane
	
	-- Apply obstacle avoidance
	direction = self:getObstacleAvoidanceDirection(creature, direction)
	
	-- Calculate new position
	local moveDistance = speed * deltaTime
	local newPosition = currentPosition + (direction * moveDistance)
	
	-- Keep creature on ground
	newPosition = self:snapToGround(newPosition)
	
	-- Update creature position and rotation
	creature.model:SetPrimaryPartCFrame(CFrame.lookAt(newPosition, newPosition + direction))
	creature.position = newPosition
end

-- Utility method to snap position to ground
function AIBehavior:snapToGround(position)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {}
	
	local origin = position + Vector3.new(0, 10, 0)
	local direction = Vector3.new(0, -20, 0)
	
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)
	
	if raycastResult then
		return raycastResult.Position + Vector3.new(0, 2, 0) -- Slightly above ground
	end
	
	return position -- Fallback to original position
end

-- Utility method to check if creature is stuck
function AIBehavior:isCreatureStuck(creature, lastPosition)
	if not lastPosition then
		return false
	end
	
	local currentPosition = creature.model.PrimaryPart.Position
	local distanceMoved = (currentPosition - lastPosition).Magnitude
	
	-- If creature hasn't moved much in the stuck threshold time, it's stuck
	return distanceMoved < 1 and self:hasBeenActiveFor(AIConfig.BehaviorSettings.StuckThreshold)
end

return AIBehavior
