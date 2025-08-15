-- Footsteps.client.lua
-- Lightweight client-side footsteps using FootstepModule

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local function getCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	if not humanoid.RootPart then
		humanoid:GetPropertyChangedSignal("RootPart"):Wait()
	end
	local root = humanoid.RootPart
	return character, humanoid, root
end

local character, humanoid, root = getCharacter()

-- Require FootstepModule from ReplicatedStorage.Shared.modules
local FootstepModule = require(game:GetService("ReplicatedStorage").Shared.modules.FootstepModule)

-- Single reusable sound instance
local footstep = Instance.new("Sound")
footstep.Name = "Footstep"
footstep.Volume = 0.6
footstep.RollOffMaxDistance = 50
footstep.Parent = root

-- Track grounded and current material
local grounded = true
local currentMaterial: Enum.Material? = humanoid.FloorMaterial

humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
	currentMaterial = humanoid.FloorMaterial
end)

humanoid.StateChanged:Connect(function(_, newState)
	if newState == Enum.HumanoidStateType.Freefall
		or newState == Enum.HumanoidStateType.Jumping
		or newState == Enum.HumanoidStateType.FallingDown
		or newState == Enum.HumanoidStateType.Swimming
		or newState == Enum.HumanoidStateType.Seated then
		grounded = false
	elseif newState == Enum.HumanoidStateType.Running
		or newState == Enum.HumanoidStateType.RunningNoPhysics
		or newState == Enum.HumanoidStateType.Landed
		or newState == Enum.HumanoidStateType.GettingUp then
		grounded = true
	end
end)

-- Re-attach sound if character respawns
player.CharacterAdded:Connect(function()
	character, humanoid, root = getCharacter()
	currentMaterial = humanoid.FloorMaterial
	footstep.Parent = root
	grounded = true
end)

-- Simple step timing based on speed
local lastStep = 0
RunService.Heartbeat:Connect(function(dt)
	if not grounded then return end
	if not currentMaterial or currentMaterial == Enum.Material.Air then return end

	local speed = root.AssemblyLinearVelocity.Magnitude
	if speed < 1.0 then return end

	-- Interval scales with speed (clamped)
	local interval = math.clamp(6.0 / math.max(speed, 1), 0.18, 0.5)
	lastStep += dt
	if lastStep < interval then return end
	lastStep = 0

	local tableForMat = FootstepModule:GetTableFromMaterial(currentMaterial)
	if not tableForMat or #tableForMat == 0 then
		-- Fallback to concrete if unmapped
		tableForMat = FootstepModule.SoundIds.Concrete
	end

	local id = FootstepModule:GetRandomSound(tableForMat)
	if not id or id == "" then return end

	footstep.SoundId = id
	footstep.PlaybackSpeed = 0.95 + math.random() * 0.1
	footstep:Play()
end)
