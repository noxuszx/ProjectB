local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Expose ZonePlus from Wally (Packages) under ReplicatedStorage.Shared.modules
-- Usage: local ZonePlus = require(game.ReplicatedStorage.Shared.modules.ZonePlus)
return require(ReplicatedStorage.Packages.zoneplus)

