-- src/server/ai/creatures/BaseCreature.lua
-- Abstract base class for all AI creatures
-- Provides common functionality and interface

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Debris 			  = game:GetService("Debris")

local AIConfig			  = require(ReplicatedStorage.Shared.config.ai.AIConfig)
local RagdollModule 	  = require(ReplicatedStorage.Shared.modules.RagdollModule)
local FoodDropSystem 	  = require(script.Parent.Parent.Parent.loot.FoodDropSystem)
local CreaturePoolManager = require(script.Parent.Parent.CreaturePoolManager)
local CS_tags 			  = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local BaseCreature = {}
BaseCreature.__index = BaseCreature

local function getUpdateCreatureHealthRemote()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	local updateCreatureHealthRemote =
		remotesFolder:FindFirstChild("UpdateCreatureHealth")
	if not updateCreatureHealthRemote then
		updateCreatureHealthRemote = Instance.new("RemoteEvent")
		updateCreatureHealthRemote.Name = "UpdateCreatureHealth"
		updateCreatureHealthRemote.Parent = remotesFolder
	end

	return updateCreatureHealthRemote
end



function BaseCreature.new(model, creatureType, spawnPosition)
	local self = setmetatable({}, BaseCreature)

	if not model then
		error(
			"[BaseCreature] No model provided for creature type: " .. (creatureType or "unknown")
		)
	end

	local originalParts = {}
	for _, child in pairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(originalParts, child.Name)
		end
	end

	local function ensurePrimaryPart()
		local candidates =
			{
				"HumanoidRootPart",
				"Torso",
				"UpperTorso",
				"LowerTorso",
				"Head",
				"Root",
			}
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
		error(
			"[BaseCreature] CRITICAL: No valid BaseParts found in model for creature type: " .. (creatureType or "unknown")
		)
	end

	if not model.PrimaryPart or not model.PrimaryPart.Parent then
		error(
			"[BaseCreature] PrimaryPart validation failed for creature type: " .. (creatureType or "unknown")
		)
	end

	self.model = model
	self.creatureType = creatureType
	self.spawnPosition = spawnPosition or model.PrimaryPart.Position
	self.position = model.PrimaryPart.Position

	local config = AIConfig.CreatureTypes[creatureType]
	if not config then
		warn(
			"[BaseCreature] No config found for creature type: " .. creatureType
		)
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

	self:setupCharacterProtection()
	self:setupDeathHandling()
	self:setupHealthDisplay()
	self:setupDebugGUI()

	if self.health < self.maxHealth then
		self:sendHealthUpdate()
	end

	return self
end


function BaseCreature:update(deltaTime)
	if not self.isActive or not self.model or not self.model.Parent then return end

	if not self.model.PrimaryPart then
		print(
			"[BaseCreature] Destroying",
			self.creatureType,
			"due to missing PrimaryPart"
		)
		self:destroy()
		return
	end

	if self.currentBehavior and self.currentBehavior.followUp then
		self.currentBehavior:followUp(self, deltaTime)
	end

	if self.currentBehavior then
		self.currentBehavior:update(self, deltaTime)
	end

	self.position = self.model.PrimaryPart.Position
	self.lastUpdateTime = os.clock()
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

	local humanoid = self.model:FindFirstChild("Humanoid")
	if humanoid then
		local healthPercentage = self.health / self.maxHealth
		humanoid.Health = humanoid.MaxHealth * healthPercentage
	end

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
			local distance =
				(player.Character.PrimaryPart.Position - creaturePosition).Magnitude
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

	self:destroyDebugGUI()

	if self.model and self.model.Parent then
		Debris:AddItem(self.model, 0)
	end
end

function BaseCreature:setupCharacterProtection()
	local humanoid = self.model:FindFirstChild("Humanoid")
	if not humanoid then return end
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
end

