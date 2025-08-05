-- LookAtPlayer.server.lua
-- Parent this Script under the NPC Model (server-side)

local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")

local npc              = script.Parent
local root             = npc:WaitForChild("HumanoidRootPart")

------------------------------------------------------------------
-- 1.  Create the constraint once
------------------------------------------------------------------
local align = Instance.new("AlignOrientation")
align.Name              = "BodyLookAt"
align.RigidityEnabled   = true          -- instant turn; set false for smooth
align.Responsiveness    = 50            -- higher = snappier
align.Mode              = Enum.OrientationAlignmentMode.OneAttachment
align.Parent            = root

local a0 = Instance.new("Attachment")
a0.Parent = root
align.Attachment0 = a0          -- this attachment is what the body rotates

------------------------------------------------------------------
-- 2.  Helper: pick the closest living player
------------------------------------------------------------------
local function getClosestPlayer()
    local closest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then
            local d = (hrp.Position - root.Position).Magnitude
            if d < minDist then
                minDist, closest = d, hrp
            end
        end
    end
    return closest  -- HumanoidRootPart of the nearest player (or nil)
end

------------------------------------------------------------------
-- 3.  Update target every frame (very cheap, one CFrame call)
------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
    local targetPart = getClosestPlayer()
    if targetPart then
        -- Face the player only on the horizontal plane (keep current Y)
        local fromPos  = root.Position
        local toPos    = Vector3.new(targetPart.Position.X, fromPos.Y, targetPart.Position.Z)
        align.CFrame   = CFrame.lookAt(fromPos, toPos)
    end
end)