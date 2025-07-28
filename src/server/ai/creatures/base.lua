-- src/server/ai/creatures/BaseCreature.lua
-- Abstract base class for all AI creatures
-- Provides common functionality and interface

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local AIConfig = require(ReplicatedStorage.Shared.config.ai.ai)
local RagdollModule = require(ReplicatedStorage.Shared.modules.RagdollModule)
local FoodDropSystem = require(script.Parent.Parent.Parent.loot.FoodDropSystem)

local BaseCreature = {}
BaseCreature.__index = BaseCreature

-- Abstract base class - should not be instantiated directly
function BaseCreature.new(model, creatureType, spawnPosition)
	local self = setmetatable({}, BaseCreature)

	-- BULLETPROOF model and PrimaryPart validation
	if not model then
		error("[BaseCreature] No model provided for creature type: " .. (creatureType or "unknown"))
	end

	-- Store original model info for debugging
	local originalParts = {}
	for _, child in pairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(originalParts, child.Name)
		end
	end
	
	-- Debug: Creating creature (removed spam)

	-- ALWAYS ensure PrimaryPart is set correctly (even if it exists, it might be invalid)
	local function ensurePrimaryPart()
		local candidates = {"HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "Head", "Root"}

		-- Try standard creature parts first
		for _, partName in ipairs(candidates) do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") and part.Parent then
				model.PrimaryPart = part
				return true, partName
			end
		end

		for _, child in pairs(model:GetChildren()) do
			if child:IsA("BasePart") and child.Parent then
				model.PrimaryPart = child
				return true, child.Name
			end
		end

		for _, descendant in pairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Parent then
				model.PrimaryPart = descendant
				return true, descendant.Name
			end
		end

		return false, nil
	end

	local success, partName = ensurePrimaryPart()
	if not success then
		error("[BaseCreature] CRITICAL: No valid BaseParts found in model for creature type: " .. (creatureType or "unknown"))
	end

	-- Debug: PrimaryPart set (removed spam)

	if not model.PrimaryPart or not model.PrimaryPart.Parent then
		error("[BaseCreature] PrimaryPart validation failed for creature type: " .. (creatureType or "unknown"))
	end

	-- Core properties
	self.model = model
	self.creatureType = creatureType
	self.spawnPosition = spawnPosition or model.PrimaryPart.Position
	self.position = model.PrimaryPart.Position
	
	local config = AIConfig.CreatureTypes[creatureType]
	if not config then
		warn("[BaseCreature] No config found for creature type: " .. creatureType)
		config = {}
	end
	
	self.health = config.Health or 100
	self.maxHealth = self.health
	self.moveSpeed = config.MoveSpeed or 16
	self.detectionRange = config.DetectionRange or 20
	self.currentBehavior = nil
	self.isActive = true
	self.lastUpdateTime = tick()
	self.isDead = false


	-- Prevent Roblox auto-cleanup of character parts
	self:setupCharacterProtection()

	-- Setup death event handling
	self:setupDeathHandling()

	return self
end

function BaseCreature:update(deltaTime)
	if not self.isActive or not self.model or not self.model.Parent then
		return
	end

	if not self.model.PrimaryPart then
		print("[BaseCreature] Destroying", self.creatureType, "due to missing PrimaryPart")
		self:destroy()
		return
	end

	if self.currentBehavior then
		self.currentBehavior:update(self, deltaTime)
	end

	-- Update position
	self.position = self.model.PrimaryPart.Position
	self.lastUpdateTime = tick()
end

function BaseCreature:setBehavior(newBehavior)
	if self.currentBehavior then
		self.currentBehavior:exit(self)
	end
	
	self.currentBehavior = newBehavior
	if newBehavior then
		newBehavior:enter(self)
	end
end

function BaseCreature:takeDamage(amount)
	if self.isDead then return end
	
	self.health = math.max(0, self.health - amount)
	
	-- Update Humanoid health to match creature health
	local humanoid = self.model:FindFirstChild("Humanoid")
	if humanoid then
		local healthPercentage = self.health / self.maxHealth
		humanoid.Health = humanoid.MaxHealth * healthPercentage
	end
	
	if self.health <= 0 then
		self:die()
	end
end

function BaseCreature:getDistanceToPlayer()
	local nearestDistance = math.huge
	local creaturePosition = self.model.PrimaryPart.Position
	
	for _, player in pairs(game.Players:GetPlayers()) do
		if player.Character and player.Character.PrimaryPart then
			local distance = (player.Character.PrimaryPart.Position - creaturePosition).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
			end
		end
	end
	
	return nearestDistance
end

function BaseCreature:destroy()
	self.isActive = false
	
	if self.currentBehavior then
		self.currentBehavior:exit(self)
		self.currentBehavior = nil
	end
	
	
	if self.model and self.model.Parent then
		-- Use Debris service to defer destruction to next frame, preventing lag spikes
		Debris:AddItem(self.model, 0)
	end
end

function BaseCreature:setupCharacterProtection()
	local humanoid = self.model:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	-- Prevent Roblox from auto-cleaning up character parts
	humanoid.BreakJointsOnDeath = false
	
	-- Additional protection settings
	humanoid.RequiresNeck = false  -- Don't break if neck is missing
	
	print("[BaseCreature] Protected", self.creatureType, "from Roblox character cleanup")
end

function BaseCreature:setupDeathHandling()
	local humanoid = self.model:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	-- Connect to Humanoid.Died event
	humanoid.Died:Connect(function()
		if not self.isDead then
			self:die()
		end
	end)
end

function BaseCreature:die()
	if self.isDead then return end
	
	self.isDead = true
	self.isActive = false
	
	print("[BaseCreature]", self.creatureType, "is dying")
	
	-- Stop current behavior
	if self.currentBehavior then
		self.currentBehavior:exit(self)
		self.currentBehavior = nil
	end
	
	-- Handle death based on creature type
	local config = AIConfig.CreatureTypes[self.creatureType]
	if self:shouldRagdoll() then
		-- Ragdoll for humanoid creatures
		print("[BaseCreature] Ragdolling", self.creatureType)
		local success = RagdollModule.PermanentNpcRagdoll(self.model)
		if success then
			-- Keep model in world as ragdoll, don't destroy
			return
		else
			warn("[BaseCreature] Ragdoll failed for", self.creatureType, "- destroying normally")
		end
	else
		-- Simple death for animals - destroy and drop food
		print("[BaseCreature] Simple death for", self.creatureType)
		local deathPosition = self.model.PrimaryPart.Position
		
		-- Drop food before destroying
		local success = FoodDropSystem.dropFood(self.creatureType, deathPosition)
		if success then
			print("[BaseCreature] Dropped food for", self.creatureType)
		else
			print("[BaseCreature] No food drop for", self.creatureType)
		end
	end
	
	-- Fallback: destroy the model if ragdoll failed or not applicable
	self:destroy()
end

function BaseCreature:shouldRagdoll()
	-- Ragdoll humanoid creatures: Villager1, Villager2, Mummy, Skeleton
	local ragdollCreatures = {
		["Villager1"] = true,
		["Villager2"] = true,
		["Mummy"] = true,
		["Skeleton"] = true,
	}
	
	return ragdollCreatures[self.creatureType] == true
end

function BaseCreature:shouldHaveAnimations()
	-- Same creatures that can ragdoll should have animations (humanoid creatures)
	return self:shouldRagdoll()
end



function BaseCreature:setupHealthDisplay()
	local humanoid = self.model:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	-- Hide nametags but allow health bars
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	-- Or use: Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
end

return BaseCreature
