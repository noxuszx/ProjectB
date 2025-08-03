-- Main Weapon Damage System
print("🔥 WEAPON DAMAGE SYSTEM STARTING! 🔥")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create Remotes folder if it doesn't exist
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
    print("✅ Created Remotes folder")
end

-- Create WeaponDamage RemoteEvent
local weaponDamageRemote = remotesFolder:FindFirstChild("WeaponDamage")
if not weaponDamageRemote then
    weaponDamageRemote = Instance.new("RemoteEvent")
    weaponDamageRemote.Name = "WeaponDamage"
    weaponDamageRemote.Parent = remotesFolder
    print("✅ Created WeaponDamage RemoteEvent")
else
    print("✅ Found existing WeaponDamage RemoteEvent")
end

print("🚀 Setting up weapon damage handler...")

weaponDamageRemote.OnServerEvent:Connect(function(player, targetCharacter, damage)
    print("🎯 WEAPON DAMAGE EVENT FIRED!")
    print("   Player:", player.Name)
    print("   Target:", tostring(targetCharacter and targetCharacter.Name))
    print("   Damage:", damage)
    
    -- Basic validation
    if not player.Character then 
        print("❌ Player has no character")
        return 
    end
    if not targetCharacter then 
        print("❌ No target character")
        return 
    end
    if targetCharacter == player.Character then 
        print("❌ Player tried to attack themselves")
        return 
    end

    print("   Target parent:", tostring(targetCharacter.Parent))
    print("   Target class:", targetCharacter.ClassName)

    -- Distance check
    if player.Character.PrimaryPart and targetCharacter.PrimaryPart then
        local playerPos = player.Character.PrimaryPart.Position
        local targetPos = targetCharacter.PrimaryPart.Position
        local distance = (playerPos - targetPos).Magnitude
        print("   Distance:", distance)
        if distance > 15 then 
            print("❌ Target too far away")
            return 
        end
    end

    -- Try AIManager first
    local AIManager = require(game.ServerScriptService.Server.ai.AIManager)
    local aiManager = AIManager.getInstance()
    local creature = aiManager:getCreatureByModel(targetCharacter)
    
    print("   AIManager found creature:", tostring(creature ~= nil))
    if creature then
        print("   Creature type:", tostring(creature.creatureType or "unknown"))
        print("   Has takeDamage:", tostring(creature.takeDamage ~= nil))
        
        if creature.takeDamage then
            print("✅ Calling creature:takeDamage(" .. damage .. ")")
            creature:takeDamage(damage, player)
            return
        end
    end

    -- Fallback to humanoid damage
    local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
    if not targetHumanoid then 
        print("❌ No humanoid found, cannot damage")
        return 
    end

    -- Prevent PvP damage
    if game.Players:GetPlayerFromCharacter(targetCharacter) then
        print("❌ PvP damage prevented")
        return
    end

    print("✅ Falling back to humanoid damage")
    targetHumanoid.Health -= damage
    print("✅ " .. player.Name .. " dealt " .. damage .. " damage to " .. targetCharacter.Name)
end)

print("🚀 Weapon damage system ready!")