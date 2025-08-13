-- CamelControllerS  (Server, child of CamelModel)
local Players = game:GetService("Players")

local DEBUG = false
if DEBUG then print("[CamelControllerS] Script starting:", script:GetFullName()) end

local camelModel = script.Parent
if not camelModel then
	if DEBUG then warn("[CamelControllerS] script.Parent is nil") end
	return
end

-- Be flexible about the seat: support Seat or VehicleSeat anywhere under the model
local seat = camelModel:FindFirstChildOfClass("Seat") or camelModel:FindFirstChildOfClass("VehicleSeat") or camelModel:FindFirstChild("Seat")
if not seat then
	if DEBUG then warn("[CamelControllerS] No Seat or VehicleSeat found under", camelModel:GetFullName()) end
	return
end
if DEBUG then print("[CamelControllerS] Seat found:", seat:GetFullName()) end

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

if DEBUG then print("[CamelControllerS] Connecting Occupant changed") end
seat:GetPropertyChangedSignal("Occupant"):Connect(function()
	local occupant = seat.Occupant
	if DEBUG then print("[CamelControllerS] Occupant changed:", occupant and occupant.Parent and occupant.Parent.Name or "nil") end
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
				if DEBUG then print("[CamelControllerS] Network owner set to:", player.Name) end
			else
				if DEBUG then warn("[CamelControllerS] No rootPart to SetNetworkOwner") end
			end
			if not player:FindFirstChild("PlayerGui") then
				if DEBUG then warn("[CamelControllerS] PlayerGui missing for", player.Name) end
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
				if DEBUG then print("[CamelControllerS] Inserted CamelDriver into PlayerGui for", player.Name) end
			else
				if DEBUG then warn("[CamelControllerS] Missing CamelDriver template under server script") end
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
				if DEBUG then print("[CamelControllerS] Network owner cleared (server)") end
			else
				warn("[CamelControllerS] No rootPart to clear NetworkOwner")
			end
		end)
	end
end)
