-- One-time script to update existing creatures to hide default UI

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

		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") then
				local humanoid = child:FindFirstChild("Humanoid")
				if humanoid then
					hideCreatureUI(humanoid)
				end
			end
		end
	end
end

for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("Model") and child:FindFirstChild("Humanoid") then
		local humanoid = child:FindFirstChild("Humanoid")
		hideCreatureUI(humanoid)
	end
end

script:Destroy()
