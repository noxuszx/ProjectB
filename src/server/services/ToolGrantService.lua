-- src/server/services/ToolGrantService.lua
-- Service for granting tools to players from ReplicatedStorage templates
-- Handles tool cloning and placement in player backpacks

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SystemLoadMonitor = _G.SystemLoadMonitor or require(script.Parent.Parent.SystemLoadMonitor)

local ToolGrantService = {}

-- Tools that should be limited to one instance per player (by exact name)
local SINGLE_INSTANCE_TOOLS = {
	Spear = true,
	Katana = true,
	Crossbow = true,
	Bow = true,
	Machete = true,
	Kopesh = true,
}

-- Tools that are allowed to have multiple instances
local MULTI_INSTANCE_TOOLS = {
	Bandage = true,
	Medkit = true,
}

-- Track in-progress grants to avoid race-based duplicates
local _inProgress = {}

local toolsFolder = ReplicatedStorage:FindFirstChild("Tools")
if not toolsFolder then
	warn("[ToolGrantService] Tools folder not found in ReplicatedStorage - tool granting will fail")
end

-- Helper to check if a player already has a tool, either equipped (Character) or in Backpack
local function playerHasTool(player, toolName)
	if not player then return false end
	local character = player.Character
	if character and character:FindFirstChild(toolName) then
		return true
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack and backpack:FindFirstChild(toolName) then
		return true
	end
	return false
end

function ToolGrantService.grantTool(player, toolName)
	if not player or not toolName then
		warn("[ToolGrantService] Invalid parameters for grantTool")
		return false
	end

	if not player.Backpack then
		warn("[ToolGrantService] Player", player.Name, "has no Backpack - cannot grant tool")
		return false
	end

	if not toolsFolder then
		warn("[ToolGrantService] Tools folder not available - cannot grant", toolName)
		return false
	end

	-- Enforce duplicate policy: single-instance weapons cannot be granted twice
	local hasAlready = playerHasTool(player, toolName)
	if hasAlready then
		if SINGLE_INSTANCE_TOOLS[toolName] and not MULTI_INSTANCE_TOOLS[toolName] then
			-- Deny grant so world item remains for others
			print("[ToolGrantService] Deny grant -", player.Name, "already has single-instance tool", toolName)
			return false
		else
			-- Allow multiples for whitelisted tools (e.g., Bandage, Medkit)
			print("[ToolGrantService] Player already has", toolName, "but multiples are allowed; proceeding to grant")
		end
	end

	-- Guard against concurrent double-grants (same player+tool within this tick)
	local key = tostring(player.UserId) .. ":" .. tostring(toolName)
	if _inProgress[key] then
		print("[ToolGrantService] Skipping concurrent grant for", player.Name, toolName)
		return true
	end
	_inProgress[key] = true

	local toolTemplate = toolsFolder:FindFirstChild(toolName)
	if not toolTemplate then
		warn("[ToolGrantService] Tool template not found:", toolName)
		return false
	end

	if not toolTemplate:IsA("Tool") then
		warn("[ToolGrantService] Template", toolName, "is not a Tool - it's a", toolTemplate.ClassName)
		return false
	end

	local success = false
	local newTool
	local ok, err = pcall(function()
		newTool = toolTemplate:Clone()
		newTool.Parent = player.Backpack
		success = true
	end)

	if not ok then
		warn("[ToolGrantService] Error granting tool", toolName, "to", player.Name, ":", err)
	else
		print("[ToolGrantService] Granted", toolName, "to", player.Name)
	end

	_inProgress[key] = nil
	return success
end

function ToolGrantService.hasToolTemplate(toolName)
	if not toolsFolder or not toolName then
		return false
	end

	local template = toolsFolder:FindFirstChild(toolName)
	return template and template:IsA("Tool")
end

function ToolGrantService.getAvailableTools()
	if not toolsFolder then
		return {}
	end

	local tools = {}
	for _, item in pairs(toolsFolder:GetChildren()) do
		if item:IsA("Tool") then
			table.insert(tools, item.Name)
		end
	end

	return tools
end

SystemLoadMonitor.reportSystemLoaded("ToolSystem")

return ToolGrantService
