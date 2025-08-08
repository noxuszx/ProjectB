--[[
    WeldSystem.lua
    Handles welding/unwelding mechanics for drag and drop system
]]
--

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragDropConfig        = require(ReplicatedStorage.Shared.config.DragDropConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local WeldSystem = {}
local player     = Players.LocalPlayer
local mouse      = player:GetMouse()

-- Weld state
local hoveredObject = nil

local function isPlayerCharacterPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if model then
		return Players:GetPlayerFromCharacter(model) ~= nil
	end
	return false
end

local function problemWeld(part)
	if part.Anchored and part.Size.Magnitude > 100 then
		print("DEBUG: Skipping extremely large anchored part:", part.Name, "Size:", part.Size.Magnitude)
		return true
	end

	if part.Transparency >= 1 then
		print("DEBUG: Skipping invisible part:", part.Name, "Transparency:", part.Transparency)
		return true
	end

	for _, suspiciousName in pairs(DragDropConfig.SUSPICIOUS_NAMES) do
		if part.Name:find(suspiciousName) then
			if part.Parent and part.Parent.Name == "Chunks" then
				print("DEBUG: Allowing chunk part as weld target:", part.Name)
			else
				print("DEBUG: Skipping suspicious part:", part.Name)
				return true
			end
		end
	end

	return false
end

local function isWeldableTarget(part)
	return part:IsA("BasePart")
		and part.CanCollide
		and not problemWeld(part)
		and not isPlayerCharacterPart(part)
		and CollectionServiceTags.isWeldable(part)
end

function WeldSystem.updateHoveredObject(isDragging, isDraggableObjectFunc)
	local target = mouse.Target

	if not isDragging and target and target ~= hoveredObject then
		if isDraggableObjectFunc(target) then
			hoveredObject = target
		end
	elseif not target or isDragging or (target and not isDraggableObjectFunc(target)) then
		if hoveredObject then
			hoveredObject = nil
		end
	end
end

local function findWeldTargets(sourceObject)
	local targets = {}

	local actuallyTouching = sourceObject:GetTouchingParts()
	for _, part in pairs(actuallyTouching) do
		if isWeldableTarget(part) then
			local alreadyFound = false
			for _, existing in pairs(targets) do
				if existing.part == part then
					alreadyFound = true
					break
				end
			end

			if not alreadyFound then
				table.insert(targets, { part = part, distance = 0, method = "touching" })
				print("DEBUG: Actually touching:", part.Name)
			end
		end
	end

	-- Sort by distance (closest first)
	table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)

	print("DEBUG: Total targets found:", #targets)
	return targets
end

function WeldSystem.weldObject(draggedObject, currentWeld)
	local targetObject = hoveredObject or draggedObject
	if not targetObject then
		print("No object to weld - hover over a part or drag one")
		return nil, false
	end

	local weldTargets = findWeldTargets(targetObject)

	if #weldTargets == 0 then
		print("No weldable objects found nearby - move closer to another object")
		return currentWeld, (currentWeld ~= nil)
	end

	local existingWelds = {}
	for _, child in pairs(targetObject:GetChildren()) do
		if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
			table.insert(existingWelds, child)
		end
	end

	if #existingWelds > 0 then
		for _, weld in pairs(existingWelds) do
			local weldedPart = weld.Part0 == targetObject and weld.Part1 or weld.Part0
			for _, target in pairs(weldTargets) do
				if target.part == weldedPart then
					weld:Destroy()
					print("Unwelded", targetObject.Name, "from", weldedPart.Name)
					return currentWeld, (currentWeld ~= nil)
				end
			end
		end
	end

	local bestTarget = weldTargets[1]
	local weldTarget = bestTarget.part

	local weldId = os.clock() .. "_" .. math.random(1000, 9999)
	local weldName = "DragDropWeld_" .. weldId

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = targetObject
	weld.Part1 = weldTarget
	weld.Parent = targetObject
	weld.Name = weldName

	print("Welded", targetObject.Name, "to", weldTarget.Name, "via", bestTarget.method, "detection")
	print("Distance:", math.floor(bestTarget.distance * 100) / 100, "studs")

	if targetObject == draggedObject then
		return weld, true
	else
		return currentWeld, (currentWeld ~= nil)
	end
end

function WeldSystem.getWeldedAssembly(part, isDraggableObjectFunc)
	local assembly = { part }
	local visited = { [part] = true }
	local toCheck = { part }

	while #toCheck > 0 do
		local currentPart = table.remove(toCheck, 1)

		for _, child in pairs(currentPart:GetChildren()) do
			if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
				local otherPart = child.Part0 == currentPart and child.Part1 or child.Part0
				if otherPart and not visited[otherPart] and isDraggableObjectFunc(otherPart) then
					visited[otherPart] = true
					table.insert(assembly, otherPart)
					table.insert(toCheck, otherPart)
				end
			end
		end

		for _, otherPart in pairs(workspace:GetPartBoundsInBox(currentPart.CFrame, currentPart.Size * 3)) do
			if not visited[otherPart] and isDraggableObjectFunc(otherPart) then
				for _, child in pairs(otherPart:GetChildren()) do
					if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
						local connectedPart = child.Part0 == otherPart and child.Part1 or child.Part0
						if connectedPart == currentPart then
							visited[otherPart] = true
							table.insert(assembly, otherPart)
							table.insert(toCheck, otherPart)
							break
						end
					end
				end
			end
		end
	end

	return assembly
end

function WeldSystem.getPartWelds(part)
	local welds = {}
	for _, child in pairs(part:GetChildren()) do
		if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
			table.insert(welds, child)
		end
	end
	return welds
end

function WeldSystem.getAssemblyWeldCount(assembly)
	local totalWelds = 0
	local countedWelds = {}

	for _, part in pairs(assembly) do
		for _, child in pairs(part:GetChildren()) do
			if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
				if not countedWelds[child] then
					countedWelds[child] = true
					totalWelds = totalWelds + 1
				end
			end
		end
	end

	return totalWelds
end

function WeldSystem.cleanup()
	hoveredObject = nil
end

return WeldSystem
