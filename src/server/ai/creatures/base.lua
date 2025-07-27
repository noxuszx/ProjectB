-- src/server/ai/creatures/BaseCreature.lua
-- Abstract base class for all AI creatures
-- Provides common functionality and interface

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIConfig = require(ReplicatedStorage.Shared.config.ai.ai)

local BaseCreature = {}
BaseCreature.__index = BaseCreature

-- Abstract base class - should not be instantiated directly
function BaseCreature.new(model, creatureType, spawnPosition)
	local self = setmetatable({}, BaseCreature)

	-- Safety check for model and PrimaryPart
	if not model or not model.PrimaryPart then
		error("[BaseCreature] Invalid model or missing PrimaryPart for creature type: " .. (creatureType or "unknown"))
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
	
	return self
end

function BaseCreature:update(deltaTime)
	if not self.isActive or not self.model or not self.model.Parent then
		return
	end

	-- Additional safety check for PrimaryPart
	if not self.model.PrimaryPart then
		warn("[BaseCreature] PrimaryPart is missing for " .. self.creatureType)
		return
	end

	if self.currentBehavior then
		self.currentBehavior:update(self, deltaTime)
	end

	-- Update position with safety check (redundant but safe)
	if self.model.PrimaryPart then
		self.position = self.model.PrimaryPart.Position
	end
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
	self.health = math.max(0, self.health - amount)
	
	if self.health <= 0 then
		self:destroy()
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
		self.model:Destroy()
	end
end

return BaseCreature
