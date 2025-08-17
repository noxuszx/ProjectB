-- src/server/services/ProjectileService.lua
-- Centralized projectile system for NPCs and players

local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local WeaponConfig           = require(ReplicatedStorage.Shared.config.WeaponConfig)
local ProjectileService      = {}
local weaponDamageRemote     = nil
local projectileVisualRemote = nil

local function initializeRemotes()
	local remotesFolder      = ReplicatedStorage:WaitForChild("Remotes")
	weaponDamageRemote       = remotesFolder.WeaponDamage
	projectileVisualRemote   = remotesFolder.ProjectileVisual
end


local function createRaycastParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.IgnoreWater = true
	return params
end


local function getMuzzlePosition(shooter)
	if shooter and shooter.model then
		local weapon = shooter.model:FindFirstChild("Weapon")
		if weapon then
			local muzzle = weapon:FindFirstChild("Muzzle")
			if muzzle and muzzle:IsA("BasePart") then
				return muzzle.Position
			end
		end
		local fallbackMuzzle = shooter.model:FindFirstChild("Muzzle", true)
		if fallbackMuzzle and fallbackMuzzle:IsA("BasePart") then
			return fallbackMuzzle.Position
		end
	end
	return shooter.model.PrimaryPart.Position + Vector3.new(0, 3.5, 0)
end

ProjectileService.getMuzzlePosition = getMuzzlePosition

function ProjectileService.hasLineOfSight(origin, targetPos, ignoreList)
	local raycastParams = createRaycastParams()
	raycastParams.FilterDescendantsInstances = ignoreList or {}
	local direction = (targetPos - origin).Unit
	local maxDistance = (targetPos - origin).Magnitude
	local result = workspace:Raycast(origin, direction * maxDistance, raycastParams)
	return not result
		or (
			ignoreList
			and (function()
				for _, ignoredInstance in pairs(ignoreList) do
					if result.Instance:IsDescendantOf(ignoredInstance) then
						return true
					end
				end
				return false
			end)()
		)
end

function ProjectileService.fire(origin, targetPos, weaponName, shooter, ignoreList)
	if not weaponDamageRemote then
		initializeRemotes()
	end

	local weaponConfig = WeaponConfig.getRangedWeaponConfig(weaponName)
	if not weaponConfig then
		warn("[ProjectileService] No config found for weapon:", weaponName)
		return nil
	end

	local raycastParams = createRaycastParams()
	raycastParams.FilterDescendantsInstances = ignoreList or {}

	local direction = (targetPos - origin).Unit
	local maxRange = weaponConfig.Range or 200

	local result = workspace:Raycast(origin, direction * maxRange, raycastParams)

	local hitPosition = result and result.Position or (origin + direction * maxRange)
	local hitInstance = result and result.Instance or nil
	local hitCharacter = nil
	local damageDealt = nil
	local wasHeadshot = false

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

	if hitCharacter and weaponConfig.Damage then
		local damage = weaponConfig.Damage
		do
			local head = hitCharacter:FindFirstChild("Head")
			if head and hitInstance then
				local isHeadshot = (hitInstance == head) or hitInstance:IsDescendantOf(head)
				if isHeadshot and weaponConfig.HeadshotsEnabled then
					local mult = tonumber(weaponConfig.HeadshotMultiplier) or 2
					damage = math.floor(damage * mult)
					wasHeadshot = true
				end
			end
		end
		damageDealt = damage

		local Players = game:GetService("Players")
		local AIManager = require(game.ServerScriptService.Server.ai.AIManager)
		local aiManager = AIManager.getInstance()
		local creature = aiManager:getCreatureByModel(hitCharacter)

		if creature then
			if creature.takeDamage then
				creature:takeDamage(damage, shooter)
			end
		else
			local targetHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
			if targetHumanoid then
				-- Prevent PvP damage if target is a player
				local isTargetPlayer = Players:GetPlayerFromCharacter(hitCharacter) ~= nil
				local isShooterPlayer = false
				if typeof(shooter) == "Instance" then
					isShooterPlayer = Players:GetPlayerFromCharacter(shooter) ~= nil
				end
				if (not isTargetPlayer) or (isTargetPlayer and not isShooterPlayer) then
					targetHumanoid:TakeDamage(damage)
				end
			end
		end
	end

	-- Notify player client for hit indicators (post-multiplier value)
	if hitCharacter then
		local Players = game:GetService("Players")
		local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
		if hitPlayer and weaponDamageRemote then
			weaponDamageRemote:FireClient(hitPlayer, weaponName, damageDealt or weaponConfig.Damage, shooter)
		end
	end

	-- Send visual payload to clients within reasonable range
	local visualPayload = {
		weaponName = weaponName,
		origin = origin,
		hitPosition = hitPosition,
		hitInstance = hitInstance,
		lifetime = weaponConfig.BulletConfig and weaponConfig.BulletConfig.Lifetime or 2.0,
	}

	-- Fire to all clients (or optimize with radius later if needed)
	projectileVisualRemote:FireAllClients(visualPayload)

	return {
		hit = result ~= nil,
		hitPosition = hitPosition,
		hitCharacter = hitCharacter,
		distance = (hitPosition - origin).Magnitude,
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
