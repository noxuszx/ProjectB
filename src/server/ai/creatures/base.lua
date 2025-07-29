-- src/server/ai/creatures/BaseCreature.lua
-- Abstract base class for all AI creatures
-- Provides common functionality and interface

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local AIConfig = require(ReplicatedStorage.Shared.config.ai.ai)
local RagdollModule = require(ReplicatedStorage.Shared.modules.RagdollModule)
local FoodDropSystem = require(script.Parent.Parent.Parent.loot.FoodDropSystem)
local CreaturePoolManager = require(script.Parent.Parent.CreaturePoolManager)

-- Get RemoteEvent for health updates (will be created if it doesn't exist)
local function getUpdateCreatureHealthRemote()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end
	
	local updateCreatureHealthRemote = remotesFolder:FindFirstChild("UpdateCreatureHealth")
	if not updateCreatureHealthRemote then
		updateCreatureHealthRemote = Instance.new("RemoteEvent")
		updateCreatureHealthRemote.Name = "UpdateCreatureHealth"
		updateCreatureHealthRemote.Parent = remotesFolder
	end
	
	return updateCreatureHealthRemote
end

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
	self.lastUpdateTime = os.clock()
	self.isDead = false


	-- Prevent Roblox auto-cleanup of character parts
	self:setupCharacterProtection()

	-- Setup death event handling
	self:setupDeathHandling()
	
	-- Setup debug GUI if enabled
	self:setupDebugGUI()
	
	-- Send initial health to clients (in case creature spawns damaged)
	if self.health < self.maxHealth then
		self:sendHealthUpdate()
	end

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
	self.lastUpdateTime = os.clock()
	
	-- Update debug GUI if enabled
	self:updateDebugGUI()
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

function BaseCreature:sendHealthUpdate()
	local updateRemote = getUpdateCreatureHealthRemote()
	if updateRemote then
		updateRemote:FireAllClients(self.model, self.health, self.maxHealth)
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
	
	-- Send health update to all clients for health bar display
	self:sendHealthUpdate()
	
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
	
	-- Clean up debug GUI
	self:destroyDebugGUI()
	
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
	
	-- Debug: Protected from Roblox character cleanup (removed spam)
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
	
	local totalStart = os.clock()
	
	self.isDead = true
	self.isActive = false
	
	print("[BaseCreature]", self.creatureType, "is dying")
	
	-- Send health update to remove health bars before destruction
	self.health = 0
	self:sendHealthUpdate()
	
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
		-- Simple death for animals - pool or destroy and drop food
		print("[BaseCreature] Simple death for", self.creatureType)
		local deathPosition = self.model.PrimaryPart.Position
		
		-- Drop food before pooling/destroying
		local success = FoodDropSystem.dropFood(self.creatureType, deathPosition, self.model)
		if success then
			print("[BaseCreature] Dropped food for", self.creatureType)
		else
			print("[BaseCreature] No food drop for", self.creatureType)
		end
		
		-- Try to pool creature instead of destroying
		if CreaturePoolManager.isPooledCreature(self.creatureType) then
			local poolSuccess = CreaturePoolManager.poolCreature(self.model, self.creatureType)
			if poolSuccess then
				print("[BaseCreature] Pooled", self.creatureType, "instead of destroying")
				-- Don't call destroy() - creature is now pooled
				print("[BaseCreature] Total die() for", self.creatureType, "took:", (os.clock() - totalStart) * 1000, "ms")
				return
			else
				warn("[BaseCreature] Failed to pool", self.creatureType, "- falling back to destroy")
			end
		end
	end
	
	-- Fallback: destroy the model if ragdoll failed, not pooled, or pooling failed
	local destroyStart = os.clock()
	self:destroy()
	print("[BaseCreature] Model destruction took:", (os.clock() - destroyStart) * 1000, "ms")
	
	print("[BaseCreature] Total die() for", self.creatureType, "took:", (os.clock() - totalStart) * 1000, "ms")
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

-- ============================================
-- DEBUG VISUALIZATION FUNCTIONS
-- ============================================

function BaseCreature:setupDebugGUI()
	if not AIConfig.Debug.ShowStateLabels then
		return
	end
	
	if not self.model or not self.model.PrimaryPart then
		return
	end
	
	-- Create BillboardGui for debug info
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "CreatureDebugGUI"
	billboardGui.Size = UDim2.new(3, 0, 1, 0)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.Parent = self.model.PrimaryPart
	
	-- LOD Level Label
	local lodLabel = Instance.new("TextLabel")
	lodLabel.Name = "LODLabel"
	lodLabel.Size = UDim2.new(1, 0, 0.3, 0)
	lodLabel.Position = UDim2.new(0, 0, 0, 0)
	lodLabel.BackgroundTransparency = 0.3
	lodLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	lodLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	lodLabel.TextScaled = true
	lodLabel.Font = Enum.Font.SourceSansBold
	lodLabel.Text = "LOD: Unknown"
	lodLabel.Parent = billboardGui
	
	-- Behavior State Label
	local stateLabel = Instance.new("TextLabel")
	stateLabel.Name = "StateLabel"
	stateLabel.Size = UDim2.new(1, 0, 0.3, 0)
	stateLabel.Position = UDim2.new(0, 0, 0.35, 0)
	stateLabel.BackgroundTransparency = 0.3
	stateLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	stateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	stateLabel.TextScaled = true
	stateLabel.Font = Enum.Font.SourceSans
	stateLabel.Text = "State: Idle"
	stateLabel.Parent = billboardGui
	
	-- Update Rate Label
	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "RateLabel"
	rateLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rateLabel.Position = UDim2.new(0, 0, 0.7, 0)
	rateLabel.BackgroundTransparency = 0.3
	rateLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	rateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.SourceSans
	rateLabel.Text = "Rate: --Hz"
	rateLabel.Parent = billboardGui
	
	self.debugGUI = billboardGui
end

function BaseCreature:updateDebugGUI()
	if not AIConfig.Debug.ShowStateLabels or not self.debugGUI then
		return
	end
	
	local lodLabel = self.debugGUI:FindFirstChild("LODLabel")
	local stateLabel = self.debugGUI:FindFirstChild("StateLabel")
	local rateLabel = self.debugGUI:FindFirstChild("RateLabel")
	
	-- Update LOD level and color
	if lodLabel then
		local lodLevel = self.lodLevel or "Unknown"
		local lodRate = self.lodUpdateRate or 0
		
		lodLabel.Text = "LOD: " .. lodLevel
		
		-- Color code by LOD level
		if lodLevel == "Close" then
			lodLabel.BackgroundColor3 = Color3.fromRGB(0, 150, 0) -- Green
		elseif lodLevel == "Medium" then
			lodLabel.BackgroundColor3 = Color3.fromRGB(255, 165, 0) -- Orange
		elseif lodLevel == "Far" then
			lodLabel.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
		else
			lodLabel.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Gray
		end
	end
	
	-- Update behavior state
	if stateLabel then
		local stateName = "Idle"
		if self.currentBehavior then
			if self.currentBehavior.name then
				stateName = self.currentBehavior.name
				-- Add sub-state for roaming behavior
				if self.currentBehavior.state then
					stateName = stateName .. ":" .. self.currentBehavior.state
				end
			end
		end
		stateLabel.Text = "State: " .. stateName
	end
	
	-- Update rate
	if rateLabel then
		local rate = self.lodUpdateRate or 0
		rateLabel.Text = "Rate: " .. string.format("%.1f", rate) .. "Hz"
	end
end

function BaseCreature:destroyDebugGUI()
	if self.debugGUI then
		self.debugGUI:Destroy()
		self.debugGUI = nil
	end
end

return BaseCreature
