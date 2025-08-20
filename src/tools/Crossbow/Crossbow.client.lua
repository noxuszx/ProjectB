--[[
    Crossbow.client.lua
    Ranged weapon system with hitscan mechanics and realistic bullet tracers
    Uses instant hit detection with visual tracer animation for best gameplay feel
]]
--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local tool = script.Parent
local player = Players.LocalPlayer
local LocalHitRegistry = require(ReplicatedStorage.Shared.modules.LocalHitRegistry)
local SoundPlayer = require(ReplicatedStorage.Shared.modules.SoundPlayer)

local WeaponConfig = require(ReplicatedStorage.Shared.config.WeaponConfig)
local weaponName = tool.Name
local config = WeaponConfig.getRangedWeaponConfig(weaponName)

if not config then
    error("[" .. weaponName .. "] No ranged weapon configuration found!")
end

local lastFireTime = 0
local isEquipped = false
local currentCharacter = nil
local weaponRemote = nil
local headshotClaimRemote = nil


local function initializeRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        weaponRemote = remotes:FindFirstChild("WeaponDamage")
        headshotClaimRemote = remotes:FindFirstChild("HeadshotClaim")
        if not weaponRemote then
            warn("[" .. weaponName .. "] WeaponDamage remote not found!")
        end
        if not headshotClaimRemote then
            warn("[" .. weaponName .. "] HeadshotClaim remote not found (headshot FX will still play locally)")
        end
    end
end

local function isOnCooldown()
    local currentTime = tick()
    local timeSinceLastFire = currentTime - lastFireTime
    return timeSinceLastFire < config.Cooldown
end

local function getCooldownRemaining()
    local currentTime = tick()
    local timeSinceLastFire = currentTime - lastFireTime
    return math.max(0, config.Cooldown - timeSinceLastFire)
end

local function findMuzzlePoint()
    local muzzlePart = tool:FindFirstChild("Muzzle") or tool:FindFirstChild("Barrel")
    if muzzlePart then
        return muzzlePart.CFrame
    end
    local handle = tool:FindFirstChild("Handle")
    if handle then
        return handle.CFrame * CFrame.new(0, 0, -handle.Size.Z / 2 - 0.5)
    end

    if currentCharacter and currentCharacter.PrimaryPart then
        return currentCharacter.PrimaryPart.CFrame * CFrame.new(0, 1, -2)
    end

    return CFrame.new()
end

local function getZoneParts()
    local zoneParts = {}
    
    -- Find all zone trigger parts (used by ZonePlus)
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Trigger" and obj.CanQuery then
            table.insert(zoneParts, obj)
        end
    end
    
    return zoneParts
end

local function performHitscan(muzzlePos, mouseHitPos)
    if not currentCharacter or not currentCharacter.PrimaryPart then
        return nil, nil
    end

    local rayDirection = (mouseHitPos - muzzlePos).Unit * config.Range
    local raycastParams = RaycastParams.new()

    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = { currentCharacter, tool }
    local zoneParts = getZoneParts()
    for _, zonePart in pairs(zoneParts) do
        table.insert(filterList, zonePart)
    end
    
    raycastParams.FilterDescendantsInstances = filterList

    local raycastResult = workspace:Raycast(muzzlePos, rayDirection, raycastParams)

    if raycastResult then
        return raycastResult.Instance, raycastResult.Position
    else
        return nil, mouseHitPos
    end
end

-- Create toolbox-style bullet tracer
local function createTracer(startPos, hitPos)
    local beam = Instance.new("Part", workspace)
    beam.BrickColor = BrickColor.new("Ghost grey")
    beam.FormFactor = "Custom"
    beam.Material = "SmoothPlastic"
    beam.Transparency = 0
    beam.Anchored = true
    beam.Locked = true
    beam.CanCollide = false

    local distance = (hitPos - startPos).Magnitude
    beam.Size = Vector3.new(0.1, 0.1, distance)
    beam.CFrame = CFrame.new(startPos, hitPos) * CFrame.new(0, 0, -distance / 2)

    Debris:AddItem(beam, 0.05)
end

