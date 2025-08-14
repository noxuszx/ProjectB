-- Main Weapon Damage System

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Reference pre-defined WeaponDamage remote
local weaponDamageRemote = ReplicatedStorage.Remotes.WeaponDamage

weaponDamageRemote.OnServerEvent:Connect(function(player, targetCharacter, damage)
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

    -- Distance check (reasonable max range for any weapon)
    if player.Character.PrimaryPart and targetCharacter.PrimaryPart then
        local playerPos = player.Character.PrimaryPart.Position
        local targetPos = targetCharacter.PrimaryPart.Position
        local distance = (playerPos - targetPos).Magnitude
        if distance > 250 then  -- Increased from 15 to 250 studs (max weapon range)
            return 
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
