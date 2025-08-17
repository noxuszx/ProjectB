--[[
    Spear.client.lua (generic melee script)
    Simplified: magnitude-only selection, no directional/LOS, mobile-friendly
    You can copy this exact script to other melee tools. It reads stats from WeaponConfig by tool.Name.
]]
--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local LocalHitRegistry = require(ReplicatedStorage.Shared.modules.LocalHitRegistry)
local SoundPlayer = require(ReplicatedStorage.Shared.modules.SoundPlayer)

local tool = script.Parent
local player = Players.LocalPlayer

local WeaponConfig = require(ReplicatedStorage.Shared.config.WeaponConfig)
local weaponName = tool.Name
local config = WeaponConfig.getWeaponConfig(weaponName)

local lastAttackTime = 0
local isEquipped = false
local character: Model? = nil
local humanoid: Humanoid? = nil
local weaponRemote: RemoteEvent? = nil

local ATTACK_ANIMATION_ID = "rbxassetid://81865375741678"
local attackTrack: AnimationTrack? = nil
local SWING_SOUND_ID = "rbxassetid://4571259077"
local swingSound: Sound? = nil

local function initRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return
	end
	weaponRemote = remotes:FindFirstChild("WeaponDamage")
end

local function ensureLegacyToolAnim()
	local existing = tool:FindFirstChild("toolanim")
	if existing then
		existing:Destroy()
	end
	local v = Instance.new("StringValue")
	v.Name = "toolanim"
	v.Value = (config and config.Animation) or "Slash"
	v.Parent = tool
end

local function setupAnimation()
	if not character then
		return
	end
	humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if attackTrack then
		attackTrack:Stop()
		attackTrack:Destroy()
		attackTrack = nil
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = ATTACK_ANIMATION_ID
	local ok, track = pcall(function()
		return humanoid:LoadAnimation(anim)
	end)
	if ok and track then
		attackTrack = track
		attackTrack.Priority = Enum.AnimationPriority.Action
	else
		ensureLegacyToolAnim()
	end
end

local function playAttackAnimation()
	if attackTrack then
		if attackTrack.IsPlaying then
			attackTrack:Stop()
		end
		attackTrack:Play()
		if config and config.SwingDuration and attackTrack.Length and attackTrack.Length > 0 then
			local speed = attackTrack.Length / config.SwingDuration
			if speed > 0 then
				attackTrack:AdjustSpeed(speed)
			end
		end
		return
	end
	ensureLegacyToolAnim()
end

local function onCooldown()
	if not config or not config.Cooldown then
		return false
	end
	local now = os.clock()
	return (now - lastAttackTime) < config.Cooldown
end

local function findNearestTargetInRange(originPos: Vector3, range: number)
	local bestModel: Model? = nil
	local bestDist = math.huge

	-- Prefer tagged creatures first
	for _, inst in ipairs(CollectionService:GetTagged("Creature")) do
		local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
		if model and model ~= character and model.PrimaryPart then
			local d = (model.PrimaryPart.Position - originPos).Magnitude
			if d <= range and d < bestDist then
				bestDist = d
				bestModel = model
			end
		end
	end

	-- Fallback: any model with a Humanoid
	if not bestModel then
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("Humanoid") then
				local model = desc.Parent
				if model and model:IsA("Model") and model ~= character and model.PrimaryPart then
					local d = (model.PrimaryPart.Position - originPos).Magnitude
					if d <= range and d < bestDist then
						bestDist = d
						bestModel = model
					end
				end
			end
		end
	end

	return bestModel
end

local function createRangeVisual(originPos: Vector3, range: number)
	local sphere = Instance.new("Part")
	sphere.Name = "MeleeRangeVisual"
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.ForceField
	sphere.Color = Color3.fromRGB(255, 100, 100)
	sphere.Transparency = 0.8
	sphere.Size = Vector3.new(range * 2, range * 2, range * 2)
	sphere.CFrame = CFrame.new(originPos)
	sphere.Parent = workspace
	Debris:AddItem(sphere, 0.25)
end

local function getOrCreateSwingSound()
	if not swingSound then
		swingSound = Instance.new("Sound")
		swingSound.Name = "SwingSound"
		swingSound.SoundId = SWING_SOUND_ID
		swingSound.Volume = 0.6
		swingSound.RollOffMode = Enum.RollOffMode.InverseTapered
		swingSound.Parent = tool
	end
	return swingSound
end

local function executeAttack()
	if onCooldown() then
		return false
	end
	if not character or not character.PrimaryPart then
		return false
	end

	lastAttackTime = os.clock()

	-- Play swing SFX
	local s = getOrCreateSwingSound()
	if s then
		s:Play()
	end

	playAttackAnimation()

	local range = (config and config.Range) or 10

	-- Visualize range if enabled in global config
	local showRange = WeaponConfig
		and WeaponConfig.GlobalSettings
		and WeaponConfig.GlobalSettings.Debug
		and WeaponConfig.GlobalSettings.Debug.ShowMeleeRange
	if showRange then
		createRangeVisual(character.PrimaryPart.Position, range)
	end

	local targetModel = findNearestTargetInRange(character.PrimaryPart.Position, range)

	if targetModel and weaponRemote and config and config.Damage then
		-- Play local hit-confirm immediately
		local parent = targetModel.PrimaryPart or targetModel
		SoundPlayer.playAt("hit_confirm", parent, { volume = 0.5, rolloff = { min = 8, max = 60, emitter = 5 } })
		-- Optional: keep claim for consistency
		LocalHitRegistry.claim(targetModel)
		weaponRemote:FireServer(targetModel, config.Damage)
	end

	return true
end

tool.Equipped:Connect(function()
	isEquipped = true
	character = player.Character
	if not weaponRemote then
		initRemote()
	end
	setupAnimation()

end)

tool.Unequipped:Connect(function()
	isEquipped = false
	character = nil
end)

tool.Activated:Connect(function()
	if not isEquipped then
		return
	end
	executeAttack()
end)

player.CharacterAdded:Connect(function(c)
	if isEquipped then
		character = c
		setupAnimation()
	end
end)
