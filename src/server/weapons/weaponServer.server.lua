-- Server Script (Place in ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvent (run this once)
local remoteEvent = Instance.new("RemoteEvent")
remoteEvent.Name = "WeaponDamage"
remoteEvent.Parent = ReplicatedStorage

remoteEvent.OnServerEvent:Connect(function(player, targetCharacter, damage)
    if not player.Character then return end
    if not targetCharacter or not targetCharacter:FindFirstChildOfClass("Humanoid") then return end
    if targetCharacter == player.Character then return end
    
    local playerPos = player.Character.HumanoidRootPart.Position
    local targetPos = targetCharacter.HumanoidRootPart.Position
    local distance = (playerPos - targetPos).Magnitude
    
    if distance > 15 then
        return
    end
    
    local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
    
    -- Check if target is a creature by trying to find it in AIManager
    local AIManager = require(game.ServerScriptService.Server.ai.AIManager)
    local aiManager = AIManager.getInstance()
    local creature = aiManager:getCreatureByModel(targetCharacter)
    
    if creature and creature.takeDamage then
        -- Use creature damage system (triggers fleeing for passive creatures)
        -- Pass player as threat source so creature knows which direction to flee
        creature:takeDamage(damage, player)
        print(player.Name .. " dealt " .. damage .. " damage to creature " .. targetCharacter.Name .. " (triggered fleeing)")
    else
        -- Check if target is another player - if so, don't allow damage
        if game.Players:GetPlayerFromCharacter(targetCharacter) then
            print(player.Name .. " tried to attack player " .. targetCharacter.Name .. " but PvP is disabled")
            return
        end
        
        -- For other non-creature entities, use direct health modification
        targetHumanoid.Health = targetHumanoid.Health - damage
        print(player.Name .. " dealt " .. damage .. " damage to " .. targetCharacter.Name)
    end
end)