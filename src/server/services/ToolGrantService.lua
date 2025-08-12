-- src/server/services/ToolGrantService.lua
-- Service for granting tools to players from ReplicatedStorage templates
-- Handles tool cloning and placement in player backpacks

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ToolGrantService = {}

local toolsFolder = ReplicatedStorage:FindFirstChild("Tools")
if not toolsFolder then
	warn("[ToolGrantService] Tools folder not found in ReplicatedStorage - tool granting will fail")
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

	local toolTemplate = toolsFolder:FindFirstChild(toolName)
	if not toolTemplate then
		warn("[ToolGrantService] Tool template not found:", toolName)
		return false
	end

	if not toolTemplate:IsA("Tool") then
		warn("[ToolGrantService] Template", toolName, "is not a Tool - it's a", toolTemplate.ClassName)
		return false
	end

	local newTool = toolTemplate:Clone()
	newTool.Parent = player.Backpack

	print("[ToolGrantService] Granted", toolName, "to", player.Name)
	return true
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

print("[ToolGrantService] Initialized")
print("==================================================")

return ToolGrantService
