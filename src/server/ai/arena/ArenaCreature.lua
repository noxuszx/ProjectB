-- src/server/ai/arena/ArenaCreature.lua
-- Arena-specific creature controller with enhanced pathfinding and combat behaviors
-- Handles movement, targeting, and damage for arena events

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

-- External modules
local RagdollModule  = require(ReplicatedStorage.Shared.modules.RagdollModule)
local FoodDropSystem = require(ServerScriptService.Server.loot.FoodDropSystem)

local ArenaCreature = {}
ArenaCreature.__index = ArenaCreature

-- RemoteEvent helper for health bar updates (matches Base creature pattern)
local function getUpdateCreatureHealthRemote()
	-- Reference the pre-defined UpdateCreatureHealth remote
	return ReplicatedStorage.Remotes.UpdateCreatureHealth
end

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
	-- Pathfinding
	PATH_COMPUTE_DISTANCE = 12, -- Increased: Distance to use MoveTo vs pathfinding
	PATH_RECOMPUTE_DISTANCE = 10, -- Increased: How far target must move to trigger recompute
	WAYPOINT_THRESHOLD = 4, -- Increased: Distance to consider waypoint reached
	MAX_PATH_RETRIES = 3,
	
	-- Movement
	BASE_MOVE_SPEED = 20,
	CHASE_SPEED_MULTIPLIER = 1.25,
	STUCK_THRESHOLD = 1, -- Distance to detect if stuck (reduced from 2)
	STUCK_CHECK_TIME = 2.0, -- Time between stuck checks (increased for more time to move)
	
	-- Combat
	ATTACK_RANGE = 5,
	ATTACK_COOLDOWN = 1.0,
	DAMAGE_AMOUNT = 10, -- Base damage
	
	-- Behavior
	AGGRO_RANGE = 150, -- Large range for instant aggro
	LOSE_TARGET_DISTANCE = 200, -- Distance to give up chase
	TARGET_REACQUISITION_TIME = 0.5,
}

-- ============================================
-- CONSTRUCTOR
-- ============================================

function ArenaCreature.new(model, creatureType, spawnPosition)
	local self = setmetatable({}, ArenaCreature)
	
	-- Model and identity
	self.model = model
	self.creatureType = creatureType
	self.spawnPosition = spawnPosition
	self.uniqueId = creatureType .. "_" .. tostring(tick())
	
	-- Components
	self.humanoid = model:FindFirstChild("Humanoid")
	self.rootPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	
	if not self.humanoid or not self.rootPart then
		warn("[ArenaCreature] Missing Humanoid or RootPart for", creatureType)
		if not self.humanoid then
		end
		if not self.rootPart then
		end
		return nil
	end
	
	-- State
	self.isActive = true
	self.isDead = false
	self.isArenaCreature = true
	
	-- Combat properties
	self.health = self.humanoid.MaxHealth
	self.damage = CONFIG.DAMAGE_AMOUNT
	self.attackCooldown = 0
	self.lastAttackTime = 0
	
	-- Movement properties
	self.moveSpeed = CONFIG.BASE_MOVE_SPEED
	self.humanoid.WalkSpeed = self.moveSpeed
	
	-- Targeting
	self.currentTarget = nil
	self.lastTargetPosition = nil
	self.targetAcquisitionTime = 0
	
	-- Pathfinding with staggered updates
	self.currentPath = nil
	self.waypoints = {}
	self.currentWaypointIndex = 1
	self.lastPathComputeTime = os.clock() + math.random() * 0.5 -- Stagger initial updates
	self.pathUpdateInterval = 0.5 + math.random() * 0.3 -- Random interval 0.5-0.8s
	self.pathRetries = 0
	
	-- Stuck detection
	self.lastPosition = self.rootPart.Position
	self.lastStuckCheckTime = 0
	self.stuckCounter = 0
	
	-- Set up death handling
	self:setupDeathHandling()

	-- Set up health display updates for client UI
	self:setupHealthDisplay()
	
	-- Set collision group for better movement
	self:setupCollisions()
	
	print(string.format("[ArenaCreature] Created %s at position (%.1f, %.1f, %.1f)", 
		creatureType, spawnPosition.X, spawnPosition.Y, spawnPosition.Z))
	
	return self
end

-- ============================================
-- INITIALIZATION
-- ============================================

function ArenaCreature:setupHealthDisplay()
	-- Hook health changes to drive client health bars
	local humanoid = self.humanoid
	if not humanoid then return end
	
	humanoid.HealthChanged:Connect(function(newHealth)
		local maxHealth = humanoid.MaxHealth or 100
		-- Only send when hurt; client hides when full
		if newHealth < maxHealth then
			local remote = getUpdateCreatureHealthRemote()
			remote:FireAllClients(self.model, newHealth, maxHealth)
		end
		-- If dead or zero, notify as well so client can remove
		if newHealth <= 0 then
			local remote = getUpdateCreatureHealthRemote()
			remote:FireAllClients(self.model, 0, maxHealth)
		end
	end)
