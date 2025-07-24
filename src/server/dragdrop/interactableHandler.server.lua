local RP = game:GetService("ReplicatedStorage")

RP.Remotes.PickupItem.OnServerEvent:Connect(function(plr, object)
	if not object then return end

	-- Handle different object types for network ownership
	if object:IsA("MeshPart") or object:IsA("Part") then
		-- Direct part - set network owner
		object:SetNetworkOwner(plr)
	elseif object.PrimaryPart then
		-- Model or Tool with PrimaryPart
		object.PrimaryPart:SetNetworkOwner(plr)
	else
		-- Fallback - try to find the first BasePart
		for _, child in pairs(object:GetDescendants()) do
			if child:IsA("BasePart") then
				child:SetNetworkOwner(plr)
				break
			end
		end
	end
end)

RP.Remotes.DropItem.OnServerEvent:Connect(function(plr, object, velocity)
	if not object then return end

	-- Handle different object types for network ownership and velocity
	if object:IsA("MeshPart") or object:IsA("Part") then
		-- Direct part - reset network owner and apply velocity
		object:SetNetworkOwner(nil)
		if velocity then
			object.AssemblyLinearVelocity = velocity
		end
	elseif object.PrimaryPart then
		-- Model or Tool with PrimaryPart
		object.PrimaryPart:SetNetworkOwner(nil)
		if velocity then
			object.PrimaryPart.AssemblyLinearVelocity = velocity
		end
	else
		-- Fallback - try to find the first BasePart
		for _, child in pairs(object:GetDescendants()) do
			if child:IsA("BasePart") then
				child:SetNetworkOwner(nil)
				if velocity then
					child.AssemblyLinearVelocity = velocity
				end
				break
			end
		end
	end
end)