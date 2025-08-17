local RP = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

-- Ensure collision groups exist (safe to register repeatedly)
pcall(function()
	PhysicsService:RegisterCollisionGroup("Item")
end)
pcall(function()
	PhysicsService:RegisterCollisionGroup("player")
end)

local function setCollisionGroupDeep(root, groupName)
	if not root then
		return
	end
	if root:IsA("BasePart") then
		root.CollisionGroup = groupName
		return
	end
	if root:IsA("Model") or root:IsA("Tool") then
		for _, d in pairs(root:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CollisionGroup = groupName
			end
		end
	end
end

RP.Remotes.PickupItem.OnServerEvent:Connect(function(plr, object)
	if not object then
		return
	end

	-- Assign network ownership for responsiveness
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

	-- Server-authoritative collision group swap so items don't collide with the player while carried
	setCollisionGroupDeep(object, "Item")
end)

RP.Remotes.DropItem.OnServerEvent:Connect(function(plr, object, velocity)
	if not object then
		return
	end

	-- Apply throw velocity to an appropriate part
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

		if object and object.Parent then
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

			-- Reset collision group back to Default on the server
			setCollisionGroupDeep(object, "Default")
		end
	end)
end)
