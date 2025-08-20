-- src/client/ui/AliveMarkers.client.lua
-- Renders a small white dot above every other alive player's head (Counter-Strike style)
-- Notes:
-- - Dots are client-only and AlwaysOnTop so you can spot players across the map
-- - You won't see your own dot
-- - Dots are hidden when a player is dead or missing a HumanoidRootPart
-- - Cleans up automatically when characters/players change

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LOCAL = Players.LocalPlayer

local DOT_NAME = "AliveDot"
local UPDATE_INTERVAL = 0.15 -- seconds; light periodic update
local STUDS_OFFSET = Vector3.new(0, 3.2, 0) -- above head
local DOT_DIAMETER_PX = 8 -- pixel diameter of the dot
local MAX_DISTANCE = 0 -- 0 = no limit; set to a number (e.g., 2000) to cull distant dots

local lastUpdate = 0

local function isAlive(character: Model?): boolean
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	-- Consider alive if health > 0 and state is not Dead
	if humanoid.Health <= 0 then return false end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Dead then return false end
	return true
end

local function ensureDot(hrp: BasePart)
	local existing = hrp:FindFirstChild(DOT_NAME)
	if existing and existing:IsA("BillboardGui") then
		return existing
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = DOT_NAME
	billboard.Adornee = hrp
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.new(0, DOT_DIAMETER_PX, 0, DOT_DIAMETER_PX)
	billboard.StudsOffset = STUDS_OFFSET
	billboard.ResetOnSpawn = false
	billboard.Enabled = true
	billboard.LightInfluence = 0 -- keep visual consistent regardless of lighting
	billboard.Parent = hrp

	local frame = Instance.new("Frame")
	frame.Name = "Dot"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- green dot
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0) -- perfect circle
	corner.Parent = frame

	-- Add a thin black outline around the dot
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	return billboard
end

local function destroyDot(hrp: BasePart)
	local existing = hrp and hrp:FindFirstChild(DOT_NAME)
	if existing and existing:IsA("BillboardGui") then
		existing:Destroy()
	end
end

local function getLocalHRP(): BasePart?
	local char = LOCAL.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function update()
	-- Rate-limit to UPDATE_INTERVAL
	local now = os.clock()
	if now - lastUpdate < UPDATE_INTERVAL then return end
	lastUpdate = now

	local myHRP = getLocalHRP()

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LOCAL then
			local character = plr.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")

			if hrp and isAlive(character) then
				-- Optional distance culling
				if MAX_DISTANCE > 0 and myHRP then
					local dist = (myHRP.Position - hrp.Position).Magnitude
					if dist > MAX_DISTANCE then
						destroyDot(hrp)
						continue
					end
				end

				local dot = ensureDot(hrp)
				-- If you want subtle distance-based transparency, enable below:
				-- if myHRP then
				-- 	local dist = (myHRP.Position - hrp.Position).Magnitude
				-- 	local t = math.clamp((dist - 100) / 600, 0, 1) -- fade from 100→700 studs
				-- 	dot.Enabled = true
				-- 	local frame = dot:FindFirstChild("Dot")
				-- 	if frame and frame:IsA("Frame") then
				-- 		frame.BackgroundTransparency = 0.2 + 0.6 * t
				-- 	end
				-- end
			else
				if hrp then destroyDot(hrp) end
			end
		end
	end
end

-- Hook updates
RunService.Heartbeat:Connect(update)

-- Cleanup when players leave
Players.PlayerRemoving:Connect(function(plr)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then destroyDot(hrp) end
end)

