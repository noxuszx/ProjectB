-- Bandage.server.lua
-- Minimal, reliable bandage: optional short use time, no UI. Mobile-friendly.
-- Place this script inside the Bandage Tool.

local Players = game:GetService("Players")
local Tool = script.Parent

pcall(function()
	Tool.RequiresHandle = false
end)

local DEFAULTS = {
	HealAmount = 20, 
	UseTime    = 1.0,
	Cooldown   = 0.5,
}

local function getNumberAttribute(instance, name, fallback)
	local v = instance:GetAttribute(name)
	return typeof(v) == "number" and v or fallback
end

local function readConfig()
	return {
		HealAmount = getNumberAttribute(Tool, "HealAmount", DEFAULTS.HealAmount),
		UseTime = getNumberAttribute(Tool, "UseTime", DEFAULTS.UseTime),
		Cooldown = getNumberAttribute(Tool, "Cooldown", DEFAULTS.Cooldown),
	}
end

local Controller = {
	isUsing = false,
	lastUse = 0,
}

local function getHumanoid(player)
	local char = player and player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function canUse(player)
	local hum = getHumanoid(player)
	if not hum then
		return false
	end
	if hum.Health <= 0 then
		return false
	end
	if hum.Health >= hum.MaxHealth then
		return false
	end
	return true
end

local function applyHeal(player, amount)
	local hum = getHumanoid(player)
	if not hum then
		return false
	end
	local missing = math.max(0, hum.MaxHealth - hum.Health)
	local toApply = math.min(amount, missing)
	if toApply <= 0 then
		return false
	end
	hum.Health = math.min(hum.MaxHealth, hum.Health + toApply)
	return true
end

local function markUseComplete()
	Tool:SetAttribute("UseComplete", os.clock())
end

local function performUse(player)
	local cfg = readConfig()

	if Controller.isUsing then
		return markUseComplete()
	end
	if os.clock() - Controller.lastUse < cfg.Cooldown then
		return markUseComplete()
	end
	if not canUse(player) then
		return markUseComplete()
	end

	Controller.isUsing = true
	Controller.lastUse = os.clock()

	local startTime = os.clock()
	local useTime = cfg.UseTime
	while useTime > 0 and (os.clock() - startTime) < useTime do
		if Tool.Parent == nil then
			Controller.isUsing = false
			break
		end
		if not canUse(player) then
			Controller.isUsing = false
			break
		end
		task.wait(0.05)
	end

	if Controller.isUsing and canUse(player) then
		local ok = applyHeal(player, cfg.HealAmount)
		markUseComplete()
		if ok then
			task.defer(function()
				Tool:Destroy()
			end)
		end
	else
		markUseComplete()
	end

	Controller.isUsing = false
end

Tool.Activated:Connect(function()
	local player = Players:GetPlayerFromCharacter(Tool.Parent)
	if player then
		performUse(player)
	end
end)

Tool.Deactivated:Connect(function()
	if Controller.isUsing then
		Controller.isUsing = false
	end
end)

Tool.Unequipped:Connect(function()
	if Controller.isUsing then
		Controller.isUsing = false
	end
end)
