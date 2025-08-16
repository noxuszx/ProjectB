-- src/server/ai/creatures/RangedHostile.lua
-- Ranged hostile creature AI - maintains distance and fires projectiles at players
-- Extends HostileCreature but overrides behavior management for ranged combat

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local HostileCreature = require(script.Parent.Hostile)
local BaseCreature = require(script.Parent.Base)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)
local ProjectileService = require(ServerScriptService.Server.services.ProjectileService)
local SoundPlayer = require(ReplicatedStorage.Shared.modules.SoundPlayer)

local RoamingBehavior = require(script.Parent.Parent.behaviors.Roaming)
local RangedChasingBehavior =
	require(script.Parent.Parent.behaviors.RangedChasing)

local RangedHostile = setmetatable({}, { __index = HostileCreature })
RangedHostile.__index = RangedHostile

function RangedHostile.new(model, creatureType, spawnPosition)
	local self =
		setmetatable(
			HostileCreature.new(model, creatureType, spawnPosition),
			RangedHostile
		)

	local config = AIConfig.CreatureTypes[creatureType] or {}
	self.optimalRange = config.OptimalRange or 50
	self.maxRange = config.MaxRange or 120
	self.weaponName = config.WeaponName or "SkeletonArrow"

	self.currentTarget = nil
	
	-- Behavior switching delays to prevent instant kiting
	self.lastBehaviorSwitchTime = 0
	self.behaviorSwitchDelay = config.KitingDelay or 3.0  -- Wait before switching behaviors
	
	-- Burst shooting system - configurable via AIConfig
	self.shotsInCurrentBurst = 0
	self.maxShotsPerBurst = config.ShotsPerBurst or 3
	self.shotInterval = config.ShotInterval or 1.0      -- 1 second between shots within burst
	self.burstCooldown = config.BurstCooldown or 3.0    -- 3 seconds after completing a burst
	self.lastShotTime = 0
	self.lastBurstEndTime = 0
	self.isInCooldown = false

	-- Animation system
	self.animationTracks = {}
	self:setupAnimations()

	-- Look-at system using AlignOrientation constraint
	self.lookAtEnabled = false
	self.alignOrientation = nil
	self.lookAtAttachment = nil
	self:setupLookAtSystem()

	-- Enable smooth movement and rotation via Roblox's built-in systems
	local humanoid = self.model:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true  -- Let Roblox handle smooth rotation during movement
	end

	self:disconnectTouchDamage()
	self:setBehavior(RoamingBehavior.new())

	return self
end

function RangedHostile:update(deltaTime)
	BaseCreature.update(self, deltaTime)
	self:manageBehaviors()
	self:updateLookAtSystem()
	self:updateConstantShooting()
end

function RangedHostile:manageBehaviors()
	local nearestPlayer = self:findNearestPlayer()

	if not nearestPlayer then
		local behaviorName = self.currentBehavior and self.currentBehavior.behaviorName or ""
		if behaviorName ~= "Roaming" then
			self:setBehavior(RoamingBehavior.new())
			self.currentTarget = nil
			self:disableLookAt()
			self:resetBurst()  -- Reset burst when losing target
		end
		return
	end

	local distance =
		(nearestPlayer.Character.PrimaryPart.Position - self.model.PrimaryPart.Position).Magnitude

	if distance > self.detectionRange then
		local behaviorName = self.currentBehavior and self.currentBehavior.behaviorName or ""
		if behaviorName ~= "Roaming" then
			self:setBehavior(RoamingBehavior.new())
			self.currentTarget = nil
			self:disableLookAt()
			self:resetBurst()  -- Reset burst when losing target
		end
		return
	end

	self.currentTarget = nearestPlayer

	-- First time detecting player - play detect animation, enable look-at, and start burst
	local behaviorName = self.currentBehavior and self.currentBehavior.behaviorName or ""
