-- src/server/ai/behaviors/RoamingBehavior.lua
-- Roaming behavior - creatures wander around randomly with idle periods
-- Includes random waypoint selection, idle states, and smooth movement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIBehavior = require(script.Parent.AIBehavior)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)

local RoamingBehavior = setmetatable({}, {__index = AIBehavior})
RoamingBehavior.__index = RoamingBehavior

-- Roaming states
local RoamingState = {
	IDLE = "Idle",
	MOVING = "Moving",
	CHOOSING_DESTINATION = "ChoosingDestination"
}

function RoamingBehavior.new()
	local self = setmetatable(AIBehavior.new("Roaming"), RoamingBehavior)

	self.state = RoamingState.IDLE
	self.targetPosition = nil
	self.idleStartTime = 0
	self.idleDuration = 0
	-- Removed unused variables: lastPosition, stuckCheckTime, lastStuckTime, stuckAttempts

	return self
end

function RoamingBehavior:enter(creature)
	AIBehavior.enter(self, creature)

	self.state = RoamingState.IDLE
	self:startIdling(creature)

	if AIConfig.Debug.LogBehaviorChanges then
		print("[RoamingBehavior] " .. creature.creatureType .. " starting to roam")
	end
end

-- Per-frame lightweight movement completion checks (runs regardless of LOD)
function RoamingBehavior:followUp(creature, deltaTime)
	-- Handle movement completion - cheap check that must run every frame
	if self.state == RoamingState.MOVING then
		if not self.targetPosition then
			self.state = RoamingState.CHOOSING_DESTINATION
			return
		end

		local humanoid = creature.model:FindFirstChild("Humanoid")
		if not humanoid then
			self:startIdling(creature)
			return
		end

		-- Check if we just started moving (avoid immediate completion)
		if not self.moveStartTime then
			self.moveStartTime = os.clock()
			self.lastStuckCheckPosition = creature.model.PrimaryPart.Position
			self.stuckCheckTime = os.clock()
		end
		
		local currentPosition = creature.model.PrimaryPart.Position
		local timeSinceStart = os.clock() - self.moveStartTime
		
		-- Movement timeout - give up after 10 seconds
		if timeSinceStart > 10 then
			if AIConfig.Debug.LogBehaviorChanges then
				print(string.format("[RoamingBehavior] %s movement timeout after %.1f seconds", 
					creature.creatureType, timeSinceStart))
			end
			self:startIdling(creature)
			return
		end
		
		-- Stuck detection - check if we haven't moved much in 2 seconds
		local timeSinceStuckCheck = os.clock() - self.stuckCheckTime
		if timeSinceStuckCheck > 2 then
			local distanceMoved = (currentPosition - self.lastStuckCheckPosition).Magnitude
			if distanceMoved < 2 then -- Haven't moved more than 2 studs in 2 seconds
				if AIConfig.Debug.LogBehaviorChanges then
					print(string.format("[RoamingBehavior] %s stuck - only moved %.1f studs in 2 seconds", 
						creature.creatureType, distanceMoved))
				end
				-- Choose a new destination instead of idling
				self.state = RoamingState.CHOOSING_DESTINATION
				return
			end
			self.lastStuckCheckPosition = currentPosition
			self.stuckCheckTime = os.clock()
		end

		-- Distance check for arrival
		local distanceToTarget = (self.targetPosition - currentPosition).Magnitude
		if distanceToTarget < 7 then -- Increased from 3 to handle network throttling
			if AIConfig.Debug.LogBehaviorChanges then
				print(string.format("[RoamingBehavior] %s reached destination (distance: %.1f)", 
					creature.creatureType, distanceToTarget))
			end
			self:startIdling(creature)
			return
		end

		-- Continue moving towards target
		if creature.usePathfinding then
			local PathNav = require(script.Parent.Parent.PathNav)
			local stillFollowing = PathNav.step(creature, creature.moveSpeed)
			-- If path ended or could not be followed, pick a new destination instead of standing
			if not stillFollowing then
				self.state = RoamingState.CHOOSING_DESTINATION
				return
			end
		else
			if AIConfig.Debug.LogBehaviorChanges and math.random() < 0.02 then -- Log 2% of the time to avoid spam
				print(string.format("[RoamingBehavior] %s followUp - still moving, distance: %.1f, time: %.1f", 
					creature.creatureType, distanceToTarget, timeSinceStart))
			end
			self:moveTowards(creature, self.targetPosition, creature.moveSpeed, deltaTime)
		end
	end
end

-- LOD-gated expensive thinking (pathfinding, decision-making)
function RoamingBehavior:update(creature, deltaTime)
	AIBehavior.update(self, creature, deltaTime)

	-- Check for threats/players first (expensive player detection)
	local nearestPlayer, distance = self:findNearestPlayer(creature)
	if AIConfig.Debug.LogBehaviorChanges then
		print(string.format("[RoamingBehavior] %s detection check: nearest=%s dist=%.1f range=%.1f", creature.creatureType, tostring(nearestPlayer and nearestPlayer.Name), distance or -1, creature.detectionRange or -1))
	end
	if nearestPlayer then
		local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]

		if creatureConfig and creatureConfig.Type == "Passive" then
			-- Check if this creature should flee on proximity (default: true)
			local fleeOnProximity = creatureConfig.FleeOnProximity
			if fleeOnProximity == nil then
				fleeOnProximity = true -- Default behavior
			end
			
			if fleeOnProximity then
				-- Passive creatures only flee if player gets very close (within personal space)
				local personalSpaceDistance = creatureConfig.DetectionRange * 0.4 -- 40% of detection range
				if distance <= personalSpaceDistance then
					local FleeingBehavior = require(script.Parent.Fleeing)
					creature:setBehavior(FleeingBehavior.new(nearestPlayer))
					return
				end
			end
			-- If FleeOnProximity is false, creature won't flee from player proximity

		elseif creatureConfig and creatureConfig.Type == "Hostile" then
			local ChasingBehavior = require(script.Parent.Chasing)
			creature:setBehavior(ChasingBehavior.new(nearestPlayer))
			return
		end
	end

	-- Handle expensive state logic (idle timing, destination selection)
	if self.state == RoamingState.IDLE then
		self:updateIdling()
	elseif self.state == RoamingState.CHOOSING_DESTINATION then
		self:updateChoosingDestination(creature)
	end
	-- Note: MOVING state handling moved to followUp() for per-frame execution
