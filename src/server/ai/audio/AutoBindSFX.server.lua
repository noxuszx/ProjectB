-- src/server/ai/audio/AutoBindSFX.server.lua
-- Automatically binds SFX logic to NPC models as they spawn/are created.
-- Looks for humanoid models under Workspace and server spawner outputs.

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SFXManager = require(script.Parent.SFXManager)

local function tryBind(model)
	if not model or not model:IsA("Model") then return end
	-- Skip player characters
	if Players:GetPlayerFromCharacter(model) then return end
	-- Heuristic: requires a Humanoid to be an NPC.
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	-- Must have either a Head or a HumanoidRootPart to emit 3D sound.
	if not (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) then return end
	SFXManager.setupForModel(model)
end

-- If a Humanoid gets added after the Model, bind then
local function onDescendantAdded(inst)
	if inst:IsA("Humanoid") then
		local parentModel = inst.Parent
		if parentModel and parentModel:IsA("Model") then
			tryBind(parentModel)
		end
	end
end

-- Bind existing models (in case some are placed directly)
for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("Model") then
		tryBind(descendant)
	elseif descendant:IsA("Humanoid") then
		onDescendantAdded(descendant)
	end
end

-- Bind future models and humanoids
Workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") then
		tryBind(inst)
	elseif inst:IsA("Humanoid") then
		onDescendantAdded(inst)
	end
end)

