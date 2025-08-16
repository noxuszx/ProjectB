-- src/server/services/ToolGrantBinder.server.lua
-- Binds TOOL_GRANT-tagged world items with ProximityPrompts to grant tools via ToolGrantService

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local ToolGrantService = require(script.Parent.ToolGrantService)

-- Track prompt connections without attaching arbitrary fields to Instances
local promptConnections = setmetatable({}, { __mode = "k" })

local function getPrimaryBasePart(instance)
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart
		end
		return instance:FindFirstChildOfClass("BasePart")
	end
	-- Tools: return Handle
	if instance:IsA("Tool") then
		local handle = instance:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle
		end
	end
	return nil
end

local function ensurePrompt(root)
	local part = getPrimaryBasePart(root)
	if not part then
		return nil
	end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ToolGrantPrompt"
		prompt.HoldDuration = 0.3
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = part
	end
	return prompt
end

local function getToolName(inst)
	local attr = inst:GetAttribute("ToolName")
	if attr and typeof(attr) == "string" and #attr > 0 then
		return attr
	end
	return inst.Name
end

local function bindInstance(inst)
	local prompt = ensurePrompt(inst)
	if not prompt then
		return
	end

	-- If this prompt is already wired for centralized item use handling, skip binder wiring
	-- We detect this by either name (UsePrompt) or presence of a UseType attribute
	if prompt.Name == "UsePrompt" or prompt:GetAttribute("UseType") ~= nil then
		return
	end

	prompt.ActionText = "Pick up"
	prompt.ObjectText = getToolName(inst)

	-- Disconnect any previous connection we stored for this prompt
	local existingConn = promptConnections[prompt]
	if existingConn then
		existingConn:Disconnect()
		promptConnections[prompt] = nil
	end

	-- Connect and store in our map
	local conn
	conn = prompt.Triggered:Connect(function(player)
		local toolName = getToolName(inst)
		local ok = ToolGrantService.grantTool(player, toolName)
		if ok then
			-- Clean up the world instance
			inst:Destroy()
			-- Clear stored connection mapping as prompt will be destroyed soon
			promptConnections[prompt] = nil
		end
	end)
	promptConnections[prompt] = conn

	-- If the prompt leaves the game, clean up our connection map
	prompt.AncestryChanged:Connect(function(_, parent)
		if not parent then
			local c = promptConnections[prompt]
			if c then
				c:Disconnect()
				promptConnections[prompt] = nil
			end
		end
	end)
end

local function onTagged(inst)
	bindInstance(inst)
	-- Rebind if ancestry changes back into workspace (rare)
	inst.AncestryChanged:Connect(function(_, parent)
		if parent and parent:IsDescendantOf(workspace) then
			bindInstance(inst)
		end
	end)
end

local function init()
	for _, inst in ipairs(CollectionService:GetTagged(CollectionServiceTags.TOOL_GRANT)) do
		if inst:IsDescendantOf(workspace) then
			onTagged(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal(CollectionServiceTags.TOOL_GRANT):Connect(function(inst)
		if inst:IsDescendantOf(workspace) then
			onTagged(inst)
		end
	end)
end

init()

