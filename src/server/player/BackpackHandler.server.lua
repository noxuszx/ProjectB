--[[
    BackpackHandler.server.lua
    Handles BackpackEvent remote events for the LIFO sack system
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BackpackService = require(script.Parent.BackpackService)

-- Create Remotes folder if it doesn't exist
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

-- Create BackpackEvent RemoteEvent
local BackpackEvent = remotesFolder:FindFirstChild("BackpackEvent")
if not BackpackEvent then
    BackpackEvent = Instance.new("RemoteEvent")
    BackpackEvent.Name = "BackpackEvent"
    BackpackEvent.Parent = remotesFolder
end

BackpackEvent.OnServerEvent:Connect(function(player, action, ...)
    local args = {...}
    
    if action == "RequestStore" then
        local object = args[1]
        local success, message, backpack = BackpackService.storeObject(player, object)
        
        if success then
            local contents = BackpackService.getBackpackContents(player)
            BackpackEvent:FireClient(player, "Sync", contents, message)
        else
            BackpackEvent:FireClient(player, "Error", message)
        end
        
    elseif action == "RequestRetrieve" then
        local success, message, backpack, newObject = BackpackService.retrieveObject(player)
        
        if success then
            local contents = BackpackService.getBackpackContents(player)
            BackpackEvent:FireClient(player, "Sync", contents, message)
        else
            BackpackEvent:FireClient(player, "Error", message)
        end
        
    elseif action == "RequestSync" then
        local contents = BackpackService.getBackpackContents(player)
        BackpackEvent:FireClient(player, "Sync", contents)
    end
end)