if behaviorName == "Roaming" and self.shotsInCurrentBurst == 0 and not self.isInCooldown then
        -- Only trigger once per acquisition, not every frame while roaming
		self:playAnimation("detect", false, 0.2)
		self:enableLookAt()
		self:startNewBurst()  -- Start fresh burst when detecting player
	end

	local currentBehaviorName = self.currentBehavior and self.currentBehavior.behaviorName or ""
	local currentTime = os.clock()
	local canSwitchBehavior = currentTime - self.lastBehaviorSwitchTime >= self.behaviorSwitchDelay
	
	-- Only switch to chasing if player is too close (for kiting behavior)
	if distance < self.optimalRange - 7 then
		if currentBehaviorName ~= "RangedChasing" and canSwitchBehavior then
			self:setBehavior(RangedChasingBehavior.new(nearestPlayer))
			self.lastBehaviorSwitchTime = currentTime
		end
	-- Otherwise, just stay put and keep shooting (no need for RangedAttack behavior)
	elseif currentBehaviorName == "RangedChasing" and canSwitchBehavior then
		-- Stop chasing and just stand ground while shooting
		self:setBehavior(RoamingBehavior.new())
		self.lastBehaviorSwitchTime = currentTime
	end
end

function RangedHostile:findNearestPlayer()
	local nearestPlayer = nil
	local nearestDistance = math.huge

	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character.PrimaryPart and player.Character:FindFirstChild(
			"Humanoid"
		) then
			if player.Character.Humanoid.Health > 0 then
				local distance =
					(player.Character.PrimaryPart.Position - self.model.PrimaryPart.Position).Magnitude
				if distance < nearestDistance and distance <= self.detectionRange then
					nearestPlayer = player
					nearestDistance = distance
				end
			end
		end
	end

	return nearestPlayer
end


function RangedHostile:getOptimalRange()
	return self.optimalRange
end

function RangedHostile:getMaxRange()
	return self.maxRange
end

function RangedHostile:getWeaponName()
	return self.weaponName
end

function RangedHostile:setupAnimations()
	local humanoid = self.model:FindFirstChild("Humanoid")
	if not humanoid then
		warn("[RangedHostile] No Humanoid found for animations:", self.creatureType)
		return
	end

	local config = AIConfig.CreatureTypes[self.creatureType] or {}
	
	if config.AnimationId then
		local animationObject = Instance.new("Animation")
		animationObject.AnimationId = config.AnimationId
		
		local track = humanoid:LoadAnimation(animationObject)
		track.Priority = Enum.AnimationPriority.Action
		self.animationTracks.detect = track
		self.animationTracks.attack = track
		
		if AIConfig.Debug.LogBehaviorChanges then
			print("[RangedHostile] Loaded animation from config (" .. config.AnimationId .. ") for", self.creatureType)
		end
		return
	end

	local animationsFolder = self.model:FindFirstChild("Animations")
	if animationsFolder then
		local singleAnim = animationsFolder:FindFirstChild("Attack") or 
						   animationsFolder:FindFirstChild("Shoot") or
						   animationsFolder:FindFirstChild("Detect") or 
						   animationsFolder:FindFirstChild("Alert")
		
		if singleAnim and singleAnim:IsA("Animation") then
			local track = humanoid:LoadAnimation(singleAnim)
			track.Priority = Enum.AnimationPriority.Action
			self.animationTracks.detect = track
			self.animationTracks.attack = track
			if AIConfig.Debug.LogBehaviorChanges then
				print("[RangedHostile] Loaded single animation (" .. singleAnim.Name .. ") from model for", self.creatureType)
			end
		else
			if AIConfig.Debug.LogBehaviorChanges then
				warn("[RangedHostile] No animation found for", self.creatureType)
			end
		end
	else
		if AIConfig.Debug.LogBehaviorChanges then
			warn("[RangedHostile] No animation source found for", self.creatureType)
		end
	end
