-- src/server/player/PlayerHealHandler.server.lua
-- Adds a ProximityPrompt to heal other players using Bandage or Medkit
-- Event-driven, reuses existing feedback UI and PlayerStatsManager

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStatsManager = require(script.Parent.PlayerStatsManager)

local deathRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Death")
local revivalFeedbackRemote = deathRemotes:WaitForChild("RevivalFeedback")

local HEAL_PROMPT_NAME = "HealPrompt"
local HEAL_HOLD_DURATION = 1.5
local HEAL_MAX_DISTANCE = 10
local HEAL_COOLDOWN_SECONDS = 3

local HEAL_VALUES = {
	Bandage = 25,
	Medkit = 75,
}

local function ensureHealPrompt(character, player)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (hrp and humanoid) then return end

	-- Create or reuse
	local prompt = hrp:FindFirstChild(HEAL_PROMPT_NAME)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = HEAL_PROMPT_NAME
		prompt.ActionText = "Heal Player"
		prompt.ObjectText = player.Name
		prompt.HoldDuration = HEAL_HOLD_DURATION
		prompt.MaxActivationDistance = HEAL_MAX_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.UIOffset = Vector2.new(0, -8)
		prompt.Parent = hrp
		-- Hide from the target player themselves (client visibility script respects this)
		prompt:SetAttribute("HiddenFromPlayer", player.UserId)
		print("[PlayerHeal] Created HealPrompt for", player.Name)
	end

	-- Enable prompt only if player is not full health
	local function refreshEnabled()
		local ok, maxHealth = pcall(function() return humanoid.MaxHealth end)
		local ok2, health = pcall(function() return humanoid.Health end)
		if ok and ok2 then
			-- Enable only when alive and missing health
			local healable = (health > 0 and health < maxHealth)
			prompt.Enabled = healable
			-- Mirror state as an attribute on HRP so clients can reliably reflect visibility
			hrp:SetAttribute("Healable", healable)
			-- Debug
			-- print("[PlayerHeal] Healable state:", player.Name, healable, string.format("(%.1f/%.1f)", health, maxHealth))
		end
	end
	refreshEnabled()
	-- Track health changes
	humanoid:GetPropertyChangedSignal("Health"):Connect(refreshEnabled)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refreshEnabled)
end

local function onCharacterAdded(player, character)
	-- Clear any stale cooldown from previous life
	player:SetAttribute("HealCooldownUntil", nil)
	-- Slight delay to ensure Humanoid/HRP exists
	task.defer(function()
		if character.Parent == nil then return end
		ensureHealPrompt(character, player)
	end)
end

local function findHealerConsumable(player)
	-- return toolName string and the tool instance to destroy
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	local bandage = (backpack and backpack:FindFirstChild("Bandage")) or (character and character:FindFirstChild("Bandage"))
	if bandage then return "Bandage", bandage end
	local medkit = (backpack and backpack:FindFirstChild("Medkit")) or (character and character:FindFirstChild("Medkit"))
	if medkit then return "Medkit", medkit end
	-- Debug: list inventory when missing
	local backpackItems, characterItems = {}, {}
	if backpack then
		for _, ch in ipairs(backpack:GetChildren()) do table.insert(backpackItems, ch.Name .. "(" .. ch.ClassName .. ")") end
	end
	if character then
		for _, ch in ipairs(character:GetChildren()) do if ch:IsA("Tool") then table.insert(characterItems, ch.Name) end end
	end
	print("[PlayerHeal][Debug] No consumable found for", player.Name, "- Backpack:", table.concat(backpackItems, ", "), "- CharacterTools:", table.concat(characterItems, ", "))
	return nil, nil
end

local function getPromptTargetPlayer(prompt)
	local hrp = prompt and prompt.Parent
	if not (hrp and hrp:IsA("BasePart")) then return nil end
	local character = hrp.Parent
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

-- Cooldown helpers (per-target cooldown)
local function isOnHealCooldown(targetPlayer)
	local untilTs = targetPlayer:GetAttribute("HealCooldownUntil")
	if typeof(untilTs) == "number" then
		return os.clock() < untilTs
	end
	return false
end

local function setHealCooldown(targetPlayer)
	targetPlayer:SetAttribute("HealCooldownUntil", os.clock() + HEAL_COOLDOWN_SECONDS)
end

local function onPromptTriggered(prompt, healer)
	if prompt.Name ~= HEAL_PROMPT_NAME then return end
	-- Basic debounce
	if not prompt.Enabled then return end
	prompt.Enabled = false

	local target = getPromptTargetPlayer(prompt)
	if not target or target == healer then
		-- Re-enable if invalid
		if prompt.Parent then prompt.Enabled = true end
		return
	end

	-- If target already full health, disable prompt and exit silently
	local tChar = target.Character
	local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
	if not tHum or tHum.Health <= 0 then
		-- Dead/downed targets cannot be healed; hide prompt
		if prompt.Parent then prompt.Enabled = false end
		return
	end
	if tHum.Health >= tHum.MaxHealth then
		if prompt.Parent then
			prompt.Enabled = false
		end
		return
	end
	print("[PlayerHeal] Heal attempt:", healer.Name, "->", target.Name)

	if isOnHealCooldown(target) then
		print("[PlayerHeal] Target on cooldown:", target.Name)
		-- Soft-fail: re-enable without consuming item
		if prompt.Parent then prompt.Enabled = true end
		return
	end

	-- Check healer has item
	local toolName, toolInstance = findHealerConsumable(healer)
	if not toolName or not toolInstance then
		-- Feedback to healer
		revivalFeedbackRemote:FireClient(healer, "requires_healing_item")
		if prompt.Parent then prompt.Enabled = true end
		return
	end

	-- Compute amount and heal via stats manager
	local amount = HEAL_VALUES[toolName] or 25
	local ok = PlayerStatsManager.Heal(target, amount)
	-- Also adjust Roblox Humanoid health so the prompt enable logic and gameplay match
	local targetCharacter = target.Character
	local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
	if targetHumanoid then
		local newHealth = math.min(targetHumanoid.MaxHealth, targetHumanoid.Health + amount)
		targetHumanoid.Health = newHealth
		-- Update the prompt immediately based on new health
		if prompt.Parent then
			prompt.Enabled = (newHealth < targetHumanoid.MaxHealth)
		end
	end
	if ok then
		print("[PlayerHeal] Success:", healer.Name, "healed", target.Name, "with", toolName, "for", amount)
		-- Consume item
		toolInstance:Destroy()
		setHealCooldown(target)
	else
		print("[PlayerHeal] Heal failed for", healer.Name, "->", target.Name)
		-- If heal failed, re-enable prompt and do not consume
		if prompt.Parent then prompt.Enabled = true end
		return
	end

	-- Re-enable prompt after a very short delay to allow UI update
	task.delay(0.2, function()
		if prompt.Parent then
			prompt.Enabled = true
		end
	end)
end

-- Wire up services
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then onCharacterAdded(player, player.Character) end
	player.CharacterAdded:Connect(function(char) onCharacterAdded(player, char) end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char) onCharacterAdded(player, char) end)
end)

ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
