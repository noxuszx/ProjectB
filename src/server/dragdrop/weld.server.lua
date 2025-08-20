local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WeldEvent = Remotes:WaitForChild("WeldAction") -- Ensure this RemoteEvent exists in the project config

-- Helpers
local function getRepPart(object: Instance): BasePart?
	if not object then return nil end
	if object:IsA("BasePart") then return object end
	if object:IsA("Model") then
		if object.PrimaryPart and object.PrimaryPart:IsA("BasePart") then return object.PrimaryPart end
		for _, d in ipairs(object:GetDescendants()) do
			if d:IsA("BasePart") then return d end
		end
	end
	return nil
end

local function isPlayerOrCreaturePart(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then return false end
	if Players:GetPlayerFromCharacter(model) then return true end
	return model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function isValidWeldTarget(part: BasePart): boolean
	if not part or not part:IsA("BasePart") then return false end
	-- "Weld to anything": allow any BasePart except player/creature parts
	if isPlayerOrCreaturePart(part) then return false end
	return true
end

local function getAssemblyRoot(part: BasePart): BasePart?
	if not part then return nil end
	return part.AssemblyRootPart or part
end

local function getAssemblyVel(part: BasePart)
	local root = getAssemblyRoot(part)
	if not root then return Vector3.zero, Vector3.zero end
	return root.AssemblyLinearVelocity or Vector3.zero, root.AssemblyAngularVelocity or Vector3.zero
end

local function nearestPlayerWithin(pos: Vector3, radius: number): Player?
	local nearest, bestD2
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char.PrimaryPart
		if root then
			local d2 = (root.Position - pos).Magnitude
			if d2 <= radius and (bestD2 == nil or d2 < bestD2) then
				nearest = plr
				bestD2 = d2
			end
		end
	end
	return nearest
end

local function setOwnerForAssembly(part: BasePart, owner: Player?)
	local root = getAssemblyRoot(part)
	if not root then return end
	pcall(function()
		root:SetNetworkOwner(owner)
	end)
end

local function adaptiveOwnershipMonitor(part: BasePart, initialOwner: Player?, opts)
	opts = opts or {}
	local windowSeconds = opts.windowSeconds or 2.0
	local hardCap = opts.hardCap or 10.0
	local linThresh = opts.linThresh or 2.0
	local angThresh = opts.angThresh or 1.0
	local settleHold = opts.settleHold or 0.2
	local proximity = opts.proximity or 50.0
	local reclaimRadius = opts.reclaimRadius or 60.0
	local swapCooldown = opts.swapCooldown or 0.75
	local pollDt = opts.pollDt or 0.08

	local root = getAssemblyRoot(part)
	if not root then return end

	local t = 0.0
	local tHard = 0.0
	local settledTimer = 0.0
	local lastSwap = -math.huge
	local currentOwner = initialOwner
	setOwnerForAssembly(root, currentOwner)

	while t < windowSeconds and tHard < hardCap do
		if not root or not root.Parent then break end
		local lin, ang = getAssemblyVel(root)
		if lin.Magnitude < linThresh and ang.Magnitude < angThresh then
			settledTimer += pollDt
		else
			settledTimer = 0.0
		end

		if settledTimer >= settleHold then
			break
		end

		local nowOwner = currentOwner
		local nearest = nearestPlayerWithin(root.Position, proximity)
		if nearest and nearest ~= currentOwner and (t - lastSwap) >= swapCooldown then
			nowOwner = nearest
			lastSwap = t
		elseif not nearest then
			-- Consider reclaim to server if no one is around within reclaimRadius for a bit
			local away = nearestPlayerWithin(root.Position, reclaimRadius)
			if not away and currentOwner ~= nil and (t - lastSwap) >= swapCooldown then
				nowOwner = nil
				lastSwap = t
			end
		end

		if nowOwner ~= currentOwner then
			currentOwner = nowOwner
			setOwnerForAssembly(root, currentOwner)
		end

		RS.Heartbeat:Wait()
		t += pollDt
		tHard += pollDt
	end

	-- Final handoff: prefer server unless a player is very close and it's still moving
	local finalOwner = nil
	local lin, ang = getAssemblyVel(root)
	if lin.Magnitude > linThresh * 1.5 then
		finalOwner = nearestPlayerWithin(root.Position, proximity)
	end
	setOwnerForAssembly(root, finalOwner)
end

local function safeLift(part: BasePart, offsetY: number)
	local root = getAssemblyRoot(part)
	if not root then return end
	local cf = root.CFrame
	-- small upward lift to avoid penetration pops
	pcall(function()
		root.CFrame = CFrame.new(cf.Position + Vector3.new(0, offsetY, 0)) * cf.Rotation
	end)
end

local function wakeAssembly(part: BasePart)
	local root = getAssemblyRoot(part)
	if not root then return end
	-- Zero angular a bit and add small downward impulse to ensure gravity takes over
	pcall(function()
		root.AssemblyAngularVelocity = root.AssemblyAngularVelocity * 0.5
		local m = root.AssemblyMass or root:GetMass()
		root:ApplyImpulse(Vector3.new(0, -m * 8, 0))
	end)
end

-- Server-side weld creation (Attach)
local function handleAttach(player: Player, a: Instance, b: Instance)
	local p0 = getRepPart(a)
	local p1 = getRepPart(b)
	if not p0 or not p1 then return end
	if p0 == p1 then return end
	if not isValidWeldTarget(p0) or not isValidWeldTarget(p1) then return end
	-- No distance restriction: allow welding across gaps; client UX usually ensures reasonable selection

	-- Prevent duplicate welds between the same parts
	for _, child in ipairs(p0:GetChildren()) do
		if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
			if (child.Part0 == p0 and child.Part1 == p1) or (child.Part0 == p1 and child.Part1 == p0) then
				return
			end
		end
	end

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = p0
	weld.Part1 = p1
	weld.Name = "DragDropWeld_" .. tostring(os.clock())
	weld.Parent = p0
end

-- Server-side weld removal (Detach)
local function handleDetach(player: Player, a: Instance, b: Instance?)
	local p0 = getRepPart(a)
	local p1 = b and getRepPart(b) or nil
	if not p0 then return end

	-- Collect welds to remove on BOTH sides to avoid stragglers
	local toRemove = {}
	local function collectOn(part: BasePart)
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
				if not p1 then
					table.insert(toRemove, child)
				else
					local other = child.Part0 == part and child.Part1 or child.Part0
					if other == p1 or other == p0 then
						table.insert(toRemove, child)
					end
				end
			end
		end
	end
	collectOn(p0)
	if p1 then collectOn(p1) end
	if #toRemove == 0 then return end

	-- Determine which assembly to lift (only the NON-anchored side)
	local r0 = p0.AssemblyRootPart or p0
	local r1 = p1 and (p1.AssemblyRootPart or p1) or nil
	local a0 = r0 and r0.Anchored
	local a1 = r1 and r1.Anchored
	local liftTarget: BasePart? = nil
	if p1 and a1 and not a0 then
		liftTarget = p0
	elseif p1 and a0 and not a1 then
		liftTarget = p1
	elseif not p1 then
		liftTarget = p0
	end
	if liftTarget then
		safeLift(liftTarget, 0.2)
	end

	for _, weld in ipairs(toRemove) do
		weld:Destroy()
	end

	-- Wake and temporarily give ownership to the moving (non-anchored) side
	local monitorTarget = p0
	if liftTarget and liftTarget ~= p0 then
		monitorTarget = liftTarget
	end
	wakeAssembly(monitorTarget)
	setOwnerForAssembly(monitorTarget, player)
	task.spawn(function()
		adaptiveOwnershipMonitor(monitorTarget, player, {
			windowSeconds = 2.0,
			hardCap = 10.0,
			linThresh = 2.0,
			angThresh = 1.0,
			settleHold = 0.2,
			proximity = 50.0,
			reclaimRadius = 60.0,
			swapCooldown = 0.75,
			pollDt = 0.08,
		})
	end)
end

WeldEvent.OnServerEvent:Connect(function(player: Player, action: string, a: Instance, b: Instance?)
	if action == "Attach" then
		handleAttach(player, a, b)
	elseif action == "Detach" then
		handleDetach(player, a, b)
	end
end)
