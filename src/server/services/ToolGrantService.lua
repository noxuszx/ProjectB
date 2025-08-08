-- src/server/services/ToolGrantService.lua
-- Service for granting tools to players from ReplicatedStorage templates
-- Handles tool cloning and placement in player backpacks

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ToolGrantService = {}

-- Cache the Tools folder for tool templates (Roblox Tool instances)
local toolsFolder = ReplicatedStorage:FindFirstChild("Tools")
if not toolsFolder then
	warn("[ToolGrantService] Tools folder not found in ReplicatedStorage - tool granting will fail")
end

-- Grant a tool to a player's backpack
function ToolGrantService.grantTool(player, toolName)
	if not player or not toolName then
		warn("[ToolGrantService] Invalid parameters for grantTool")
		return false
	end
	
	-- Check if player has a backpack
	if not player.Backpack then
		warn("[ToolGrantService] Player", player.Name, "has no Backpack - cannot grant tool")
		return false
	end
	
-- Find tool template in Tools folder
if not toolsFolder then
	warn("[ToolGrantService] Tools folder not available - cannot grant", toolName)
	return false
end

local toolTemplate = toolsFolder:FindFirstChild(toolName)
if not toolTemplate then
	warn("[ToolGrantService] Tool template not found:", toolName)
	return false
end
	
	-- Check if template is actually a tool (could be MeshPart, Model, etc.)
	if not toolTemplate:IsA("Tool") then
		warn("[ToolGrantService] Template", toolName, "is not a Tool - it's a", toolTemplate.ClassName)
		return false
	end
	
	-- Clone tool and give to player
	local newTool = toolTemplate:Clone()
	newTool.Parent = player.Backpack
	
	print("[ToolGrantService] Granted", toolName, "to", player.Name)
	return true
end

-- Check if a tool template exists (utility function)
function ToolGrantService.hasToolTemplate(toolName)
	if not toolsFolder or not toolName then
		return false
	end
	
	local template = toolsFolder:FindFirstChild(toolName)
	return template and template:IsA("Tool")
end

-- Get all available tool templates (for debugging/admin use)
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

print("[ToolGrantService] Initialized - Ready to grant tools to player backpacks")

return ToolGrantService