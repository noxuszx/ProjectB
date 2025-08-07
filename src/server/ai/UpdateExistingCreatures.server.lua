-- One-time script to update existing creatures to hide default UI
print("🔧 Updating existing creatures to hide default Roblox UI...")

local function hideCreatureUI(humanoid)
	if not humanoid then
		return
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0
end

local creatureFolders = { "SpawnedCreatures", "PassiveCreatures", "HostileCreatures" }

for _, folderName in ipairs(creatureFolders) do
	local folder = workspace:FindFirstChild(folderName)
	if folder then
		print("📁 Processing folder:", folderName)

		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") then
				local humanoid = child:FindFirstChild("Humanoid")
				if humanoid then
					hideCreatureUI(humanoid)
					print("✅ Updated UI for:", child.Name)
				end
			end
		end
	end
end

for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("Model") and child:FindFirstChild("Humanoid") then
		local humanoid = child:FindFirstChild("Humanoid")
		hideCreatureUI(humanoid)
		print("✅ Updated UI for workspace creature:", child.Name)
	end
end

print("🎉 Finished updating existing creatures!")
script:Destroy()