end

function ArenaCreature:setupDeathHandling()
	-- Ensure joints are preserved on death so ragdoll can convert Motor6Ds to constraints
	self.humanoid.BreakJointsOnDeath = false

	self.humanoid.Died:Connect(function()
		self:die()
	end)
	
	-- Hide health bar
	self.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	self.humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	
	-- Tag the humanoid so weapons can damage it properly
	CollectionService:AddTag(self.humanoid, "Creature")
	CollectionService:AddTag(self.model, "Creature")
end

function ArenaCreature:setupCollisions()
	-- Only unanchor parts and set network owner - no collision groups for now
	local anchoredCount = 0
	for _, part in ipairs(self.model:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Check if any parts are anchored (they shouldn't be!)
			if part.Anchored then
				anchoredCount = anchoredCount + 1
				part.Anchored = false -- Unanchor it!
				warn("[ArenaCreature] Found anchored part:", part.Name, "- unanchoring it")
			end
		end
	end
	
	-- Ensure server owns physics
	self.rootPart:SetNetworkOwner(nil)
end

-- ============================================
-- TARGETING SYSTEM
-- ============================================

function ArenaCreature:setTarget(player)
	if self.currentTarget == player then
		return
	end
	
	self.currentTarget = player
	self.targetAcquisitionTime = os.clock()
	self.lastTargetPosition = nil
	self.currentPath = nil
	self.waypoints = {}
	self.currentWaypointIndex = 1
	
	if player then
			-- Immediately start moving towards target
		self:updatePath()
	else
	end
end

function ArenaCreature:validateTarget()
	if not self.currentTarget then
		return false
	end
	
	local character = self.currentTarget.Character
	if not character then
		return false
	end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	
	local targetRoot = character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		return false
	end
	
	-- Check if target is too far
	local distance = (targetRoot.Position - self.rootPart.Position).Magnitude
	if distance > CONFIG.LOSE_TARGET_DISTANCE then
		return false
	end
	
	return true
end

-- ============================================
-- PATHFINDING SYSTEM
-- ============================================

function ArenaCreature:updatePath()
	if not self.currentTarget or not self.currentTarget.Character then
		return false
	end
	
	local targetRoot = self.currentTarget.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		return false
	end
	
	local targetPosition = targetRoot.Position
	local myPosition = self.rootPart.Position
	local distance = (targetPosition - myPosition).Magnitude
	
	-- Use direct movement for short distances
	if distance < CONFIG.PATH_COMPUTE_DISTANCE then
		self.humanoid:MoveTo(targetPosition)
		self.currentPath = nil
		-- Keep waypoints empty but save target position to prevent recomputation
		self.waypoints = {}
		self.lastTargetPosition = targetPosition
		return true
	end
	
	-- Check if we need to recompute path
	if self.lastTargetPosition then
		local targetMoved = (targetPosition - self.lastTargetPosition).Magnitude
		if targetMoved < CONFIG.PATH_RECOMPUTE_DISTANCE and self.currentPath and #self.waypoints > 0 then
			-- Target hasn't moved much and we still have waypoints, keep using current path
			return true
		end
	end
	
	-- Compute new path
	local success = self:computePath(targetPosition)
	if success then
		self.lastTargetPosition = targetPosition
		self.pathRetries = 0
	else
		self.pathRetries = self.pathRetries + 1
		if self.pathRetries >= CONFIG.MAX_PATH_RETRIES then
			-- Fall back to direct movement
			self.humanoid:MoveTo(targetPosition)
			self.pathRetries = 0
		end
	end
	
	return success
end

function ArenaCreature:computePath(targetPosition)
	-- Check with ArenaAIManager if we can compute a path (throttling)
	local ArenaAIManager = require(script.Parent.ArenaAIManager)
	local aiManager = ArenaAIManager.getInstance()
	
	if not aiManager:canComputePath(self.uniqueId) then
		-- Throttled, skip this computation
		return false
	end
	
	
	-- Record that we're computing a path
	aiManager:recordPathCompute(self.uniqueId)
	
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentMaxSlope = 45,
		WaypointSpacing = 4,
		Costs = {
			Water = 20,
			DangerZone = math.huge,
		}
	})
	
	local success, errorMessage = pcall(function()
		path:ComputeAsync(self.rootPart.Position, targetPosition)
	end)
	
	if not success then
		warn("[ArenaCreature] Path computation failed:", errorMessage)
		return false
	end
	
	if path.Status == Enum.PathStatus.Success then
		self.currentPath = path
		self.waypoints = path:GetWaypoints()
		self.currentWaypointIndex = 1
		
		
		-- Start moving to first waypoint
		if #self.waypoints > 0 then
			self:moveToWaypoint()
		end
		
		return true
	else
		warn("[ArenaCreature] Path status:", path.Status)
		return false
	end
