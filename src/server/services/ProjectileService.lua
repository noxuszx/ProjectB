-- src/server/services/ProjectileService.lua
-- Centralized projectile system for NPCs and players
-- Handles server-authoritative raycast damage and client visual coordination

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponConfig = require(ReplicatedStorage.Shared.config.WeaponConfig)

local ProjectileService = {}

-- Cache remotes for performance
local weaponDamageRemote = nil
local projectileVisualRemote = nil

-- Initialize remotes
local function initializeRemotes()
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    
    -- Reuse existing WeaponDamage remote for damage
    weaponDamageRemote = remotesFolder:WaitForChild("WeaponDamage")
    
    -- Create ProjectileVisual remote if it doesn't exist
    projectileVisualRemote = remotesFolder:FindFirstChild("ProjectileVisual")
    if not projectileVisualRemote then
        projectileVisualRemote = Instance.new("RemoteEvent")
        projectileVisualRemote.Name = "ProjectileVisual"
        projectileVisualRemote.Parent = remotesFolder
    end
end

-- Create new raycast params for each operation to avoid race conditions
local function createRaycastParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.IgnoreWater = true
	return params
end

-- Determine the firing origin for a shooter (NPC or player)
-- Tries to use a part named "Muzzle" on the equipped weapon; falls back to a point
-- slightly above the creature's PrimaryPart if no muzzle is found.
local function getMuzzlePosition(shooter)
	if shooter and shooter.model then
		-- Assume the weapon model is parented directly under the creature model and named "Weapon"
		local weapon = shooter.model:FindFirstChild("Weapon")
		if weapon then
			local muzzle = weapon:FindFirstChild("Muzzle")
			if muzzle and muzzle:IsA("BasePart") then
				return muzzle.Position
			end
		end
		-- Fallback: try any descendant named "Muzzle"
		local fallbackMuzzle = shooter.model:FindFirstChild("Muzzle", true)
		if fallbackMuzzle and fallbackMuzzle:IsA("BasePart") then
			return fallbackMuzzle.Position
		end
	end
	-- Default: shoot from slightly above the center of the creature
	return shooter.model.PrimaryPart.Position + Vector3.new(0, 3.5, 0)
end

-- Expose utility so AI behaviors can reuse it
ProjectileService.getMuzzlePosition = getMuzzlePosition

-- Perform line of sight check between two positions
function ProjectileService.hasLineOfSight(origin, targetPos, ignoreList)
    local raycastParams = createRaycastParams()
    raycastParams.FilterDescendantsInstances = ignoreList or {}
    
    local direction = (targetPos - origin).Unit
    local maxDistance = (targetPos - origin).Magnitude
    
    local result = workspace:Raycast(origin, direction * maxDistance, raycastParams)
    
    -- Clear LOS if no obstruction or hit the target/ignored objects
    return not result or (ignoreList and (function()
        for _, ignoredInstance in pairs(ignoreList) do
            if result.Instance:IsDescendantOf(ignoredInstance) then
                return true
            end
        end
        return false
    end)())
end

-- Fire a projectile with server-authoritative damage and client visuals
function ProjectileService.fire(origin, targetPos, weaponName, shooter, ignoreList)
    if not weaponDamageRemote then
        initializeRemotes()
    end
    
    -- Get weapon configuration
    local weaponConfig = WeaponConfig.getRangedWeaponConfig(weaponName)
    if not weaponConfig then
        warn("[ProjectileService] No config found for weapon:", weaponName)
        return nil
    end
    
    -- Perform server-authoritative raycast
    local raycastParams = createRaycastParams()
    raycastParams.FilterDescendantsInstances = ignoreList or {}
    
    local direction = (targetPos - origin).Unit
    local maxRange = weaponConfig.Range or 200
    
    local result = workspace:Raycast(origin, direction * maxRange, raycastParams)
    
    local hitPosition = result and result.Position or (origin + direction * maxRange)
    local hitInstance = result and result.Instance or nil
    local hitCharacter = nil
    
    -- Find hit character if we hit something
    if hitInstance then
        local currentParent = hitInstance.Parent
        while currentParent do
            if currentParent:FindFirstChildOfClass("Humanoid") then
                hitCharacter = currentParent
                break
            end
            currentParent = currentParent.Parent
        end
    end
    
    -- Apply damage if we hit a valid target
    if hitCharacter and weaponConfig.Damage then
        -- Server-side damage handling - call WeaponTest damage logic directly
        local Players = game:GetService("Players")
        
        -- Try AIManager first for creature damage
        local AIManager = require(game.ServerScriptService.Server.ai.AIManager)
        local aiManager = AIManager.getInstance()
        local creature = aiManager:getCreatureByModel(hitCharacter)
        
        if creature then
            if creature.takeDamage then
                creature:takeDamage(weaponConfig.Damage, shooter)
            end
        else
            -- Fallback to humanoid damage (for non-AI targets)
            local targetHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
            if targetHumanoid then
                -- Prevent PvP damage if target is a player
                local isTargetPlayer = Players:GetPlayerFromCharacter(hitCharacter) ~= nil
                local isShooterPlayer = false
                if typeof(shooter) == "Instance" then
                    isShooterPlayer = Players:GetPlayerFromCharacter(shooter) ~= nil
                end
                -- Allow damage to players when shooter is an NPC
                if (not isTargetPlayer) or (isTargetPlayer and not isShooterPlayer) then
                    targetHumanoid:TakeDamage(weaponConfig.Damage)
                end
            end
        end
    end
    
    -- Notify player client for hit indicators
    if hitCharacter then
        local Players = game:GetService("Players")
        local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
        if hitPlayer and weaponDamageRemote then
            weaponDamageRemote:FireClient(hitPlayer, weaponName, weaponConfig.Damage, shooter)
        end
    end
    
    -- Send visual payload to clients within reasonable range
    local visualPayload = {
        weaponName = weaponName,
        origin = origin,
        hitPosition = hitPosition,
        hitInstance = hitInstance,
        lifetime = weaponConfig.BulletConfig and weaponConfig.BulletConfig.Lifetime or 2.0
    }
    
    -- Fire to all clients (or optimize with radius later if needed)
    projectileVisualRemote:FireAllClients(visualPayload)
    
    return {
        hit = result ~= nil,
        hitPosition = hitPosition,
        hitCharacter = hitCharacter,
        distance = (hitPosition - origin).Magnitude
    }
end

-- Perform simple distance check (for AI optimal range logic)
function ProjectileService.getDistance(pos1, pos2)
    return (pos2 - pos1).Magnitude
end

-- Check if target is within range
function ProjectileService.isInRange(origin, targetPos, maxRange)
    return ProjectileService.getDistance(origin, targetPos) <= maxRange
end

return ProjectileService