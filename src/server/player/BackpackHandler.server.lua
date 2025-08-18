--[[
    BackpackHandler.server.lua
    Handles BackpackEvent remote events for the LIFO sack system
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BackpackService = require(script.Parent.BackpackService)

-- Reference pre-defined remotes (for LIFO backpack system)
local remotesFolder = ReplicatedStorage.Remotes
local BackpackEvent = remotesFolder.BackpackEvent
local BackpackChanged = remotesFolder.BackpackChanged

BackpackEvent.OnServerEvent:Connect(function(player, action, ...)
    local args = {...}
    
    if action == "RequestStore" then
        local object = args[1]
        local success, message, backpack = BackpackService.storeObject(player, object)
        
        if success then
            local contents = BackpackService.getBackpackContents(player)
            local count, capacity = BackpackService.getBackpackStats(player)
            BackpackEvent:FireClient(player, "Sync", contents, message, capacity)
            -- Fire instant update event
            BackpackChanged:FireClient(player, contents)
            -- Play store sound
            BackpackEvent:FireClient(player, "PlaySound", "STORE_SOUND_ID")
        else
            BackpackEvent:FireClient(player, "Error", message)
        end
        
    elseif action == "RequestRetrieve" then
        local success, message, backpack, newObject = BackpackService.retrieveObject(player)
        
        if success then
            local contents = BackpackService.getBackpackContents(player)
            local count, capacity = BackpackService.getBackpackStats(player)
            BackpackEvent:FireClient(player, "Sync", contents, message, capacity)
            -- Fire instant update event
            BackpackChanged:FireClient(player, contents)
            -- Play unstore sound
            BackpackEvent:FireClient(player, "PlaySound", "UNSTORE_SOUND_ID")
        else
            BackpackEvent:FireClient(player, "Error", message)
        end
        
    elseif action == "RequestSync" then
        local contents = BackpackService.getBackpackContents(player)
        local count, capacity = BackpackService.getBackpackStats(player)
        BackpackEvent:FireClient(player, "Sync", contents, nil, capacity)
    end
end)