-- src/server/admin/AdminCommands.lua
-- Server-side admin command system providing fly (with ascend/descend) and noclip.
-- Replace the UserId list below with your own.

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local PhysicsService     = game:GetService("PhysicsService")

local AdminCommands = {}

---------------------------------------------------------------------
-- CONFIGURATION ----------------------------------------------------
---------------------------------------------------------------------

local ADMIN_USER_IDS = {
    3255890550, -- << change to your Roblox account ID
}

local COMMAND_PREFIX = ";"  -- chat prefix for admin commands
local FLY_SPEED      = 70   -- studs / second

---------------------------------------------------------------------
-- REMOTE EVENT (client input) --------------------------------------
---------------------------------------------------------------------

local remote: RemoteEvent
if ReplicatedStorage:FindFirstChild("AdminFlyControl") then
    remote = ReplicatedStorage.AdminFlyControl :: RemoteEvent
else
    remote = Instance.new("RemoteEvent")
    remote.Name = "AdminFlyControl"
    remote.Parent = ReplicatedStorage
end

---------------------------------------------------------------------
-- INTERNAL STATE ---------------------------------------------------
---------------------------------------------------------------------

-- state[plr] = {
--     Flying         = bool,
--     Noclip         = bool,
--     HeartbeatConn  = RBXScriptConnection?,
--     Input          = {dir:Vector3, ascend:boolean, descend:boolean},
-- }
local state = {}

local function ensureState(plr: Player)
    state[plr] = state[plr] or {Flying = false, Noclip = false, Input = {dir = Vector3.zero}}
    return state[plr]
end

local function isAdmin(plr: Player)
    for _, id in ipairs(ADMIN_USER_IDS) do
        if plr.UserId == id then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------
-- FLY --------------------------------------------------------------
---------------------------------------------------------------------

local function createFlyBodyMovers(hrp: BasePart)
    local gyro = Instance.new("BodyGyro")
    gyro.Name        = "AdminFlyGyro"
    gyro.MaxTorque   = Vector3.new(9e4, 9e4, 9e4)
    gyro.P           = 9e4
    gyro.CFrame      = hrp.CFrame
    gyro.Parent      = hrp

    local vel = Instance.new("BodyVelocity")
    vel.Name        = "AdminFlyVel"
    vel.MaxForce    = Vector3.new(9e4, 9e4, 9e4)
    vel.Parent      = hrp

    return gyro, vel
end

local function enableFly(plr: Player)
    local char = plr.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end

    local s = ensureState(plr)
    if s.Flying then return end

    local gyro, vel = createFlyBodyMovers(hrp)
    s.Input = {dir = Vector3.zero, ascend = false, descend = false}

    -- listen for this player input packets
    remote.OnServerEvent:Connect(function(sender: Player, data)
        if sender ~= plr then return end
        s.Input = data
    end)

    -- heartbeat velocity/orientation update
    s.HeartbeatConn = RunService.Heartbeat:Connect(function()
        if hrp.Parent == nil then return end
        local inp = s.Input
        local dir = inp.dir or Vector3.zero
        if inp.ascend  then dir += Vector3.new(0,  1, 0) end
        if inp.descend then dir += Vector3.new(0, -1, 0) end

        if dir.Magnitude > 0 then
            dir           = dir.Unit
            vel.Velocity  = dir * FLY_SPEED
            -- face movement direction ignoring vertical component
            local flat = Vector3.new(dir.X, 0, dir.Z)
            if flat.Magnitude > 0.1 then
                gyro.CFrame = CFrame.new(hrp.Position, hrp.Position + flat)
            end
        else
            vel.Velocity = Vector3.zero
        end
    end)

    s.Flying = true
    print("[AdminCommands] fly ON for", plr.Name)
end

local function disableFly(plr: Player)
    local char = plr.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end

    for _,v in ipairs(hrp:GetChildren()) do
        if v.Name == "AdminFlyGyro" or v.Name == "AdminFlyVel" then v:Destroy() end
    end

    local s = ensureState(plr)
    if s.HeartbeatConn then s.HeartbeatConn:Disconnect() end
    s.Flying = false
    print("[AdminCommands] fly OFF for", plr.Name)
end

---------------------------------------------------------------------
-- NOCLIP -----------------------------------------------------------
---------------------------------------------------------------------

local function setCharacterCollisions(char: Model, enabled: boolean)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = enabled
            PhysicsService:SetPartCollisionGroup(part, enabled and "Default" or "Admins")
        end
    end
end

local function enableNoclip(plr: Player)
    local char = plr.Character; if not char then return end
    local s = ensureState(plr); if s.Noclip then return end
    setCharacterCollisions(char, false)
    s.Noclip = true
    print("[AdminCommands] noclip ON for", plr.Name)
end

local function disableNoclip(plr: Player)
    local char = plr.Character; if not char then return end
    setCharacterCollisions(char, true)
    ensureState(plr).Noclip = false
    print("[AdminCommands] noclip OFF for", plr.Name)
end

---------------------------------------------------------------------
-- COMMAND DISPATCH -------------------------------------------------
---------------------------------------------------------------------

function AdminCommands.RunCommand(plr: Player, msg: string)
    if not (isAdmin(plr) and msg:sub(1,#COMMAND_PREFIX)==COMMAND_PREFIX) then return end
    local cmd = string.lower( (string.split(msg:sub(#COMMAND_PREFIX+1), " ")[1] or "") )
    if cmd == "fly"      then enableFly(plr)
    elseif cmd == "unfly" or cmd == "walk" then disableFly(plr)
    elseif cmd == "noclip" or cmd == "nc"   then enableNoclip(plr)
    elseif cmd == "clip"                       then disableNoclip(plr) end
end

---------------------------------------------------------------------
-- CLEANUP ----------------------------------------------------------
---------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(plr)
    disableFly(plr)
    disableNoclip(plr)
    state[plr] = nil
end)

return AdminCommands