end

function RangedHostile:playAnimation(animName, shouldLoop, fadeTime)
	local track = self.animationTracks[animName]
	if track then
		if shouldLoop then
			track.Looped = true
		end
		track:Play(fadeTime or 0.1)
		return track
	else
		if AIConfig.Debug.LogBehaviorChanges then
			print("[RangedHostile] Animation not found:", animName, "for", self.creatureType)
		end
	end
end

function RangedHostile:stopAnimation(animName, fadeTime)
	local track = self.animationTracks[animName]
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.1)
	end
end

function RangedHostile:disconnectTouchDamage()
	if self.touchConnections then
		for _, connection in pairs(self.touchConnections) do
			connection:Disconnect()
		end
		self.touchConnections = {}
	end
end

function RangedHostile:destroy()
	self:cleanupLookAtSystem()
	self:resetBurst()
	self.currentTarget = nil
	HostileCreature.destroy(self)
end

-- Burst Shooting System
function RangedHostile:updateConstantShooting()
	if not self.currentTarget then
		self:resetBurst()
		return
	end
	
	local currentTime = os.clock()
	
	if self.isInCooldown then
		if currentTime - self.lastBurstEndTime >= self.burstCooldown then
            self:startNewBurst()
		else
			return
		end
	end
	
	if currentTime - self.lastShotTime < self.shotInterval then
		return
	end
	
	if not (self.currentTarget.Character and self.currentTarget.Character.PrimaryPart) then
		return
	end
	
	local targetPosition = self.currentTarget.Character.PrimaryPart.Position
	
	if not self:checkLineOfSight(targetPosition) then
		return
	end
	
	-- Fire projectile
	self:fireProjectile(targetPosition)
	self.lastShotTime = currentTime
	self.shotsInCurrentBurst = self.shotsInCurrentBurst + 1
	
	if AIConfig.Debug.LogBehaviorChanges then
		print("[RangedHostile] " .. self.creatureType .. " fired shot " .. self.shotsInCurrentBurst .. "/" .. self.maxShotsPerBurst)
	end
	
	-- Check if burst is complete
	if self.shotsInCurrentBurst >= self.maxShotsPerBurst then
		self:startCooldown(currentTime)
	end
end

function RangedHostile:startNewBurst()
    self.shotsInCurrentBurst = 0
    self.isInCooldown = false
    -- Set lastShotTime so the first shot can fire immediately
    self.lastShotTime = os.clock() - self.shotInterval

    if AIConfig.Debug.LogBehaviorChanges then
        print("[RangedHostile] " .. self.creatureType .. " starting new burst")
    end
end

function RangedHostile:startCooldown(currentTime)
	self.isInCooldown = true
	self.lastBurstEndTime = currentTime
	
	if AIConfig.Debug.LogBehaviorChanges then
		print("[RangedHostile] " .. self.creatureType .. " entering 3-second cooldown after " .. self.shotsInCurrentBurst .. " shots")
	end
end

function RangedHostile:resetBurst()
	self.shotsInCurrentBurst = 0
	self.isInCooldown = false
	self.lastShotTime = 0
	self.lastBurstEndTime = 0
end

function RangedHostile:checkLineOfSight(targetPosition)
	local origin = ProjectileService.getMuzzlePosition and ProjectileService.getMuzzlePosition(self) or 
				   (self.model.PrimaryPart.Position + Vector3.new(0, 3.5, 0))
	local ignoreList = {self.model, self.currentTarget.Character}
	
	return ProjectileService.hasLineOfSight(origin, targetPosition, ignoreList)
end

