-- src/server/ai/behaviors/RangedAttack.lua
-- Ranged attack behavior - performs LOS checks, respects cooldown, and fires projectiles
-- Used by ranged hostile creatures when in optimal firing position

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AIBehavior = require(script.Parent.AIBehavior)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)
local ProjectileService = require(ServerScriptService.Server.services.ProjectileService)

local RangedAttack = setmetatable({}, { __index = AIBehavior })
RangedAttack.__index = RangedAttack

function RangedAttack.new(targetPlayer)
	local self = setmetatable(AIBehavior.new("RangedAttack"), RangedAttack)

	self.targetPlayer = targetPlayer
	self.attackStartTime = 0
	self.maxAttackTime = 30
	self.lastLOSCheck = 0
	self.losCheckRate = 0.2
	self.hasLOS = false
	self.lastTurnUpdate = 0
	self.lastRangeCheck = 0
	self.rangeCheckRate = 3

	return self
end

function RangedAttack:enter(creature)
	AIBehavior.enter(self, creature)

	self.attackStartTime = os.clock()

	if AIConfig.Debug.LogBehaviorChanges then
		local targetName = self.targetPlayer and self.targetPlayer.Name or "Unknown"
		print("[RangedAttack] " .. creature.creatureType .. " attacking " .. targetName)
	end
end

function RangedAttack:update(creature, deltaTime)
	AIBehavior.update(self, creature, deltaTime)

	if os.clock() - self.attackStartTime > self.maxAttackTime then
		self:stopAttacking(creature, "Attack timeout")
		return
	end

	if not self:isTargetValid() then
		self:stopAttacking(creature, "Target lost")
		return
	end

	if not (self.targetPlayer and self.targetPlayer.Character and self.targetPlayer.Character.PrimaryPart) then
		self:stopAttacking(creature, "Target invalid")
		return
	end

	local targetPosition = self.targetPlayer.Character.PrimaryPart.Position
	local currentPosition = creature.model.PrimaryPart.Position
	local distance = (targetPosition - currentPosition).Magnitude
	local maxRange = creature.getMaxRange and creature:getMaxRange() or 120
	local optimalRange = creature.getOptimalRange and creature:getOptimalRange() or 50

	if distance > maxRange then
		self:stopAttacking(creature, "Target out of max range")
		return
	end

	local currentTime = os.clock()
	if currentTime - self.lastRangeCheck >= self.rangeCheckRate then
		self.lastRangeCheck = currentTime
		if distance > optimalRange + 12 or distance < optimalRange - 12 then
			local RangedChasing = require(script.Parent.RangedChasing)
			creature:setBehavior(RangedChasing.new(self.targetPlayer))
			return
		end
	end

	if currentTime - self.lastLOSCheck >= self.losCheckRate then
		self.hasLOS = self:checkLineOfSight(creature, targetPosition)
		self.lastLOSCheck = currentTime
	end

	if self.hasLOS and creature:canFireAtTarget() then
		self:fireProjectile(creature, targetPosition)
	end

	if AIConfig.Debug.LogBehaviorChanges and math.random() < 0.01 then
		print(
			"[RangedAttack] "
				.. creature.creatureType
				.. " attacking: distance="
				.. string.format("%.1f", distance)
				.. ", LOS="
				.. tostring(self.hasLOS)
		)
	end
end

function RangedAttack:checkLineOfSight(creature, targetPosition)
	local origin = ProjectileService.getMuzzlePosition and ProjectileService.getMuzzlePosition(creature)
		or (creature.model.PrimaryPart.Position + Vector3.new(0, 3.5, 0))
	local ignoreList = { creature.model, self.targetPlayer.Character }

	return ProjectileService.hasLineOfSight(origin, targetPosition, ignoreList)
end

function RangedAttack:fireProjectile(creature, targetPosition)
	local origin = ProjectileService.getMuzzlePosition and ProjectileService.getMuzzlePosition(creature)
		or (creature.model.PrimaryPart.Position + Vector3.new(0, 3.5, 0))
	local weaponName = creature.getWeaponName and creature:getWeaponName() or "SkeletonArrow"
	local ignoreList = { creature.model }

	if creature.playAnimation then
		creature:playAnimation("attack", false, 0.1)
	end

	local result = ProjectileService.fire(origin, targetPosition, weaponName, creature, ignoreList)

	creature:updateFireTime()

	if AIConfig.Debug.LogBehaviorChanges then
		local targetName = self.targetPlayer and self.targetPlayer.Name or "Unknown"
		local hitInfo = result and result.hit and "HIT" or "MISS"
		print("[RangedAttack] " .. creature.creatureType .. " fired at " .. targetName .. " - " .. hitInfo)
	end
end

function RangedAttack:isTargetValid()
	return self.targetPlayer
		and self.targetPlayer.Parent
		and self.targetPlayer.Character
		and self.targetPlayer.Character.PrimaryPart
		and self.targetPlayer.Character:FindFirstChild("Humanoid")
		and self.targetPlayer.Character.Humanoid.Health > 0
end

function RangedAttack:stopAttacking(creature, reason)
	if AIConfig.Debug.LogBehaviorChanges then
		print("[RangedAttack] " .. creature.creatureType .. " stopping attack: " .. reason)
	end

	local RoamingBehavior = require(script.Parent.Roaming)
	creature:setBehavior(RoamingBehavior.new())
end

return RangedAttack
