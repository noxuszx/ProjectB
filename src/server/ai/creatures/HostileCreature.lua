-- src/server/ai/creatures/HostileCreature.lua
-- Simple hostile creature AI - chases players and deals touch damage
-- Uses behavior system for state management

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local BaseCreature = require(script.Parent.BaseCreature)
local AIConfig = require(ReplicatedStorage.Shared.config.AIConfig)

-- Import behavior classes
local RoamingBehavior = require(script.Parent.Parent.behaviors.RoamingBehavior)
local ChasingBehavior = require(script.Parent.Parent.behaviors.ChasingBehavior)

local HostileCreature = setmetatable({}, {__index = BaseCreature})
HostileCreature.__index = HostileCreature

function HostileCreature.new(model, creatureType, spawnPosition)
	local self = setmetatable(BaseCreature.new(model, creatureType, spawnPosition), HostileCreature)

	-- Hostile creature specific properties
	local config = AIConfig.CreatureTypes[creatureType] or {}
	self.touchDamage = config.TouchDamage or 15
	self.chaseSpeed = config.ChaseSpeed or 22
	self.damageCooldown = config.DamageCooldown or 1.5

	-- Touch damage tracking
	self.lastDamageTime = {} -- Track damage cooldown per player
	self.touchConnections = {}

	-- Set up touch damage
	self:setupTouchDamage()

	-- Start with roaming behavior
	self:setBehavior(RoamingBehavior.new())

	return self
end

function HostileCreature:update(deltaTime)
	-- Call parent update (which handles behavior updates)
	BaseCreature.update(self, deltaTime)
end



function HostileCreature:setupTouchDamage()
	-- Set up touch damage on creature parts
	for _, part in pairs(self.model:GetChildren()) do
		if part:IsA("BasePart") then
			local connection = part.Touched:Connect(function(hit)
				self:onTouch(hit)
			end)
			table.insert(self.touchConnections, connection)
		end
	end
end

function HostileCreature:onTouch(hit)
	local character = hit.Parent
	local humanoid = character:FindFirstChild("Humanoid")
	local player = Players:GetPlayerFromCharacter(character)
	
	if not player or not humanoid then
		return
	end
	
	-- Check damage cooldown
	local currentTime = tick()
	if self.lastDamageTime[player.UserId] and 
	   currentTime - self.lastDamageTime[player.UserId] < self.damageCooldown then
		return
	end
	
	-- Deal damage
	humanoid:TakeDamage(self.touchDamage)
	self.lastDamageTime[player.UserId] = currentTime
	
	if AIConfig.Debug.LogBehaviorChanges then
		print("[HostileCreature] " .. self.creatureType .. " dealt " .. self.touchDamage .. " damage to " .. player.Name)
	end
end



function HostileCreature:destroy()
	-- Clean up touch connections
	for _, connection in pairs(self.touchConnections) do
		connection:Disconnect()
	end
	self.touchConnections = {}
	
	-- Call parent destroy
	BaseCreature.destroy(self)
end

return HostileCreature
