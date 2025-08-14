-- src/server/ai/creatures/HostileCreature.lua
-- Simple hostile creature AI - chases players and deals touch damage
-- Uses behavior system for state management

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local BaseCreature = require(script.Parent.Base)
local AIConfig = require(ReplicatedStorage.Shared.config.ai.AIConfig)

local RoamingBehavior = require(script.Parent.Parent.behaviors.Roaming)
local ChasingBehavior = require(script.Parent.Parent.behaviors.Chasing)

local HostileCreature = setmetatable({}, { __index = BaseCreature })
HostileCreature.__index = HostileCreature

function HostileCreature.new(model, creatureType, spawnPosition)
	local self =
		setmetatable(
			BaseCreature.new(model, creatureType, spawnPosition),
			HostileCreature
		)
	local config = AIConfig.CreatureTypes[creatureType] or {}
	self.touchDamage = config.TouchDamage or 15
	self.chaseSpeed = config.ChaseSpeed or 22
	self.damageCooldown = config.DamageCooldown or 1.5

	self.lastDamageTime = {}
	self.touchConnections = {}

	self:setupTouchDamage()
	-- Ensure touch damage stops immediately on death/ragdoll
	local humanoid = model:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			self:disconnectTouchDamage()
		end)
	end
	self:setBehavior(RoamingBehavior.new())

	return self
end

function HostileCreature:update(deltaTime)
	BaseCreature.update(self, deltaTime)
end

function HostileCreature:setupTouchDamage()
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
	-- Do not deal damage if this creature is dead or ragdolled
	if self.isDead or (self.model and self.model:GetAttribute("Ragdolled")) then return end
	local myHumanoid = self.model and self.model:FindFirstChild("Humanoid")
	if not myHumanoid or myHumanoid.Health <= 0 then return end

	local character = hit.Parent
	if not character then return end
	local humanoid = character:FindFirstChild("Humanoid")
	local player = Players:GetPlayerFromCharacter(character)

	if not player or not humanoid or humanoid.Health <= 0 then return end

	local currentTime = os.clock()
	if self.lastDamageTime[player.UserId] and currentTime - self.lastDamageTime[player.UserId] < self.damageCooldown then return end

	if self.touchDamage and self.touchDamage > 0 then
		humanoid:TakeDamage(self.touchDamage)
		self.lastDamageTime[player.UserId] = currentTime
		if AIConfig.Debug.LogBehaviorChanges then
			print("[HostileCreature] " .. self.creatureType .. " dealt " .. self.touchDamage .. " damage to " .. player.Name)
		end
	end
end

function HostileCreature:disconnectTouchDamage()
	if self.touchConnections then
		for _, connection in pairs(self.touchConnections) do
			connection:Disconnect()
		end
		self.touchConnections = {}
	end
end

function HostileCreature:destroy()
	self:disconnectTouchDamage()
	BaseCreature.destroy(self)
end

return HostileCreature
