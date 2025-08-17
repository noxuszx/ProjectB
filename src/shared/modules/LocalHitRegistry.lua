-- src/shared/modules/LocalHitRegistry.lua
-- Client-side registry to mark recent local hit claims so only the attacker hears hit SFX.
-- Usage:
--   LocalHitRegistry.claim(model)         -- call from weapon client when a local hit is detected
--   LocalHitRegistry.wasRecent(model)     -- call from UI/health listener to verify local ownership

local LocalHitRegistry = {}

local _recent = {}  -- [Model] = lastClaimTime
local DEFAULT_TTL = 0.35    -- seconds a claim remains valid (tune for your RTT)

function LocalHitRegistry.claim(model)
	if not model then return end
	_recent[model] = os.clock()
end

-- Optional ttlSeconds overrides default TTL for this check (useful to extend for kill events)
function LocalHitRegistry.wasRecent(model, ttlSeconds)
	local t = _recent[model]
	if not t then return false end
	local limit = tonumber(ttlSeconds) or DEFAULT_TTL
	if os.clock() - t <= limit then return true end
	_recent[model] = nil
	return false
end

return LocalHitRegistry
