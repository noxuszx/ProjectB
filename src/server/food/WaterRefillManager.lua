-- WaterRefillManager.lua
-- Manages water refill points using CollectionService tags
-- Players can refill water bottles at tagged water sources

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local WaterBottleService = require(script.Parent.WaterBottleService)

local DEBUG = false

local WaterRefillManager = {}
local refillPrompts = {}

local function resolveHost(instance)
	if instance:IsA("BasePart") or instance:IsA("Attachment") then
		return instance
	end
	if instance:IsA("Model") then
		if instance.PrimaryPart then return instance.PrimaryPart end
		local bp = instance:FindFirstChildWhichIsA("BasePart", true)
		if bp then return bp end
	end
	local bp = instance:FindFirstChildWhichIsA("BasePart", true)
	return bp
end

local function createProximityPrompt(taggedInstance)
	local host = resolveHost(taggedInstance)
	if not host then
		return
	end
	if refillPrompts[host] then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WaterRefillPrompt"
	prompt.ActionText = "Refill"
	prompt.ObjectText = "Water Bottle"
	prompt.HoldDuration = 0.75
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Parent = host

	refillPrompts[host] = prompt

	prompt.Triggered:Connect(function(player)
		if DEBUG then print("[WaterRefillManager] local trigger", player and player.Name, host:GetFullName()) end
		WaterBottleService.Refill(player)
	end)
end

local function removeProximityPrompt(part)
	local prompt = refillPrompts[part]
	if prompt then
		prompt:Destroy()
		refillPrompts[part] = nil
	end
end

function WaterRefillManager.init()
	if not _G.__WaterBottleServiceInit then
		_G.__WaterBottleServiceInit = true
		WaterBottleService.Init()
	end
	local taggedParts = CollectionService:GetTagged(CollectionServiceTags.WATER_REFILL_SOURCE)
	for _, part in pairs(taggedParts) do
		createProximityPrompt(part)
	end

	CollectionService:GetInstanceAddedSignal(CollectionServiceTags.WATER_REFILL_SOURCE):Connect(function(inst)
		createProximityPrompt(inst)
	end)
	CollectionService:GetInstanceRemovedSignal(CollectionServiceTags.WATER_REFILL_SOURCE):Connect(function(inst)
		removeProximityPrompt(inst)
		local host = (function()
			if inst:IsA("BasePart") then return inst end
			local h = inst:FindFirstChildWhichIsA("BasePart", true)
			return h
		end)()
		if host then removeProximityPrompt(host) end
	end)

	-- Global fallback (silent by default)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt and prompt.Name == "WaterRefillPrompt" then
			if DEBUG then print("[WaterRefillManager] global trigger", player and player.Name, prompt.Parent and prompt.Parent:GetFullName()) end
			WaterBottleService.Refill(player)
		end
	end)

	return true
end

function WaterRefillManager.shutdown()
	for part, prompt in pairs(refillPrompts) do
		prompt:Destroy()
	end
	refillPrompts = {}
end

return WaterRefillManager
