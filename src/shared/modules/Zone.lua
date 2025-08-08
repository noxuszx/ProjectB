local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wrapper so code can require ReplicatedStorage.Shared.modules.Zone
-- and get the Zone API from the ZonePlus package that Rojo mounts under Shared.modules.
-- ZonePlus's init returns the Zone table directly.
return require(ReplicatedStorage.Shared.modules.zoneplus)

