-- Main Weapon Damage System

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Reference pre-defined WeaponDamage remote
local weaponDamageRemote = ReplicatedStorage.Remotes.WeaponDamage
local headshotClaimRemote = ReplicatedStorage.Remotes:FindFirstChild("HeadshotClaim")
	or Instance.new("RemoteEvent", ReplicatedStorage.Remotes)
headshotClaimRemote.Name = "HeadshotClaim"

-- Lightweight headshot claim cache (shooter -> { [target] = { time = os.clock() } })
local _recentHeadshotClaims = {}
local HEADSHOT_CLAIM_TTL = 0.2

local function _pruneClaims()
	local now = os.clock()
	for shooter, targets in pairs(_recentHeadshotClaims) do
		for target, info in pairs(targets) do
			if now - info.time > HEADSHOT_CLAIM_TTL then
				targets[target] = nil
			end
		end
		if next(targets) == nil then
			_recentHeadshotClaims[shooter] = nil
		end
	end
end

-- Handle client headshot claims
headshotClaimRemote.OnServerEvent:Connect(function(player, targetCharacter, weaponName, clientShotTime)
	if typeof(targetCharacter) ~= "Instance" or not targetCharacter:IsA("Model") then
		return
	end
	if not targetCharacter:FindFirstChildOfClass("Humanoid") then
		return
	end
	_recentHeadshotClaims[player] = _recentHeadshotClaims[player] or {}
	_recentHeadshotClaims[player][targetCharacter] =
		{ time = os.clock(), weapon = weaponName, clientTime = clientShotTime }
	_pruneClaims()
end)

weaponDamageRemote.OnServerEvent:Connect(function(player, targetCharacter, damage, weaponName)
	-- Basic validation
	if not player.Character then
		return
	end
	if not targetCharacter then
		return
	end
	if targetCharacter == player.Character then
		return
	end

	-- Distance check
	if player.Character.PrimaryPart and targetCharacter.PrimaryPart then
		local playerPos = player.Character.PrimaryPart.Position
		local targetPos = targetCharacter.PrimaryPart.Position
		local distance = (playerPos - targetPos).Magnitude
		if distance > 250 then
			return
		end
	end

	-- add lightweight headshot upgrade if client claimed just recently and the weapon supports it
	if weaponName then
		local WeaponConfig = require(ReplicatedStorage.Shared.config.WeaponConfig)
		local wcfg = WeaponConfig.getRangedWeaponConfig(weaponName)
		if wcfg and wcfg.HeadshotsEnabled then
			local shooterClaims = _recentHeadshotClaims[player]
			local claim = shooterClaims and shooterClaims[targetCharacter]
			if claim and (os.clock() - claim.time) <= HEADSHOT_CLAIM_TTL then
				local mult = tonumber(wcfg.HeadshotMultiplier) or 2
				damage = math.floor(damage * mult)
				-- consume claim
				shooterClaims[targetCharacter] = nil
			end
		end
	end

	-- Try AIManager first
	local AIManager = require(game.ServerScriptService.Server.ai.AIManager)
	local aiManager = AIManager.getInstance()
	local creature = aiManager:getCreatureByModel(targetCharacter)

	if creature then
		if creature.takeDamage then
			creature:takeDamage(damage, player)
			return
		end
	end

	-- Fallback to humanoid damage
	local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid then
		return
	end

	-- Prevent PvP damage
	if game.Players:GetPlayerFromCharacter(targetCharacter) then
		return
	end

	targetHumanoid.Health -= damage
end)
