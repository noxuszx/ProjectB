-- src/server/admin/AdminUIHandler.server.lua
-- Server-side handler for admin UI commands
-- Processes UI button commands and syncs state

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminCommands = require(script.Parent.AdminCommands)

-- Wait for RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Admin")
local commandRemote = remotes:WaitForChild("AdminCommand")
local stateSyncRemote = remotes:WaitForChild("AdminStateSync")

-- Ensure HideAllUI remote exists for UI visibility toggling
local hideAllUIRemote = remotes:FindFirstChild("HideAllUI")
if not hideAllUIRemote then
    hideAllUIRemote = Instance.new("RemoteEvent")
    hideAllUIRemote.Name = "HideAllUI"
    hideAllUIRemote.Parent = remotes
end

---------------------------------------------------------------------
-- ADMIN VERIFICATION ----------------------------------------------
---------------------------------------------------------------------

local ADMIN_USER_IDS = {
    3255890550, -- << Should match AdminCommands.lua
}

local function isAdmin(plr: Player)
    for _, id in ipairs(ADMIN_USER_IDS) do
        if plr.UserId == id then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------
-- STATE MANAGEMENT ------------------------------------------------
---------------------------------------------------------------------

-- Track admin states for UI synchronization
-- state[plr] = {flying = bool, noclip = bool, god = bool}
local playerStates = {}

local function getPlayerState(plr: Player)
    if not playerStates[plr] then
        playerStates[plr] = {
            flying = false,
            noclip = false,
            god = false
        }
    end
    return playerStates[plr]
end

local function syncPlayerState(plr: Player)
    if isAdmin(plr) then
        local state = getPlayerState(plr)
        stateSyncRemote:FireClient(plr, state)
    end
end

-- Sync state periodically to catch changes from chat commands
local function startStateSyncLoop()
    spawn(function()
        while true do
            wait(2) -- Sync every 2 seconds
            for _, plr in ipairs(Players:GetPlayers()) do
                if isAdmin(plr) then
                    syncPlayerState(plr)
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- COMMAND PROCESSING ----------------------------------------------
---------------------------------------------------------------------

-- Process UI commands by converting them to chat format
local function processUICommand(plr: Player, command: string, args: string?)
    if not isAdmin(plr) then
        warn("[AdminUIHandler] Non-admin player attempted to use admin UI:", plr.Name)
        return
    end
    
    -- Construct command message in chat format
    local commandMsg = "/" .. command
    if args then
        commandMsg = commandMsg .. " " .. args
    end
    
    print("[AdminUIHandler] Processing UI command from", plr.Name, ":", commandMsg)
    
    -- Update state before command (for toggle buttons)
    local state = getPlayerState(plr)
    
    -- Handle state updates for toggle commands
    if command == "fly" then
        state.flying = true
    elseif command == "unfly" or command == "walk" then
        state.flying = false
    elseif command == "noclip" or command == "nc" then
        state.noclip = true
        state.flying = true -- noclip auto-enables fly
    elseif command == "clip" then
        state.noclip = false
        state.flying = false -- clip auto-disables fly
    elseif command == "god" then
        state.god = true
    elseif command == "ungod" then
        state.god = false
    elseif command == "kill" then
        state.god = false -- kill removes god mode
    end
    
    -- Execute the command through existing AdminCommands system
    AdminCommands.RunCommand(plr, commandMsg)
    
    -- Sync updated state to client
    wait(0.1) -- Small delay to ensure command completes
    syncPlayerState(plr)
end

---------------------------------------------------------------------
-- REMOTE EVENT HANDLERS -------------------------------------------
---------------------------------------------------------------------

-- Handle UI command from client
commandRemote.OnServerEvent:Connect(function(plr, command, args)
    processUICommand(plr, command, args)
end)

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(plr)
    playerStates[plr] = nil
end)

-- Start the state sync loop
startStateSyncLoop()

print("[AdminUIHandler] Admin UI handler initialized")