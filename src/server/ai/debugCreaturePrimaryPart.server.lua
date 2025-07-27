-- Debug script to help diagnose and fix PrimaryPart issues with AI creatures
-- Run this script in ServerScriptService to check your creature models

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreatureSpawner = require(script.Parent.creatureSpawner)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

print("=== AI Creature PrimaryPart Debug Tool ===")
print("This script will help you diagnose and fix PrimaryPart issues with your creature models.")
print("")

-- Wait a moment for everything to load
task.wait(2)

print("1. Running diagnostics...")
CreatureSpawner.diagnosePrimaryPartIssues()

print("")
print("2. Attempting to fix PrimaryPart issues...")
CreatureSpawner.fixPrimaryPartIssues()

print("")
print("3. Running diagnostics again to verify fixes...")
CreatureSpawner.diagnosePrimaryPartIssues()

print("")
print("4. Checking creature tagging status...")
local function checkCreatureTagging()
	local creatureFolders = {"SpawnedCreatures", "PassiveCreatures", "HostileCreatures"}
	for _, folderName in pairs(creatureFolders) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			print("Checking " .. folderName .. ":")
			for _, model in pairs(folder:GetChildren()) do
				if model:IsA("Model") then
					local isDraggable = CollectionServiceTags.isDraggable(model)
					local hasNonDraggableTag = CollectionServiceTags.hasTag(model, CollectionServiceTags.NON_DRAGGABLE)
					print("  " .. model.Name .. ": Draggable=" .. tostring(isDraggable) .. ", NonDraggableTag=" .. tostring(hasNonDraggableTag))

					-- Check a few body parts
					local bodyParts = {"HumanoidRootPart", "Torso", "Head"}
					for _, partName in ipairs(bodyParts) do
						local part = model:FindFirstChild(partName)
						if part then
							local partDraggable = CollectionServiceTags.isDraggable(part)
							local partNonDraggable = CollectionServiceTags.hasTag(part, CollectionServiceTags.NON_DRAGGABLE)
							print("    " .. partName .. ": Draggable=" .. tostring(partDraggable) .. ", NonDraggableTag=" .. tostring(partNonDraggable))
						end
					end
				end
			end
		end
	end
end

checkCreatureTagging()

print("")
print("=== Debug Complete ===")
print("If you still see issues:")
print("1. Make sure your creature models are in the correct folders:")
print("   - ReplicatedStorage/NPCs/PassiveCreatures/")
print("   - ReplicatedStorage/NPCs/HostileCreatures/")
print("2. Each model should have at least one of these parts:")
print("   - HumanoidRootPart (preferred)")
print("   - Torso or UpperTorso")
print("   - Head")
print("3. Each model should have a Humanoid object")
print("4. Model names should match the creature types in your config")
print("5. All creature parts should show 'Draggable=false' and 'NonDraggableTag=true'")
print("")
print("You can delete this script after fixing the issues.")
