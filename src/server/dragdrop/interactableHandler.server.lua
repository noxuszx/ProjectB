local RP = game:GetService("ReplicatedStorage")

RP.Remotes.PickupItem.OnServerEvent:Connect(function(plr, object)
	if not object then return end

	if object:IsA("MeshPart") or object:IsA("Part") then
		object:SetNetworkOwner(plr)
	elseif object.PrimaryPart then
		object.PrimaryPart:SetNetworkOwner(plr)
	else
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

	if object:IsA("MeshPart") or object:IsA("Part") then
		if velocity then
			object.AssemblyLinearVelocity = velocity
		end
	elseif object.PrimaryPart then
		if velocity then
			object.PrimaryPart.AssemblyLinearVelocity = velocity
		end
	else
		for _, child in pairs(object:GetDescendants()) do
			if child:IsA("BasePart") then
				if velocity then
					child.AssemblyLinearVelocity = velocity
				end
				break
			end
		end
	end

	task.spawn(function()
		task.wait(0.5)

		if object and object.Parent then -- Check if object still exists
			if object:IsA("MeshPart") or object:IsA("Part") then
				object:SetNetworkOwner(nil)
			elseif object.PrimaryPart then
				object.PrimaryPart:SetNetworkOwner(nil)
			else
				for _, child in pairs(object:GetDescendants()) do
					if child:IsA("BasePart") then
						child:SetNetworkOwner(nil)
						break
					end
				end
			end
		end
	end)
end)