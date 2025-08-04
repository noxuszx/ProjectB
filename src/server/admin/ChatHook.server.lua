-- src/server/admin/ChatHook.server.lua
-- Connects chat messages to AdminCommands.RunCommand

local AdminCommands = require(script.Parent.AdminCommands)
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(plr)
    plr.Chatted:Connect(function(msg)
        AdminCommands.RunCommand(plr, msg)
    end)
end)