function BaseCreature:setupDeathHandling()
	local humanoid = self.model:FindFirstChild("Humanoid")
	if not humanoid then return end

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

	self.health = 0
	self:sendHealthUpdate()

	-- Stop current behavior
	if self.currentBehavior then
		self.currentBehavior:exit(self)
		self.currentBehavior = nil
	end

	local config = AIConfig.CreatureTypes[self.creatureType]
	
	if self:shouldRagdoll() then
		print("[BaseCreature] Ragdolling", self.creatureType)
		local success = RagdollModule.PermanentNpcRagdoll(self.model)
		if success then
			
			CS_tags.addTag(self.model, CS_tags.STORABLE)
			CS_tags.addTag(self.model, CS_tags.DRAGGABLE)
			print(
				"[BaseCreature] Made ragdolled",
				self.creatureType,
				"storable"
			)
			return
		else
			warn(
				"[BaseCreature] Ragdoll failed for",
				self.creatureType,
				"- destroying normally"
			)
		end
	else
		print("[BaseCreature] Simple death for", self.creatureType)
		local deathPosition = self.model.PrimaryPart.Position
		local success =
			FoodDropSystem.dropFood(
				self.creatureType,
				deathPosition,
				self.model
			)
		if success then
			print("[BaseCreature] Dropped food for", self.creatureType)
		else
			print("[BaseCreature] No food drop for", self.creatureType)
		end

		if CreaturePoolManager.isPooledCreature(self.creatureType) then
			local poolSuccess =
				CreaturePoolManager.poolCreature(self.model, self.creatureType)
			if poolSuccess then
				print(
					"[BaseCreature] Pooled",
					self.creatureType,
					"instead of destroying"
				)
				print(
					"[BaseCreature] Total die() for",
					self.creatureType,
					"took:",
					(os.clock() - totalStart) * 1000,
					"ms"
				)
				return
			else
				warn(
					"[BaseCreature] Failed to pool",
					self.creatureType,
					"- falling back to destroy"
				)
			end
		end
	end

	-- Fallback: destroy the model if ragdoll failed, not pooled, or pooling failed
	local destroyStart = os.clock()
	self:destroy()
	print(
		"[BaseCreature] Model destruction took:",
		(os.clock() - destroyStart) * 1000,
		"ms"
	)

	print(
		"[BaseCreature] Total die() for",
		self.creatureType,
		"took:",
		(os.clock() - totalStart) * 1000,
		"ms"
	)
end

function BaseCreature:shouldRagdoll()
	-- Ragdoll humanoid creatures: Villager1, Villager2, Mummy, Skeleton
	local ragdollCreatures = {
		Villager1 = true,
		Villager2 = true,
		Villager3 = true,
		Villager4 = true,
		TowerMummy = true,
		TowerSkeleton = true,
		EgyptianSkeleton = true,
		EgyptianSkeleton2 = true,
		Mummy = true,
		SkeletonArcher = true,

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

	-- Hide default Roblox UI elements completely (we have custom health bars)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0
end

-- ============================================
-- DEBUG VISUALIZATION FUNCTIONS
-- ============================================

function BaseCreature:setupDebugGUI()
	if not AIConfig.Debug.ShowStateLabels then return end

	if not self.model or not self.model.PrimaryPart then return end

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "CreatureDebugGUI"
	billboardGui.Size = UDim2.new(3, 0, 1, 0)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.Parent = self.model.PrimaryPart

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
	if not AIConfig.Debug.ShowStateLabels or not self.debugGUI then return end

	local lodLabel = self.debugGUI:FindFirstChild("LODLabel")
	local stateLabel = self.debugGUI:FindFirstChild("StateLabel")
	local rateLabel = self.debugGUI:FindFirstChild("RateLabel")

	if lodLabel then
		local lodLevel = self.lodLevel or "Unknown"
		local lodRate = self.lodUpdateRate or 0
		lodLabel.Text = "LOD: " .. lodLevel
		if lodLevel == "Close" then
			lodLabel.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
		elseif lodLevel == "Medium" then
			lodLabel.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
		elseif lodLevel == "Far" then
			lodLabel.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		else
			lodLabel.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		end
	end

	if stateLabel then
		local stateName = "Idle"
		if self.currentBehavior then
			if self.currentBehavior.behaviorName then
				stateName = self.currentBehavior.behaviorName

				if self.currentBehavior.state then
					stateName = stateName .. ":" .. self.currentBehavior.state
				end
			end
		end
		stateLabel.Text = "State: " .. stateName
	end

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