end

function RoamingBehavior:startIdling(creature)
	self.state = RoamingState.IDLE
	self.idleStartTime = os.clock()
	self.moveStartTime = nil -- Clear move start time
	self.targetPosition = nil -- Clear target position
	self.lastStuckCheckPosition = nil -- Clear stuck check position
	self.stuckCheckTime = nil -- Clear stuck check time

	local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]
	local idleTimeRange = creatureConfig and creatureConfig.IdleTime or {5, 15}
	self.idleDuration = self:getRandomTime(idleTimeRange)

	if AIConfig.Debug.LogBehaviorChanges then
		print("[RoamingBehavior] " .. creature.creatureType .. " idling for " .. string.format("%.1f", self.idleDuration) .. " seconds")
	end
end

function RoamingBehavior:updateIdling()
	local timeIdling = os.clock() - self.idleStartTime

	if timeIdling >= self.idleDuration then
		self.state = RoamingState.CHOOSING_DESTINATION
	end
end

function RoamingBehavior:updateChoosingDestination(creature)
	local creatureConfig = AIConfig.CreatureTypes[creature.creatureType]
	local roamRadius = creatureConfig and creatureConfig.RoamRadius or 20

	-- Use current position as center for roaming area (not spawn position)
	local currentPosition = creature.model.PrimaryPart.Position
	local centerPosition = currentPosition -- Use current position instead of spawn

	-- Try to find a valid destination (up to 5 attempts)
	local validDestinationFound = false
	local attempts = 0
	local targetPosition
	
	while not validDestinationFound and attempts < 5 do
		attempts = attempts + 1
		
		-- Random target selection with minimum distance
		local randomAngle = math.random() * math.pi * 2
		-- Ensure minimum distance of 10 studs to avoid immediate completion
		local minDistance = math.max(10, roamRadius * 0.3)
		local randomDistance = minDistance + math.random() * (roamRadius - minDistance)
		local targetX = centerPosition.X + math.cos(randomAngle) * randomDistance
		local targetZ = centerPosition.Z + math.sin(randomAngle) * randomDistance
		
		-- Use current Y position to ensure target is at same height level
		targetPosition = Vector3.new(targetX, currentPosition.Y, targetZ)
		
		-- Check if path is clear (simple raycast check)
		local rayDirection = (targetPosition - currentPosition).Unit * (targetPosition - currentPosition).Magnitude
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		local filterList = {creature.model}
		if workspace:FindFirstChild("NPCs") then
			table.insert(filterList, workspace.NPCs)
		end
		raycastParams.FilterDescendantsInstances = filterList
		
		local raycastResult = workspace:Raycast(currentPosition, rayDirection, raycastParams)
		
		-- If no obstruction or obstruction is very close to target, accept it
		if not raycastResult or (targetPosition - raycastResult.Position).Magnitude < 3 then
			validDestinationFound = true
		else
			if AIConfig.Debug.LogBehaviorChanges and attempts == 1 then
				print(string.format("[RoamingBehavior] %s destination blocked, trying another angle", creature.creatureType))
			end
		end
	end
	
	-- Use the best target we found (or last attempt if none were perfect)
	self.targetPosition = targetPosition

	self.state = RoamingState.MOVING
	self.moveStartTime = nil -- Reset move start time for new movement
	
	-- Movement: use pathfinding for arena enemies, else direct MoveTo
	local humanoid = creature.model:FindFirstChild("Humanoid")
	if humanoid then
		if creature.usePathfinding then
			local PathNav = require(script.Parent.Parent.PathNav)
			local waypoints = select(1, PathNav.computePath(creature.model.PrimaryPart.Position, self.targetPosition))
			if waypoints and #waypoints > 0 then
				PathNav.setPath(creature, waypoints)
				-- Kick first step immediately
				PathNav.step(creature, creature.moveSpeed)
			else
				-- Fallback: direct MoveTo if path fails
				humanoid:MoveTo(self.targetPosition)
				self.lastMoveGoal = self.targetPosition
				humanoid.WalkSpeed = creature.moveSpeed
			end
		else
			-- Legacy movement
			humanoid:MoveTo(self.targetPosition)
			self.lastMoveGoal = self.targetPosition
			humanoid.WalkSpeed = creature.moveSpeed
		end
	end

	if AIConfig.Debug.LogBehaviorChanges then
		local distance = (self.targetPosition - currentPosition).Magnitude
		print(string.format("[RoamingBehavior] %s choosing destination:", creature.creatureType))
		print(string.format("  Current pos: (%.1f, %.1f, %.1f)", currentPosition.X, currentPosition.Y, currentPosition.Z))
		print(string.format("  Target pos: (%.1f, %.1f, %.1f)", self.targetPosition.X, self.targetPosition.Y, self.targetPosition.Z))
		print(string.format("  Distance: %.1f studs", distance))
		print("  MoveTo command issued immediately")
	end
end

-- updateMoving() logic moved to followUp() for per-frame execution

return RoamingBehavior