end

function ArenaCreature:moveToWaypoint()
	if not self.waypoints or #self.waypoints == 0 then
		return
	end
	
	if self.currentWaypointIndex > #self.waypoints then
		-- Reached end of path
		self.currentPath = nil
		return
	end
	
	local waypoint = self.waypoints[self.currentWaypointIndex]
	
	-- Handle jump waypoints
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		self.humanoid.Jump = true
	end
	
	-- Move to waypoint
	self.humanoid:MoveTo(waypoint.Position)
end

function ArenaCreature:updateMovement()
	if not self.currentTarget then
		return
	end
	
	-- Check if we have waypoints to follow
	if self.waypoints and #self.waypoints > 0 then
		local currentWaypoint = self.waypoints[self.currentWaypointIndex]
		if currentWaypoint then
			-- Use XZ distance only (ignore Y axis for waypoint reaching)
			local myPos = self.rootPart.Position
			local wpPos = currentWaypoint.Position
			local xzDistance = ((myPos.X - wpPos.X)^2 + (myPos.Z - wpPos.Z)^2)^0.5
			
			-- Check if reached waypoint (using XZ distance)
			if xzDistance < CONFIG.WAYPOINT_THRESHOLD then
				self.currentWaypointIndex = self.currentWaypointIndex + 1
				self:moveToWaypoint()
			end
		end
	end
	
	-- Update speed based on chase state
	local targetDistance = self:getTargetDistance()
	if targetDistance and targetDistance < CONFIG.AGGRO_RANGE then
		self.humanoid.WalkSpeed = self.moveSpeed * CONFIG.CHASE_SPEED_MULTIPLIER
	else
		self.humanoid.WalkSpeed = self.moveSpeed
	end
end

-- ============================================
-- COMBAT SYSTEM
-- ============================================

function ArenaCreature:updateCombat(deltaTime)
	if not self.currentTarget or not self:validateTarget() then
		return
	end
	
	local targetRoot = self.currentTarget.Character.HumanoidRootPart
	local distance = (targetRoot.Position - self.rootPart.Position).Magnitude
	
	-- Update attack cooldown
	self.attackCooldown = math.max(0, self.attackCooldown - deltaTime)
	
	-- Check if in attack range
	if distance <= CONFIG.ATTACK_RANGE and self.attackCooldown <= 0 then
		self:performAttack()
	end
end

