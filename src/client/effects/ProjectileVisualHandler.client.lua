-- src/client/effects/ProjectileVisualHandler.client.lua
-- Client-side projectile visual effects
-- Listens to ProjectileVisual RemoteEvent and creates tracer effects

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.Shared.config.WeaponConfig)

local ProjectileVisualHandler = {}

-- Cache for performance
local projectileVisualRemote = nil
local activeTracers = {}

-- Initialize remote connection
local function initializeRemote()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotesFolder then
		warn("[ProjectileVisualHandler] Remotes folder not found")
		return
	end

	projectileVisualRemote = remotesFolder:WaitForChild("ProjectileVisual", 10)
	if not projectileVisualRemote then
		warn("[ProjectileVisualHandler] ProjectileVisual remote not found")
		return
	end

	projectileVisualRemote.OnClientEvent:Connect(onProjectileVisual)
end

-- Create simple toolbox-style tracer like crossbow
local function createProjectileTracer(visualPayload)
	local origin = visualPayload.origin
	local hitPosition = visualPayload.hitPosition
	local weaponName = visualPayload.weaponName

	-- Get weapon visual configuration for color/material
	local weaponConfig = WeaponConfig.getRangedWeaponConfig(weaponName)
	local bulletConfig = weaponConfig and weaponConfig.BulletConfig

	-- Create simple beam tracer (like crossbow)
	local beam = Instance.new("Part")
	beam.Name = "ProjectileTracer_" .. weaponName
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Locked = true

	-- Use weapon config colors if available, otherwise default
	if bulletConfig then
		beam.Color = bulletConfig.Color or Color3.new(0.6, 0.4, 0.2)
		beam.Material = bulletConfig.Material or Enum.Material.Wood
	else
		beam.Color = Color3.new(0.6, 0.4, 0.2) -- Brown arrow color
		beam.Material = Enum.Material.Wood
	end

	beam.Transparency = 0
	beam.FormFactor = Enum.FormFactor.Custom

	-- Calculate beam size and position (like crossbow)
	local distance = (hitPosition - origin).Magnitude
	beam.Size = Vector3.new(0.1, 0.1, distance)
	beam.CFrame = CFrame.new(origin, hitPosition) * CFrame.new(0, 0, -distance / 2)

	beam.Parent = workspace

	-- Very short lifetime like crossbow (0.05 seconds)
	Debris:AddItem(beam, 0.05)

	-- Track for cleanup
	table.insert(activeTracers, beam)
end

-- Create impact effect at hit position
local function createImpactEffect(visualPayload)
	local hitPosition = visualPayload.hitPosition
	local hitInstance = visualPayload.hitInstance

	if not hitPosition then
		return
	end

	-- Simple spark effect
	local spark = Instance.new("Part")
	spark.Name = "ImpactSpark"
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.CanTouch = false
	spark.Size = Vector3.new(0.5, 0.5, 0.5)
	spark.Material = Enum.Material.Neon
	spark.Color = Color3.new(1, 0.8, 0.4) -- Orange spark
	spark.Shape = Enum.PartType.Ball
	spark.CFrame = CFrame.new(hitPosition)
	spark.Parent = workspace

	-- Quick flash effect
	local flashTween = TweenService:Create(spark, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(0.1, 0.1, 0.1),
	})

	flashTween:Play()
	flashTween.Completed:Connect(function()
		if spark and spark.Parent then
			spark:Destroy()
		end
	end)

	-- Safety cleanup
	Debris:AddItem(spark, 1)
end

-- Handle incoming projectile visual events
function onProjectileVisual(visualPayload)
	if not visualPayload or not visualPayload.origin or not visualPayload.hitPosition then
		warn("[ProjectileVisualHandler] Invalid visual payload received")
		return
	end

	-- Create tracer effect
	createProjectileTracer(visualPayload)

	-- Create impact effect if we hit something
	if visualPayload.hitInstance then
		createImpactEffect(visualPayload)
	end
end

-- Cleanup function for when player leaves
local function cleanup()
	for _, tracer in ipairs(activeTracers) do
		if tracer and tracer.Parent then
			tracer:Destroy()
		end
	end
	activeTracers = {}
end

-- Initialize on client startup
RunService.Heartbeat:Wait() -- Wait one frame
initializeRemote()

-- Cleanup on shutdown
game.Players.LocalPlayer.AncestryChanged:Connect(function()
	if not game.Players.LocalPlayer.Parent then
		cleanup()
	end
end)

return ProjectileVisualHandler
