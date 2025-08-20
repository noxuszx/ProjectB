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

	-- Helper to get a representative BasePart and assembly root
	local function getRepPart(obj: Instance): BasePart?
		if not obj then return nil end
		if obj:IsA("BasePart") then return obj end
		if obj:IsA("Model") then
			if obj.PrimaryPart then return obj.PrimaryPart end
			for _, d in ipairs(obj:GetDescendants()) do
				if d:IsA("BasePart") then return d end
			end
		end
		return nil
	end
	local function getRoot(part: BasePart): BasePart
		return (part and part.AssemblyRootPart) or part
	end

	-- Apply throw velocity to an appropriate part
	local rep = getRepPart(object)
	if rep and velocity then
		rep.AssemblyLinearVelocity = velocity
	end

	-- Start adaptive ownership monitor for smoother post-drop behavior
	task.spawn(function()
		local root = rep and getRoot(rep)
		if not root or not root.Parent then return end

		-- Temporarily give ownership to dropper for responsiveness
		pcall(function() root:SetNetworkOwner(plr) end)

		local RS = game:GetService("RunService")
		local Players = game:GetService("Players")

		local windowSeconds = 2.0
		local hardCap = 10.0
		local linThresh = 2.0
		local angThresh = 1.0
		local settleHold = 0.2
		local proximity = 50.0
		local reclaimRadius = 60.0
		local swapCooldown = 0.75
		local pollDt = 0.08

		local t, tHard, settledTimer, lastSwap = 0.0, 0.0, 0.0, -math.huge
		local currentOwner = plr

		local function nearestPlayerWithin(pos: Vector3, radius: number)
			local nearest, bestD
			for _, p in ipairs(Players:GetPlayers()) do
				local char = p.Character
				local r = char and char.PrimaryPart
				if r then
					local d = (r.Position - pos).Magnitude
					if d <= radius and (not bestD or d < bestD) then
						nearest, bestD = p, d
					end
				end
			end
			return nearest
		end

		while t < windowSeconds and tHard < hardCap do
			if not root or not root.Parent then break end
			local lin = root.AssemblyLinearVelocity or Vector3.zero
			local ang = root.AssemblyAngularVelocity or Vector3.zero
			if lin.Magnitude < linThresh and ang.Magnitude < angThresh then
				settledTimer += pollDt
			else
				settledTimer = 0.0
			end
			if settledTimer >= settleHold then
				break
			end

			local nowOwner = currentOwner
			local near = nearestPlayerWithin(root.Position, proximity)
			if near and near ~= currentOwner and (t - lastSwap) >= swapCooldown then
				nowOwner = near
				lastSwap = t
			elseif not near then
				local nearReclaim = nearestPlayerWithin(root.Position, reclaimRadius)
				if not nearReclaim and currentOwner ~= nil and (t - lastSwap) >= swapCooldown then
					nowOwner = nil
					lastSwap = t
				end
			end

			if nowOwner ~= currentOwner then
				currentOwner = nowOwner
				pcall(function() root:SetNetworkOwner(currentOwner) end)
			end

			RS.Heartbeat:Wait()
			t += pollDt
			tHard += pollDt
		end

		-- Final handoff: prefer server unless still moving fast near a player
		local finalOwner = nil
		local lin = root.AssemblyLinearVelocity or Vector3.zero
		if lin.Magnitude > linThresh * 1.5 then
			finalOwner = nearestPlayerWithin(root.Position, proximity)
		end
		pcall(function() root:SetNetworkOwner(finalOwner) end)

		-- Reset collision group back to Default on the server
		setCollisionGroupDeep(object, "Default")
	end)
end)
