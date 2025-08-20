-- src/server/admin/AdminCommands.lua
-- Server-side admin command system providing fly (with ascend/descend) and noclip.
-- Replace the UserId list below with your own.

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local PhysicsService     = game:GetService("PhysicsService")

-- Time/Environment modules for /time command
local DayNightCycle      = require(script.Parent.Parent.environment.DayNightCycle)
local TimeConfig         = require(ReplicatedStorage.Shared.config.Time)
local EconomyService     = require(script.Parent.Parent.services.EconomyService)
local ArenaManager       = require(script.Parent.Parent.events.ArenaManager)

local AdminCommands = {}

---------------------------------------------------------------------
-- CONFIGURATION ----------------------------------------------------
---------------------------------------------------------------------

local ADMIN_USER_IDS = {
    3255890550, -- << change to your Roblox account ID
}

local COMMAND_PREFIX = "/"  -- chat prefix for admin commands
local FLY_SPEED      = 70   -- studs / second

---------------------------------------------------------------------
-- REMOTE EVENT (client input) --------------------------------------
---------------------------------------------------------------------

-- Reference the pre-defined AdminFlyControl remote
local remote: RemoteEvent = ReplicatedStorage.Remotes.AdminFlyControl

---------------------------------------------------------------------
-- INTERNAL STATE ---------------------------------------------------
---------------------------------------------------------------------

-- state[plr] = {
--     Flying         = bool,
--     Noclip         = bool,
--     HeartbeatConn  = RBXScriptConnection?,
--     Input          = {dir:Vector3, ascend:boolean, descend:boolean},
--     God            = bool,
--     GodConn        = RBXScriptConnection?,
-- }
local state = {}

-- single listener for all player input
remote.OnServerEvent:Connect(function(p, data)
    local s = state[p]
    if s and s.Flying then
        s.Input = data
    end
end)

local function ensureState(plr: Player)
state[plr] = state[plr] or {Flying=false, Noclip=false, Input={dir=Vector3.zero}, God=false}
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
    if s.HeartbeatConn then 
        s.HeartbeatConn:Disconnect() 
        s.HeartbeatConn = nil
    end
    s.Flying = false
    print("[AdminCommands] fly OFF for", plr.Name)
end

---------------------------------------------------------------------
-- GOD MODE ---------------------------------------------------------
---------------------------------------------------------------------

local function applyGodMode(plr: Player)
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local s = ensureState(plr)
    if s.God then return end

    hum.MaxHealth = math.huge
    hum.Health = math.huge
    s.GodConn = hum.HealthChanged:Connect(function()
        if hum.Health < hum.MaxHealth * 0.99 then
            hum.Health = hum.MaxHealth
        end
    end)
    s.God = true
    print("[AdminCommands] god ON for", plr.Name)
end

local function removeGodMode(plr: Player)
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local s = ensureState(plr)
    if not s.God then return end

    if s.GodConn then s.GodConn:Disconnect(); s.GodConn=nil end
    s.God=false
    -- reset health to default values (adjust if game uses different base)
    hum.MaxHealth = 100
    hum.Health = 100
    print("[AdminCommands] god OFF for", plr.Name)
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

-- helper: set time period safely
local function setTimePeriod(periodStr: string)
    if not periodStr then return false end
    local p = string.upper(periodStr)
    local targets = {
        DAWN = TimeConfig.DAWN_START,
        NOON = TimeConfig.NOON_START,
        DUSK = TimeConfig.DUSK_START,
        NIGHT = TimeConfig.NIGHT_START,
    }
    local t = targets[p]
    if t then
        DayNightCycle.setTime(t)
        return true
    end
    return false
end