function ArenaCreature:performAttack()
	if not self.currentTarget or not self.currentTarget.Character then
		return
	end
	
	local targetHumanoid = self.currentTarget.Character:FindFirstChild("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end
	
	-- Deal damage
	targetHumanoid:TakeDamage(self.damage)
	
	-- Play attack animation if available
	local animator = self.humanoid:FindFirstChild("Animator")
	if animator then
		-- You can add attack animation here
	end
	
	-- Set cooldown
	self.attackCooldown = CONFIG.ATTACK_COOLDOWN
	self.lastAttackTime = os.clock()
	
end

-- ============================================
-- STUCK DETECTION
-- ============================================

function ArenaCreature:checkIfStuck()
	local currentTime = os.clock()
	if currentTime - self.lastStuckCheckTime < CONFIG.STUCK_CHECK_TIME then
		return false
	end
	
	self.lastStuckCheckTime = currentTime
	
	local currentPosition = self.rootPart.Position
	local distanceMoved = (currentPosition - self.lastPosition).Magnitude
	
	if distanceMoved < CONFIG.STUCK_THRESHOLD then
		self.stuckCounter = self.stuckCounter + 1
		
		if self.stuckCounter >= 2 then
			-- We're stuck, try to unstuck
			self:handleStuck()
			return true
		end
	else
		self.stuckCounter = 0
	end
	
	self.lastPosition = currentPosition
	return false
end

function ArenaCreature:handleStuck()
	print(string.format("[ArenaCreature] %s is stuck, attempting to unstuck", self.creatureType))
	
	-- Clear current path
	self.currentPath = nil
	self.waypoints = {}
	self.currentWaypointIndex = 1
	
	-- Try to jump
	self.humanoid.Jump = true
	
	-- Move in a random direction briefly
	local randomAngle = math.random() * math.pi * 2
	local unstuckPosition = self.rootPart.Position + Vector3.new(
		math.cos(randomAngle) * 5,
		0,
		math.sin(randomAngle) * 5
	)
	self.humanoid:MoveTo(unstuckPosition)
	
	-- Reset stuck counter
	self.stuckCounter = 0
	
	-- Recompute path after a brief delay
	task.wait(0.5)
	if self.currentTarget then
		self:updatePath()
	end
end

-- ============================================
-- MAIN UPDATE
-- ============================================

function ArenaCreature:update(deltaTime)
	if not self.isActive or self.isDead then
		return
	end
	
	if not self.currentTarget then
		-- No target, don't run stuck detection
		return
	end
	
	-- Validate and update target
	if not self:validateTarget() then
		self.currentTarget = nil
		return
	end
	
	-- Check if we're in close range for direct movement
	local targetRoot = self.currentTarget.Character and self.currentTarget.Character:FindFirstChild("HumanoidRootPart")
	if targetRoot then
		local distance = (targetRoot.Position - self.rootPart.Position).Magnitude
		
		if distance < CONFIG.PATH_COMPUTE_DISTANCE then
			-- Close range - use direct movement constantly
			self.humanoid:MoveTo(targetRoot.Position)
			self.waypoints = {} -- Keep waypoints empty
			self.lastTargetPosition = targetRoot.Position
		else
			-- Long range - use pathfinding with staggered intervals
			local currentTime = os.clock()
			if currentTime - self.lastPathComputeTime > self.pathUpdateInterval then
				-- Only update path if we don't have waypoints or target has moved significantly
				if #self.waypoints == 0 or self.currentWaypointIndex > #self.waypoints then
					-- We've run out of waypoints, need new path
					if self:updatePath() then
						self.lastPathComputeTime = currentTime
					end
				elseif self.lastTargetPosition then
					-- Check if target moved significantly
					local targetMoved = (targetRoot.Position - self.lastTargetPosition).Magnitude
					if targetMoved >= CONFIG.PATH_RECOMPUTE_DISTANCE then
						-- Only log if we can actually compute
						if self:updatePath() then
							self.lastPathComputeTime = currentTime
						end
					end
				end
			end
		end
	end
	
	-- Update movement
	self:updateMovement()
	
	-- Check if stuck
	self:checkIfStuck()
	
	-- Update combat
	self:updateCombat(deltaTime)
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

function ArenaCreature:getTargetDistance()
	if not self.currentTarget or not self.currentTarget.Character then
		return nil
	end
	
	local targetRoot = self.currentTarget.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		return nil
	end
	
	return (targetRoot.Position - self.rootPart.Position).Magnitude
end

function ArenaCreature:takeDamage(amount)
	if self.isDead then
		return
	end
	
	self.humanoid:TakeDamage(amount)
	-- Explicitly send an update (HealthChanged will also fire, but this is immediate)
	local health = self.humanoid.Health
	local maxHealth = self.humanoid.MaxHealth
	if health < maxHealth then
		local remote = getUpdateCreatureHealthRemote()
		remote:FireAllClients(self.model, health, maxHealth)
	end
end

-- ============================================
-- DEATH HANDLING
-- ============================================

function ArenaCreature:die()
	if self.isDead then
		return
	end
	
	self.isDead = true
	self.isActive = false
	
	print(string.format("[ArenaCreature] %s died", self.creatureType))
	
	-- Notify clients to remove health bar
	local remote = getUpdateCreatureHealthRemote()
	local mh = self.humanoid and self.humanoid.MaxHealth or 100
	remote:FireAllClients(self.model, 0, mh)
	
	-- Clean up
	self.currentTarget = nil
	self.currentPath = nil
	self.waypoints = {}
	
	-- Handle death effects based on creature type via shared systems
	if self.creatureType:find("Scorpion") then
		-- Scorpion drops 1-2 food items using server FoodDropSystem
		local drops = math.random(1, 2)
		for i = 1, drops do
			local ok = pcall(function()
				FoodDropSystem.dropFood("Scorpion", self.rootPart.Position, self.model)
			end)
			if not ok then
				warn("[ArenaCreature] FoodDropSystem.dropFood failed for Scorpion (drop #" .. i .. ")")
			end
		end
		Debris:AddItem(self.model, 2)
	else

		-- Use shared RagdollModule for permanent NPC ragdoll
		local ok, res = pcall(function()
			return RagdollModule.PermanentNpcRagdoll(self.model)
		end)
		if not ok or not res then
			warn("[ArenaCreature] RagdollModule.PermanentNpcRagdoll failed for", self.creatureType)
		end
		Debris:AddItem(self.model, 10)
	end
end

function ArenaCreature:destroy()
	self.isActive = false
	self.isDead = true
	
	-- Remove tags
	if self.humanoid then
		CollectionService:RemoveTag(self.humanoid, "Creature")
	end
	if self.model then
		CollectionService:RemoveTag(self.model, "Creature")
	end
	
	if self.model and self.model.Parent then
		self.model:Destroy()
	end
end

return ArenaCreature
