-- src/server/ai/audio/SFXManager.lua
-- Centralized creature SFX manager (no AI edits required)
-- Usage: SFXManager.setupForModel(model)
-- It wires Hurt, Death, and Aggro (when possible) based on model type and available sounds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AIConfigOk, AIConfig = pcall(function()
	return require(ReplicatedStorage.Shared.config.ai.AIConfig)
end)

local SFXManager = {}
SFXManager.__index = SFXManager

-- Which creatures get which events managed by default
local DefaultRules = {
	Villager1 = { hurt = true, death = true, aggro = false },
	Villager2 = { hurt = true, death = true, aggro = false },
	Villager3 = { hurt = true, death = true, aggro = false },
	Villager4 = { hurt = true, death = true, aggro = false },
	SkeletonArcher = { hurt = true, death = true, aggro = true }, -- aggro via detect animation
	Mummy = { hurt = true, death = true, aggro = true },          -- aggro via attribute trigger
	Skeleton = { hurt = true, death = true, aggro = false },
	TowerSkeleton = { hurt = true, death = true, aggro = false },
	TowerMummy = { hurt = true, death = true, aggro = true },     -- aggro via attribute trigger
}

-- Name tokens to find sounds for each event (case-insensitive)
local SoundNameTokens = {
	hurt = { "hurt", "pain" },
	death = { "death", "die" },
	aggro = { "aggro", "alert", "detect" },
	attack = { "attack", "swing", "shoot" },
}

-- Cooldowns (seconds) to prevent spam
-- Tuned for more realistic barks: less frequent hurt/aggro, death always allowed
local Cooldowns = {
	hurt = 1.2,   -- was 0.35
	death = 0.0,  -- no cooldown; death SFX must never be blocked
	aggro = 5.0,  -- was 1.0
	attack = 0.25,
}

local function lower(s)
	return string.lower(s)
end

-- Find sounds in common places under the model
local function collectSounds(model, eventName)
	local tokens = SoundNameTokens[eventName]
	if not tokens then return {} end
	local out = {}
	local function consider(container)
		if not container then return end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Sound") then
				local n = lower(child.Name)
				-- Allow exact canonical names too (e.g., "Hurt")
				local matched = false
				for _, t in ipairs(tokens) do
					if string.find(n, t, 1, true) or n == t then
						matched = true
						break
					end
				end
				if matched then table.insert(out, child) end
			elseif child:IsA("Attachment") then
				for _, s in ipairs(child:GetChildren()) do
					if s:IsA("Sound") then
						local n = lower(s.Name)
						for _, t in ipairs(tokens) do
							if string.find(n, t, 1, true) or n == t then
								table.insert(out, s)
								break
							end
						end
					end
				end
			end
		end
	end
	
	-- Search model and typical nodes
	consider(model)
	consider(model:FindFirstChild("Head"))
	consider(model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	consider(model:FindFirstChild("Sounds"))
	return out
end

local function pickAndPlay(model, eventName)
	local now = os.clock()
	local cd = Cooldowns[eventName]
	local attrName = "SFX_" .. eventName .. "_Last"
	local last = model:GetAttribute(attrName) or 0

	-- Never gate death by cooldown; always allow
	if eventName ~= "death" then
		cd = cd ~= nil and cd or 0.3
		if now - last < cd then return end
	end

	local pool = collectSounds(model, eventName)
	if #pool == 0 then return end
	local s = pool[math.random(1, #pool)]
	local ok = pcall(function()
		-- add slight pitch variance if default
		if s.PlaybackSpeed == 0 or s.PlaybackSpeed == nil then
			s.PlaybackSpeed = 1 + (math.random() - 0.5) * 0.12
		end
		s:Play()
	end)
	if ok then
		model:SetAttribute(attrName, now)
	end
end

local function getCreatureType(model)
	return (model:GetAttribute("CreatureType")) or model.Name
end

local function getRulesFor(model)
	local t = getCreatureType(model)
	local rules = DefaultRules[t]
	-- Fallback: any non-player humanoid gets basic hurt/death handling
	if rules == nil then
		return { hurt = true, death = true, aggro = false }
	end
	return rules
end

local function ensureOnce(model, key)
	local flag = "SFX_Bound_" .. key
	if model:GetAttribute(flag) then return false end
	model:SetAttribute(flag, true)
	return true
end

-- Wire up humanoid-based events (hurt, death)
local function bindHumanoidSignals(model, rules)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if not ensureOnce(model, "Humanoid") then return end

	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(h)
		if h < lastHealth and h > 0 and rules.hurt then
			pickAndPlay(model, "hurt")
		end
		lastHealth = h
	end)

	humanoid.Died:Connect(function()
		if rules.death then
			pickAndPlay(model, "death")
		end
	end)
end

-- For creatures that have a detect AnimationId in config (e.g., SkeletonArcher),
-- play aggro when that animation is played.
local function bindAggroViaDetectAnimation(model, rules)
	if not rules.aggro then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if not ensureOnce(model, "AggroDetect") then return end

	local ctype = getCreatureType(model)
	local detectAnimId = nil
	if AIConfigOk and AIConfig and AIConfig.CreatureTypes and AIConfig.CreatureTypes[ctype] then
		detectAnimId = AIConfig.CreatureTypes[ctype].AnimationId
	end
	if not detectAnimId then return end

	-- Prefer Animator.AnimationPlayed, fallback to Humanoid.AnimationPlayed
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local function onAnimPlayed(track)
		local anim = track and track.Animation
		if anim and anim.AnimationId == detectAnimId then
			pickAndPlay(model, "aggro")
		end
	end
	if animator and animator.AnimationPlayed then
		animator.AnimationPlayed:Connect(onAnimPlayed)
	elseif humanoid.AnimationPlayed then
		humanoid.AnimationPlayed:Connect(onAnimPlayed)
	end
end

-- Attribute-based aggro trigger: play aggro when model's AggroTick changes
local function bindAggroViaAttribute(model, rules)
	if not rules.aggro then return end
	if not ensureOnce(model, "AggroAttr") then return end
	model:GetAttributeChangedSignal("AggroTick"):Connect(function()
		pickAndPlay(model, "aggro")
	end)
end

function SFXManager.setupForModel(model)
	if not model or not model:IsA("Model") then return end
	local rules = getRulesFor(model)
	if not rules then return end
	bindHumanoidSignals(model, rules)
	bindAggroViaDetectAnimation(model, rules)
	bindAggroViaAttribute(model, rules)
end

return SFXManager

