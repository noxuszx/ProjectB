-- src/server/food/CookingSurfaceCorpseHandler.server.lua
-- Destroys ragdolled humanoid enemy corpses that touch COOKING_SURFACE parts
-- Keeps server authority while leveraging client-owned physics for responsive contacts

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)
local SoundPlayer = require(ReplicatedStorage.Shared.modules.SoundPlayer)

local DEBUG = false

local modelDebounce = setmetatable({}, { __mode = "k" })
local CONFIRM_DELAY = 0.25

local function resolveTopModel(part)
	if not part then
		return nil
	end
	return part:FindFirstAncestorOfClass("Model")
end

local function isHumanoidCorpse(model)
	if not model or not model.Parent then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	-- Exclude player characters
	if game.Players:GetPlayerFromCharacter(model) then
		return false
	end
	-- Exclude villagers by CreatureType naming convention
	local ctype = model:GetAttribute("CreatureType")
	if ctype and string.find(ctype, "Villager") then
		return false
	end
	local ragdolled = model:GetAttribute("Ragdolled")
	local isDead = model:GetAttribute("IsDead") or (hum.Health <= 0)
	return (ragdolled or isDead)
end

local function stillTouchingSurface(model)
	if not model or not model.PrimaryPart then
		return false
	end
	local touching = model.PrimaryPart:GetTouchingParts()
	for _, p in ipairs(touching) do
		if
			CollectionService:HasTag(p, CollectionServiceTags.COOKING_SURFACE)
			or (p.Parent and CollectionService:HasTag(p.Parent, CollectionServiceTags.COOKING_SURFACE))
		then
			return true
		end
	end
	return false
end

local function onSurfaceTouched(surface, hit)
	local model = resolveTopModel(hit)
	if not model then
		return
	end
	if not isHumanoidCorpse(model) then
		return
	end

	local last = modelDebounce[model]
	local now = os.clock()
	if last and now - last < EconomyConfig.Performance.TouchDebounceTime then
		return
	end
	modelDebounce[model] = now

	pcall(function()
		SoundPlayer.playAt("corpse.burn_start", surface, {
			volume = 0.6,
			rolloff = { min = 8, max = 40, emitter = 5 },
		})
	end)

	task.delay(CONFIRM_DELAY, function()
		if not model or not model.Parent then
			return
		end
		if stillTouchingSurface(model) and isHumanoidCorpse(model) then
			if DEBUG then
				print("[CookingSurfaceCorpseHandler] Destroying corpse:", model.Name)
			end
			pcall(function()
				model:Destroy()
			end)
		end
	end)
end

local function connectSurface(part)
	if not (part:IsA("BasePart")) then
		return
	end
	part.Touched:Connect(function(hit)
		onSurfaceTouched(part, hit)
	end)
end

local function init()
	for _, surf in ipairs(CollectionServiceTags.getLiveTagged(CollectionServiceTags.COOKING_SURFACE)) do
		local host = surf
		if not host:IsA("BasePart") then
			host = surf:FindFirstChildWhichIsA("BasePart", true)
		end
		if host then
			connectSurface(host)
		end
	end
	-- Listen for future surfaces
	CollectionService:GetInstanceAddedSignal(CollectionServiceTags.COOKING_SURFACE):Connect(function(inst)
		local host = inst
		if not host:IsA("BasePart") then
			host = inst:FindFirstChildWhichIsA("BasePart", true)
		end
		if host then
			connectSurface(host)
		end
	end)
end

init()
