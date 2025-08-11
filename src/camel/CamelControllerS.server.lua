-- CamelControllerS  (Server, child of CamelModel)
local Players = game:GetService("Players")

local camelModel = script.Parent
local seat = camelModel:WaitForChild("Seat")

local lastDismountTime = 0
local DISMOUNT_DEBOUNCE = 0.1

local function stopCamel()
	local humanoid = camelModel:FindFirstChild("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero, true)
		if humanoid.RootPart then
			humanoid.RootPart.AssemblyLinearVelocity = Vector3.zero
			humanoid.RootPart.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

seat:GetPropertyChangedSignal("Occupant"):Connect(function()
	local occupant = seat.Occupant
	if occupant then
		local player = Players:GetPlayerFromCharacter(occupant.Parent)
		if player then
			camelModel:SetAttribute("Mounted", true)
			local humanoid = camelModel:FindFirstChild("Humanoid")
			if humanoid then
				humanoid:Move(Vector3.zero, true)
			end
			local rootPart = humanoid and humanoid.RootPart or seat
			if rootPart then
				rootPart:SetNetworkOwner(player)
			end
			if not player:FindFirstChild("PlayerGui") then
				return
			end
			local existing = player.PlayerGui:FindFirstChild("CamelDriver")
			if existing then
				existing:Destroy()
			end
			local template = script:FindFirstChild("CamelDriver")
			if template then
				local clone = template:Clone()
				clone.Name = "CamelDriver"
				clone.Disabled = false
				clone.Parent = player.PlayerGui
			end
		end
	else
		------------------------------------------------------------------
		--  DISMOUNT
		------------------------------------------------------------------
		local currentTime = os.clock()
		if currentTime - lastDismountTime < DISMOUNT_DEBOUNCE then
			return
		end
		lastDismountTime = currentTime

		task.defer(function()
			-- clear mounted flag to resume AI
			camelModel:SetAttribute("Mounted", false)

			stopCamel()
			-- return ownership to server (root assembly only)
			local humanoid = camelModel:FindFirstChild("Humanoid")
			local rootPart = humanoid and humanoid.RootPart or seat
			if rootPart then
				rootPart:SetNetworkOwner(nil)
			end
		end)
	end
end)
