-- src/shared/config/TeleportConfig.lua
-- Centralized teleport configuration for game <-> lobby flow

local TeleportConfig = {}

-- TODO: set this to your Lobby place ID (the place players should return to)
TeleportConfig.LobbyPlaceId = 104756079644077

-- When all players in the server are dead, show Death UI with a forced return timer.
-- After this many seconds (if all are still dead), everyone is teleported back to the lobby.
TeleportConfig.ForcedReturnSeconds = 60

return TeleportConfig

