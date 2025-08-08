-- Bandage.server.lua
-- Minimal, reliable bandage: single file, optional short use time, no UI.
-- Place this script inside the Bandage Tool.

local Players = game:GetService("Players")
local Tool = script.Parent

-- Tweakables
local HEAL_AMOUNT = 20           -- How much health to restore
local DEFAULT_USE_TIME = 1.0     -- Fallback if Tool:GetAttribute("UseTime") is not set (set to 0 for instant)
local COOLDOWN = 0.5             -- Prevent spam clicking

local isUsing = false
local lastUse = 0

-- Heal the player by modifying the default Humanoid health only
local function applyHeal(player, amount)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	local before = hum.Health
	local missing = math.max(0, hum.MaxHealth - hum.Health)
	local toApply = math.min(amount, missing)
	if toApply <= 0 then
		return false
	end
	hum.Health = math.min(hum.MaxHealth, hum.Health + toApply)
	return true
end

local function canUse(player)
	if not player or not player.Character then return false end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	if hum.Health <= 0 then return false end
	if hum.Health >= hum.MaxHealth then return false end
	return true
end

local function onActivated(player)
	if isUsing then
		Tool:SetAttribute("UseComplete", os.clock())
		return
	end
	if os.clock() - lastUse < COOLDOWN then
		Tool:SetAttribute("UseComplete", os.clock())
		return
	end
	if not canUse(player) then
		Tool:SetAttribute("UseComplete", os.clock())
		return
	end

	isUsing = true
	lastUse = os.clock()

	-- Optional short use time; cancel if tool is deactivated/unequipped
	local useTime = Tool:GetAttribute("UseTime")
	if typeof(useTime) ~= "number" then
		useTime = DEFAULT_USE_TIME
	end
	local startTime = os.clock()
	while useTime > 0 and (os.clock() - startTime) < useTime do
		-- If tool got unequipped or player became invalid, cancel
		if Tool.Parent == nil then isUsing = false break end
		if not canUse(player) then isUsing = false break end
		task.wait(0.05)
	end

	if isUsing and canUse(player) then
		local ok = applyHeal(player, HEAL_AMOUNT)
		Tool:SetAttribute("UseComplete", os.clock())
		if ok then
			task.defer(function()
				Tool:Destroy()
			end)
		end
	else
		Tool:SetAttribute("UseComplete", os.clock())
	end

	isUsing = false
end

Tool.Activated:Connect(function()
	local player = Players:GetPlayerFromCharacter(Tool.Parent)
	if player then
		onActivated(player)
	end
end)

-- Cancel use if player releases or unequips during the short use time
Tool.Deactivated:Connect(function()
	if isUsing then isUsing = false end
end)

Tool.Unequipped:Connect(function()
	if isUsing then isUsing = false end
end)