function RangedHostile:fireProjectile(targetPosition)
	local origin = ProjectileService.getMuzzlePosition and ProjectileService.getMuzzlePosition(self) or 
				   (self.model.PrimaryPart.Position + Vector3.new(0, 3.5, 0))
	local weaponName = self.weaponName or "SkeletonArrow"
	local ignoreList = {self.model}
	
	-- Play attack animation if available
	if self.playAnimation then
		self:playAnimation("attack", false, 0.1)
	end
	
	-- Play shooting sound at creature position
	SoundPlayer.playAt("ai.shoot", self.model.PrimaryPart, {
		volume = 0.7,
		rolloff = {
			max = 80,
			min = 15,
			emitter = 10
		}
	})
	
	-- Fire the projectile using ProjectileService
	local result = ProjectileService.fire(origin, targetPosition, weaponName, self, ignoreList)
	
	if AIConfig.Debug.LogBehaviorChanges then
		local targetName = self.currentTarget and self.currentTarget.Name or "Unknown"
		local hitInfo = result and result.hit and "HIT" or "MISS"
		print("[RangedHostile] " .. self.creatureType .. " fired at " .. targetName .. " - " .. hitInfo)
	end
end

-- Look-At System Implementation (AlignOrientation-based)
function RangedHostile:setupLookAtSystem()
	local root = self.model:FindFirstChild("HumanoidRootPart")
	if not root then
		if AIConfig.Debug.LogBehaviorChanges then
			warn("[RangedHostile] Look-at setup failed - no HumanoidRootPart for", self.creatureType)
		end
		return
	end
	
	-- Create AlignOrientation constraint
	self.alignOrientation = Instance.new("AlignOrientation")
	self.alignOrientation.Name = "BodyLookAt"
	self.alignOrientation.RigidityEnabled = true  -- instant turn; set false for smooth
	self.alignOrientation.Responsiveness = 50     -- higher = snappier
	self.alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	self.alignOrientation.Parent = root
	
	-- Create attachment
	self.lookAtAttachment = Instance.new("Attachment")
	self.lookAtAttachment.Parent = root
	self.alignOrientation.Attachment0 = self.lookAtAttachment
	
	-- Start disabled
	self.alignOrientation.Enabled = false
	
	if AIConfig.Debug.LogBehaviorChanges then
		print("[RangedHostile] AlignOrientation look-at system setup complete for", self.creatureType)
	end
end

function RangedHostile:enableLookAt()
	if self.alignOrientation then
		self.lookAtEnabled = true
		self.alignOrientation.Enabled = true
		
		if AIConfig.Debug.LogBehaviorChanges then
			print("[RangedHostile] Look-at enabled for", self.creatureType)
		end
	end
end

function RangedHostile:disableLookAt()
	if self.alignOrientation then
		self.lookAtEnabled = false
		self.alignOrientation.Enabled = false
		
		if AIConfig.Debug.LogBehaviorChanges then
			print("[RangedHostile] Look-at disabled for", self.creatureType)
		end
	end
end

function RangedHostile:updateLookAtSystem()
	if not self.lookAtEnabled or not self.alignOrientation or not self.currentTarget then
		return
	end
	
	-- Validate target is still valid
	if not (self.currentTarget.Character and self.currentTarget.Character.PrimaryPart) then
		self:disableLookAt()
		return
	end
	
	local root = self.model:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	local targetPart = self.currentTarget.Character.PrimaryPart
	
	-- Face the player only on the horizontal plane (keep current Y)
	local fromPos = root.Position
	local toPos = Vector3.new(targetPart.Position.X, fromPos.Y, targetPart.Position.Z)
	self.alignOrientation.CFrame = CFrame.lookAt(fromPos, toPos)
end

function RangedHostile:cleanupLookAtSystem()
	-- Destroy AlignOrientation constraint
	if self.alignOrientation then
		self.alignOrientation:Destroy()
		self.alignOrientation = nil
	end
	
	-- Destroy attachment
	if self.lookAtAttachment then
		self.lookAtAttachment:Destroy()
		self.lookAtAttachment = nil
	end
	
	-- Reset properties
	self.lookAtEnabled = false
end

return RangedHostile
