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

-- Debug function
local function debugPrint(...)
    if config.DebugEnabled then
        print("[" .. weaponName .. "]", ...)
    end
end

-- Initialize weapon remote
local function initializeRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        weaponRemote = remotes:FindFirstChild("WeaponDamage")
        if weaponRemote then
            debugPrint("✅ WeaponDamage remote found")
        else
            warn("[" .. weaponName .. "] WeaponDamage remote not found!")
        end
    end
end

-- Load and setup attack animation
local function setupAnimation()
    if not currentCharacter or not humanoid then
        debugPrint("❌ Cannot setup animation - no character or humanoid")
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
        debugPrint("✅ Attack animation loaded successfully")
        return true
    else
        warn("[" .. weaponName .. "] Failed to load attack animation:", result)
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
    
    debugPrint("Legacy animation signal created:", config.Animation)
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
        debugPrint("🎬 Playing attack animation")
        
        -- Optional: Adjust animation speed based on weapon cooldown
        local animationSpeed = config.SwingDuration > 0 and (attackAnimationTrack.Length / config.SwingDuration) or 1
        attackAnimationTrack:AdjustSpeed(animationSpeed)
        
        return true
    else
        -- Fallback to legacy animation signal
        createLegacyAnimationSignal()
        debugPrint("🎬 Using legacy animation signal")
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

-- Perform raycast to find hit target
local function performRaycast()
    if not currentCharacter or not currentCharacter.PrimaryPart then
        debugPrint("❌ No character or primary part")
        return nil
    end
    
    local rootPart = currentCharacter.PrimaryPart
    local startPosition = rootPart.Position
    local direction = rootPart.CFrame.LookVector * config.Range
    
    -- Create raycast params
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {currentCharacter}
    
    -- Perform raycast
    local raycastResult = workspace:Raycast(startPosition, direction, raycastParams)
    
    if raycastResult then
        debugPrint("🎯 Raycast hit:", raycastResult.Instance.Name)
        debugPrint("   Position:", raycastResult.Position)
        debugPrint("   Distance:", (raycastResult.Position - startPosition).Magnitude)
        
        return raycastResult.Instance, raycastResult.Position
    else
        debugPrint("❌ Raycast missed (range:", config.Range, "studs)")
        return nil
    end
end

-- Find target model from hit part
local function findTargetModel(hitPart)
    if not hitPart then return nil end
    
    debugPrint("🔍 Hit part:", hitPart.Name, "(" .. hitPart.ClassName .. ")")
    debugPrint("   Part parent:", tostring(hitPart.Parent and hitPart.Parent.Name))
    
    -- Find the model this part belongs to
    local targetModel = hitPart:FindFirstAncestorOfClass("Model")
    if targetModel then
        debugPrint("✅ Found target model:", targetModel.Name)
        debugPrint("   Model parent:", tostring(targetModel.Parent))
        return targetModel
    else
        debugPrint("❌ No model found for hit part")
        return nil
    end
end

-- Execute the weapon attack
local function executeAttack()
    -- Check cooldown
    if isOnCooldown() then
        local remaining = getCooldownRemaining()
        debugPrint("⏳ Attack on cooldown, remaining:", string.format("%.1f", remaining), "seconds")
        return false
    end
    
    -- Update last attack time
    lastAttackTime = os.clock()
    
    -- Play attack animation
    playAttackAnimation()
    
    -- Perform raycast
    local hitPart, hitPosition = performRaycast()
    if not hitPart then
        debugPrint("💨 Attack missed")
        return true  -- Attack executed but missed
    end
    
    -- Find target model
    local targetModel = findTargetModel(hitPart)
    if not targetModel then
        debugPrint("❌ No valid target found")
        return true  -- Attack executed but no valid target
    end
    
    -- Send damage to server
    if weaponRemote then
        debugPrint("⚔️ Dealing", config.Damage, "damage to", targetModel.Name)
        weaponRemote:FireServer(targetModel, config.Damage)
    else
        warn("[" .. weaponName .. "] Cannot deal damage - no remote found!")
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
    
    debugPrint("🗡️ Weapon equipped")
    debugPrint("   Damage:", config.Damage)
    debugPrint("   Range:", config.Range, "studs")
    debugPrint("   Cooldown:", config.Cooldown, "seconds")
    
    -- Initialize remote if not already done
    if not weaponRemote then
        initializeRemote()
    end
    
    -- Setup attack animation
    if humanoid then
        setupAnimation()
    else
        warn("[" .. weaponName .. "] No humanoid found - using legacy animation")
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
    
    debugPrint("📤 Weapon unequipped")
end)

-- Tool activated handler (left click)
tool.Activated:Connect(function()
    if not isEquipped then return end
    
    debugPrint("🖱️ Tool activated")
    executeAttack()
end)

-- Character respawn handler
player.CharacterAdded:Connect(function(character)
    if isEquipped then
        currentCharacter = character
        humanoid = character:FindFirstChildOfClass("Humanoid")
        debugPrint("👤 Character respawned while weapon equipped")
        
        -- Reload animation after respawn
        if humanoid then
            setupAnimation()
        end
    end
end)

-- Initialize
initializeRemote()
debugPrint("🚀 Weapon system initialized for", weaponName)