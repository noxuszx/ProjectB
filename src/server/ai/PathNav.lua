-- src/server/ai/PathNav.lua
-- Simple, reliable pathfinding helper
-- - Stateless compute
-- - Lightweight per-creature nav state (waypoints + index)
-- - Token bucket to cap path computations per second

local PathfindingService = game:GetService("PathfindingService")

local PathNav = {}

-- Token bucket: limit path builds per second
local TOKENS_PER_SECOND = 12
local MAX_TOKENS = 12
local tokens = MAX_TOKENS
local lastRefill = os.clock()

local function refillTokens()
    local now = os.clock()
    local elapsed = now - lastRefill
    if elapsed > 0 then
        local add = elapsed * TOKENS_PER_SECOND
        tokens = math.min(MAX_TOKENS, tokens + add)
        lastRefill = now
    end
end

local function tryConsumeToken()
    refillTokens()
    if tokens >= 1 then
        tokens = tokens - 1
        return true
    end
    return false
end

-- Compute a path; returns waypoints array or nil, status
function PathNav.computePath(startPos, goalPos, agentParams)
    if not tryConsumeToken() then
        return nil, "NoBudget"
    end

    local path
    if agentParams then
        path = PathfindingService:CreatePath(agentParams)
    else
        path = PathfindingService:CreatePath()
    end

    local ok, err = pcall(function()
        path:ComputeAsync(startPos, goalPos)
    end)
    if not ok then
        return nil, tostring(err)
    end

    if path.Status ~= Enum.PathStatus.Success then
        return nil, tostring(path.Status)
    end

    local wps = path:GetWaypoints()
    if not wps or #wps == 0 then
        return nil, "Empty"
    end
    return wps, "Success"
end

-- Ensure nav state table exists
function PathNav.ensureState(creature)
    creature._nav = creature._nav or { waypoints = nil, index = 0, lastRepath = 0, lastTarget = nil }
    return creature._nav
end

-- Follow current waypoint; returns true if still following, false if arrived or invalid
function PathNav.step(creature, speed)
    if not creature or not creature.model or not creature.model.PrimaryPart then
        return false
    end
    local nav = PathNav.ensureState(creature)
    local humanoid = creature.model:FindFirstChild("Humanoid")
    if not humanoid then return false end

    if not nav.waypoints or nav.index <= 0 then
        return false
    end

    -- If finished, return false
    if nav.index > #nav.waypoints then
        return false
    end

    local wp = nav.waypoints[nav.index]
    local targetPos = wp.Position

    -- Jump if needed
    if wp.Action == Enum.PathWaypointAction.Jump then
        humanoid.Jump = true
    end

    -- Issue/refresh MoveTo
    humanoid.WalkSpeed = speed
    humanoid:MoveTo(targetPos)

    -- Check proximity to advance
    local currentPos = creature.model.PrimaryPart.Position
    if (currentPos - targetPos).Magnitude <= 3 then
        nav.index += 1
        if nav.index <= #nav.waypoints then
            local nextWp = nav.waypoints[nav.index]
            if nextWp.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end
            humanoid:MoveTo(nextWp.Position)
        else
            return false -- arrived
        end
    end

    return true
end

-- Set a new path (overwrites existing)
function PathNav.setPath(creature, waypoints)
    local nav = PathNav.ensureState(creature)
    nav.waypoints = waypoints
    nav.index = 1
    nav.lastRepath = os.clock()
end

function PathNav.shouldRepath(creature, targetPos, repathInterval, moveThreshold)
    local nav = PathNav.ensureState(creature)
    local now = os.clock()
    if (now - (nav.lastRepath or 0)) >= (repathInterval or 1.2) then
        return true
    end
    if targetPos then
        local last = nav.lastTarget
        if not last or (last - targetPos).Magnitude >= (moveThreshold or 8) then
            return true
        end
    end
    return false
end

function PathNav.markTarget(creature, targetPos)
    local nav = PathNav.ensureState(creature)
    nav.lastTarget = targetPos
end

return PathNav

