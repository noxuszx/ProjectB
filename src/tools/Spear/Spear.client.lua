-- LocalScript inside the Tool
local tool = script.Parent
local player = game:GetService("Players").LocalPlayer

----------------------------------------------------------
-- When the tool is equipped, make the R6 slash possible
----------------------------------------------------------
tool.Equipped:Connect(function()
	-- Only needed for R6; harmless for R15.
	local slashSignal = Instance.new("StringValue")
	slashSignal.Name  = "toolanim"
	slashSignal.Value = "Slash"
	slashSignal.Parent = tool
end)

----------------------------------------------------------
-- On click: play slash + tell server to damage
----------------------------------------------------------
tool.Activated:Connect(function()
	local character = player.Character
	if not character then return end

	-- 1) Let the engine run the default R6 slash
	local slashSignal = tool:FindFirstChild("toolanim")
	if not slashSignal then
		slashSignal = Instance.new("StringValue")
		slashSignal.Name  = "toolanim"
		slashSignal.Value = "Slash"
		slashSignal.Parent = tool
	end

	-- 2) Simple raycast to get what we hit
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local ray = Ray.new(rootPart.Position, rootPart.CFrame.LookVector * 15)
	local part, pos = workspace:FindPartOnRay(ray, character)
	if not part then 
		print("[Spear] No part hit by raycast")
		return 
	end

	print("[Spear] Hit part: " .. part.Name .. " (" .. part.ClassName .. ")")
	print("[Spear] Part parent: " .. tostring(part.Parent and part.Parent.Name))

	local targetModel = part:FindFirstAncestorOfClass("Model")
	if not targetModel then 
		print("[Spear] No model found for hit part")
		return 
	end

	print("[Spear] Found target model: " .. targetModel.Name)
	print("[Spear] Model parent: " .. tostring(targetModel.Parent))

	-- 3) Tell the server to deal 20 damage
	local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("WeaponDamage")
	if remote then
		print("[Spear] Firing WeaponDamage event to server")
		remote:FireServer(targetModel, 20)
	else
		print("[Spear] WeaponDamage remote not found!")
	end
end)