function AdminCommands.RunCommand(plr: Player, msg: string)
    if not (isAdmin(plr) and msg:sub(1,#COMMAND_PREFIX)==COMMAND_PREFIX) then return end
    local content = msg:sub(#COMMAND_PREFIX+1)
    local parts = string.split(content, " ")
    local cmd = string.lower(parts[1] or "")
    local arg1 = parts[2]

    if cmd == "fly" then
        enableFly(plr)
    elseif cmd == "unfly" or cmd == "walk" then
        disableFly(plr)
    elseif cmd == "god" then
        applyGodMode(plr)
    elseif cmd == "ungod" then
        removeGodMode(plr)
    elseif cmd == "noclip" or cmd == "nc" or cmd == "cnoclip" then
        enableNoclip(plr)
        enableFly(plr)
    elseif cmd == "clip" then
        disableNoclip(plr)
        disableFly(plr)
    elseif cmd == "time" then
        if arg1 and string.upper(arg1) == "NEXT" then
            DayNightCycle.skipToNextPeriod()
            print("[AdminCommands] Time advanced to next period")
        else
            if not setTimePeriod(arg1) then
                warn("[AdminCommands] /time requires one of: DAWN, NOON, DUSK, NIGHT, NEXT")
            else
                print("[AdminCommands] Time set to", string.upper(arg1))
            end
        end
    elseif cmd == "kill" then
        local char = plr.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local s = ensureState(plr)
                if s.God then removeGodMode(plr) end
                hum.Health = 0
                print("[AdminCommands] Killed", plr.Name)
            end
        end
    elseif cmd == "givemoney" or cmd == "givemoneyto" then
        -- Usage: /givemoney <amount> (self only for now)
        local amountNum = tonumber(arg1)
        if not amountNum or amountNum <= 0 then
            warn("[AdminCommands] /givemoney requires a positive number amount, e.g. /givemoney 100")
            return
        end
        if EconomyService.addMoney(plr, math.floor(amountNum)) then
            print(string.format("[AdminCommands] Gave %s %d coins", plr.Name, math.floor(amountNum)))
        end
    elseif cmd == "money" then
        -- Usage: /money set <amount>
        local sub = string.lower(parts[2] or "")
        local amt = tonumber(parts[3])
        if sub == "set" then
            if not amt or amt < 0 then
                warn("[AdminCommands] /money set requires a non-negative number amount, e.g. /money set 500")
                return
            end
            amt = math.floor(amt)
            local current = EconomyService.getMoney(plr)
            local delta = amt - current
            if delta > 0 then
                EconomyService.addMoney(plr, delta)
                print(string.format("[AdminCommands] Set %s money to %d (+%d)", plr.Name, amt, delta))
            elseif delta < 0 then
                local toRemove = -delta
                if not EconomyService.removeMoney(plr, toRemove) then
                    -- Fallback: if for any reason remove fails (shouldn't when delta<0 and balance known), clamp to 0
                    local have = EconomyService.getMoney(plr)
                    if have > 0 then EconomyService.removeMoney(plr, have) end
                end
                print(string.format("[AdminCommands] Set %s money to %d (-%d)", plr.Name, amt, toRemove))
            else
                print(string.format("[AdminCommands] %s already has %d coins", plr.Name, amt))
            end
        else
            warn("[AdminCommands] /money supports: set <amount>")
        end
    elseif cmd == "arena" then
        -- Usage: /arena <start|pause|resume|victory|door|state>
        local subCmd = string.lower(parts[2] or "")
        if subCmd == "start" then
            local ok = ArenaManager.start()
            print("[AdminCommands] Arena start:", ok)
        elseif subCmd == "pause" then
            local ok = ArenaManager.pause()
            print("[AdminCommands] Arena pause:", ok)
        elseif subCmd == "resume" then
            local ok = ArenaManager.resume()
            print("[AdminCommands] Arena resume:", ok)
        elseif subCmd == "victory" then
            local ok = ArenaManager.victory()
            print("[AdminCommands] Arena victory:", ok)
        elseif subCmd == "door" or subCmd == "opendoor" then
            -- Open the Egypt door directly (ensure initialized)
            local ok, EgyptDoor = pcall(function()
                return require(script.Parent.Parent.events.EgyptDoor)
            end)
            if ok and EgyptDoor then
                pcall(function()
                    EgyptDoor.init()
                end)
                local success = pcall(function()
                    EgyptDoor.openDoor()
                end)
                print("[AdminCommands] Arena openEgyptDoor:", success)
            else
                warn("[AdminCommands] Could not require EgyptDoor module")
            end
        elseif subCmd == "state" then
            local st = ArenaManager.getState()
            print("[AdminCommands] Arena state:", st)
        elseif subCmd == "tp" or subCmd == "teleport" then
            local ok = ArenaManager.teleportPlayerToArena(plr)
            print("[AdminCommands] Arena tp:", ok)
        else
            warn("[AdminCommands] /arena supports: start | pause | resume | victory | door | state | tp")
        end
    elseif cmd == "door" or cmd == "egyptdoor" or cmd == "opendoor" or cmd == "closedoor" then
        -- Usage:
        --   /door open
        --   /door close
        --   /door state
        --   /door init
        -- Shorthands:
        --   /opendoor, /closedoor
        local function withDoor(handler)
            local okReq, EgyptDoor = pcall(function()
                return require(script.Parent.Parent.events.EgyptDoor)
            end)
            if not okReq or not EgyptDoor then
                warn("[AdminCommands] Could not require EgyptDoor module")
                return
            end
            -- Ensure initialized (idempotent)
            local okInit = true
            if EgyptDoor.getDoorPart() == nil then
                okInit = pcall(function()
                    EgyptDoor.init()
                end)
            end
            if not okInit then
                warn("[AdminCommands] EgyptDoor.init() failed")
                return
            end
            handler(EgyptDoor)
        end

        local sub = string.lower(parts[2] or "")
        if cmd == "opendoor" then sub = "open" end
        if cmd == "closedoor" then sub = "close" end

        if sub == "open" or sub == "" then
            withDoor(function(EgyptDoor)
                local ok = pcall(function()
                    EgyptDoor.openDoor()
                end)
                print("[AdminCommands] Door open:", ok)
            end)
        elseif sub == "close" then
            withDoor(function(EgyptDoor)
                local ok = pcall(function()
                    EgyptDoor.closeDoor()
                end)
                print("[AdminCommands] Door close:", ok)
            end)
        elseif sub == "state" then
            withDoor(function(EgyptDoor)
                local st = "unknown"
                local ok = pcall(function()
                    st = EgyptDoor.getDoorState()
                end)
                print("[AdminCommands] Door state:", ok and st or "error")
            end)
        elseif sub == "init" then
            withDoor(function(EgyptDoor)
                local ok = pcall(function()
                    EgyptDoor.init()
                end)
                print("[AdminCommands] Door init:", ok)
            end)
        else
            warn("[AdminCommands] /door supports: open | close | state | init")
        end
    elseif cmd == "adminui" or cmd == "ui" then
        -- Toggle admin UI visibility
        local toggleRemote = ReplicatedStorage.Remotes.Admin:FindFirstChild("AdminUIToggle")
        if toggleRemote then
            toggleRemote:FireClient(plr)
            print("[AdminCommands] Toggled admin UI for", plr.Name)
        else
            warn("[AdminCommands] AdminUIToggle RemoteEvent not found")
        end
    elseif cmd == "uishow" or cmd == "uihide" or cmd == "uitoggle" then
        -- Hide/show all UI (CoreGui + ScreenGuis) on the client
        -- Map command to mode string for client handler
        local mode = "toggle"
        if cmd == "uishow" then mode = "on" end
        if cmd == "uihide" then mode = "off" end

        -- Ensure the HideAllUI RemoteEvent exists under ReplicatedStorage.Remotes.Admin
        local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
        local adminFolder = remotesFolder and remotesFolder:FindFirstChild("Admin")
        if not adminFolder then
            warn("[AdminCommands] Remotes.Admin folder not found; cannot toggle UI")
            return
        end
        local hideAllUI = adminFolder:FindFirstChild("HideAllUI")
        if not hideAllUI then
            hideAllUI = Instance.new("RemoteEvent")
            hideAllUI.Name = "HideAllUI"
            hideAllUI.Parent = adminFolder
        end

        hideAllUI:FireClient(plr, mode)
        print(string.format("[AdminCommands] UI %s for %s", mode, plr.Name))
    end
end

---------------------------------------------------------------------
-- CLEANUP ----------------------------------------------------------
---------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(plr)
    disableFly(plr)
disableNoclip(plr)
    removeGodMode(plr)
    state[plr] = nil
end)

return AdminCommands
