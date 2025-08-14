--[[
    Spear.client.lua
    Enhanced melee weapon system with cooldowns, configuration, and proper framework
    Part of the unified melee weapon system for ProjectB
]]--

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- Tool and player references
local tool = script.Parent
local player = Players.LocalPlayer

-- Configuration
local WeaponConfig = require(ReplicatedStorage.Shared.config.WeaponConfig)
local weaponName = tool.Name
local config = WeaponConfig.getWeaponConfig(weaponName)

-- State variables
local lastAttackTime = 0
local isEquipped = false
local currentCharacter = nil
local weaponRemote = nil
local attackAnimationTrack = nil
local humanoid = nil

-- Animation configuration
local ATTACK_ANIMATION_ID = "rbxassetid://81865375741678" -- Replace with actual animation ID


-- Initialize weapon remote
local function initializeRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        weaponRemote = remotes:FindFirstChild("WeaponDamage")
        if not weaponRemote then
            return
        end
    end
end

-- Load and setup attack animation
local function setupAnimation()
    if not currentCharacter or not humanoid then
        return false
    end
    
    -- Clean up existing animation track
    if attackAnimationTrack then
        attackAnimationTrack:Stop()
        attackAnimationTrack:Destroy()
        attackAnimationTrack = nil
    end
    
    -- Create animation object
    local attackAnimation = Instance.new("Animation")
    attackAnimation.AnimationId = ATTACK_ANIMATION_ID
    
    -- Load animation track
    local success, result = pcall(function()
        return humanoid:LoadAnimation(attackAnimation)
    end)
    
    if success and result then
        attackAnimationTrack = result
        attackAnimationTrack.Priority = Enum.AnimationPriority.Action
        return true
    else
        -- Fallback to R6 string signal
        createLegacyAnimationSignal()
        return false
    end
end

-- Create animation signal for R6 compatibility (fallback)
local function createLegacyAnimationSignal()
    local existingSignal = tool:FindFirstChild("toolanim")
    if existingSignal then
        existingSignal:Destroy()
    end
    
    local animSignal = Instance.new("StringValue")
    animSignal.Name = "toolanim"
    animSignal.Value = config.Animation
    animSignal.Parent = tool
end

-- Play attack animation
local function playAttackAnimation()
    if attackAnimationTrack then
        -- Stop any currently playing attack animation
        if attackAnimationTrack.IsPlaying then
            attackAnimationTrack:Stop()
        end
        
        -- Play the attack animation
        attackAnimationTrack:Play()
        
        -- Optional: Adjust animation speed based on weapon cooldown
        local animationSpeed = config.SwingDuration > 0 and (attackAnimationTrack.Length / config.SwingDuration) or 1
        attackAnimationTrack:AdjustSpeed(animationSpeed)
        
        return true
    else
        -- Fallback to legacy animation signal
        createLegacyAnimationSignal()
        return false
    end
end

-- Check if weapon is on cooldown
local function isOnCooldown()
    local currentTime = os.clock()
    local timeSinceLastAttack = currentTime - lastAttackTime
    return timeSinceLastAttack < config.Cooldown
end

-- Get remaining cooldown time
local function getCooldownRemaining()
    local currentTime = os.clock()
    local timeSinceLastAttack = currentTime - lastAttackTime
    return math.max(0, config.Cooldown - timeSinceLastAttack)
end

-- Perform magnitude-based hit detection
local function performMagnitudeHitCheck()
    if not currentCharacter or not currentCharacter.PrimaryPart then
        return {}
    end
    
    local rootPart = currentCharacter.PrimaryPart
    local playerPos = rootPart.Position
    local playerLookVector = rootPart.CFrame.LookVector
    local validTargets = {}
    
    -- Find all potential targets in workspace
    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and model ~= currentCharacter and model.PrimaryPart then
            local targetPos = model.PrimaryPart.Position
            local distance = (targetPos - playerPos).Magnitude
            
            -- Check if within range
            if distance <= config.Range then
                -- Directional check (if configured)
                local inDirectionalRange = true
                if config.DirectionalAngle and config.DirectionalAngle < 360 then
                    local directionToTarget = (targetPos - playerPos).Unit
                    local dotProduct = playerLookVector:Dot(directionToTarget)
                    local angleThreshold = math.cos(math.rad(config.DirectionalAngle / 2))
                    
                    inDirectionalRange = dotProduct >= angleThreshold
                end
                
                if inDirectionalRange then
                    -- Line of sight check (if configured)
                    local hasLineOfSight = true
                    if config.RequireLineOfSight then
                        local directionToTarget = (targetPos - playerPos).Unit
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                        rayParams.FilterDescendantsInstances = {currentCharacter}
                        
                        local rayResult = workspace:Raycast(playerPos, directionToTarget * distance, rayParams)
                        
                        -- Check if raycast hits the target or nothing (clear path)
                        if rayResult then
                            hasLineOfSight = rayResult.Instance:IsDescendantOf(model)
                        end
                    end
                    
                    if hasLineOfSight then
                        table.insert(validTargets, {
                            model = model,
                            distance = distance,
                            position = targetPos
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(validTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    return validTargets
end

-- Find target model from hit part
local function findTargetModel(hitPart)
    if not hitPart then return nil end
    
    -- Find the model this part belongs to
    local targetModel = hitPart:FindFirstAncestorOfClass("Model")
    if targetModel then
        return targetModel
    else
        return nil
    end
end

-- Execute the weapon attack
local function executeAttack()
    -- Check cooldown
    if isOnCooldown() then
        return false
    end
    
    -- Update last attack time
    lastAttackTime = os.clock()
    
    -- Play attack animation
    playAttackAnimation()
    
    -- Perform hit detection using magnitude
    local validTargets = performMagnitudeHitCheck()
    if #validTargets == 0 then
        return true  -- Attack executed but missed
    end
    
    -- Get the closest target
    local targetModel = validTargets[1].model
    
    -- Send damage to server
    if weaponRemote then
        weaponRemote:FireServer(targetModel, config.Damage)
    end
    
    return true
end

-- Tool equipped handler
tool.Equipped:Connect(function()
    isEquipped = true
    currentCharacter = player.Character
    
    -- Get humanoid reference
    if currentCharacter then
        humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
    end
    
    
    -- Initialize remote if not already done
    if not weaponRemote then
        initializeRemote()
    end
    
    -- Setup attack animation
    if humanoid then
        setupAnimation()
    else
        createLegacyAnimationSignal()
    end
end)

-- Tool unequipped handler
tool.Unequipped:Connect(function()
    isEquipped = false
    currentCharacter = nil
    humanoid = nil
    
    -- Clean up animation track
    if attackAnimationTrack then
        attackAnimationTrack:Stop()
        attackAnimationTrack:Destroy()
        attackAnimationTrack = nil
    end
    
end)

-- Tool activated handler (left click)
tool.Activated:Connect(function()
    if not isEquipped then return end
    
    executeAttack()
end)

-- Character respawn handler
player.CharacterAdded:Connect(function(character)
    if isEquipped then
        currentCharacter = character
        humanoid = character:FindFirstChildOfClass("Humanoid")
        
        -- Reload animation after respawn
        if humanoid then
            setupAnimation()
        end
    end
end)

-- Initialize
initializeRemote()