local function playFireSound()
    -- Play the sound located under the "Sound" part inside the tool (recursive search)
    local soundPart = tool:FindFirstChild("Sound", true)
    if soundPart then
        local sound = soundPart:FindFirstChildWhichIsA("Sound")
        if sound then
            -- Clone so repeated shots can overlap without cutting each other off
            local clone = sound:Clone()
            clone.Name = "Shoot"
            clone.Parent = soundPart
            clone:Play()
            clone.Ended:Connect(function()
                clone:Destroy()
            end)
            return
        end
    end
    -- If no Sound part is found, do nothing (intentional: no SoundManager fallback)
end

local function findTargetModel(hitPart)
    if not hitPart then
        return nil
    end

    local targetModel = hitPart:FindFirstAncestorOfClass("Model")
    return targetModel
end

local function getCrosshairAimPoint()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local vpSize = camera.ViewportSize
    local screenPoint = Vector2.new(vpSize.X/2, vpSize.Y/2)
    local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y, 0)
    -- Project a point far away along the camera's look direction
    local targetPos = ray.Origin + ray.Direction.Unit * (config.Range or 200)
    return targetPos
end

local function isFirstPerson()
    local camera = workspace.CurrentCamera
    local char = player.Character
    if not camera or not char then return false end
    local head = char:FindFirstChild("Head")
    if not head then return false end
    local dist = (camera.CFrame.Position - head.Position).Magnitude
    return dist < 1.0 or Players.LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson
end

local function executeFire()
    if isOnCooldown() then
        return false
    end

    lastFireTime = tick()

    local muzzlePos = findMuzzlePoint()
    local startPos = muzzlePos.Position

    local mouseHitPos
    if UserInputService.TouchEnabled then
        -- On mobile: Fire button or first-person -> crosshair; otherwise tap-to-aim
        local aimMode = tool:GetAttribute("AimMode")
        if aimMode == "Crosshair" or isFirstPerson() then
            mouseHitPos = getCrosshairAimPoint()
        else
            local mouse = player:GetMouse()
            if mouse and mouse.Hit then
                mouseHitPos = mouse.Hit.Position
            else
                mouseHitPos = getCrosshairAimPoint()
            end
        end
    else
        local mouse = player:GetMouse()
        if mouse and mouse.Hit then
            mouseHitPos = mouse.Hit.Position
        else
            mouseHitPos = getCrosshairAimPoint()
        end
    end

    local hitPart, hitPos = performHitscan(startPos, mouseHitPos)

    createTracer(startPos, hitPos)
    playFireSound()

    if hitPart then
        local targetModel = findTargetModel(hitPart)
        if targetModel then
            -- Immediate local hit confirm so first/last hits are reliable
            local parent = targetModel.PrimaryPart or targetModel
            SoundPlayer.playAt("hit_confirm", parent, { volume = 0.5, rolloff = { min = 8, max = 60, emitter = 5 } })
            -- Record local ownership (optional)
            LocalHitRegistry.claim(targetModel)
            -- Local headshot detection for responsiveness
            local head = targetModel:FindFirstChild("Head")
            local isHeadshot = head and (hitPart == head or hitPart:IsDescendantOf(head))
            if isHeadshot then
                -- Immediate local feedback hook point (sound/UI); kept minimal here
                -- Example: play a distinct sound if desired
                -- (You can wire into your UI system to flash a 'Headshot!' indicator.)
                if headshotClaimRemote then
                    -- Send lightweight claim to server for verification
                    headshotClaimRemote:FireServer(targetModel, weaponName, os.clock())
                end
            end
            if weaponRemote then
                weaponRemote:FireServer(targetModel, config.Damage, weaponName)
            end
        end
    end

    return true
end



tool.Equipped:Connect(function()
    isEquipped = true
    currentCharacter = player.Character
    if not weaponRemote then
        initializeRemote()
    end
end)

tool.Unequipped:Connect(function()
    isEquipped = false
    currentCharacter = nil
end)

tool.Activated:Connect(function()
    if not isEquipped then
        return
    end

    executeFire()
end)

player.CharacterAdded:Connect(function(character)
    if isEquipped then
        currentCharacter = character
    end
end)

initializeRemote()
