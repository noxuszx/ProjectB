--[[
    WeldSystem.lua
    Handles welding/unwelding mechanics for drag and drop system
]]
--

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragDropConfig        = require(ReplicatedStorage.Shared.config.DragDropConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

-- Configuration
local DEBUG = false
-- Controlled via DragDropConfig.AllowAnchoredWeldTargets
local ALLOW_ANCHORED_TARGETS = DragDropConfig.AllowAnchoredWeldTargets == true

local WeldSystem = {}
local player     = Players.LocalPlayer
local mouse      = player:GetMouse()

-- Weld state
local hoveredObject = nil

-- Return a representative BasePart for an object (BasePart itself, Model.PrimaryPart, or first BasePart descendant)
local function getRepresentativePart(object)
	if not object then return nil end
	if object:IsA("BasePart") then return object end
	if object:IsA("Model") then
		if object.PrimaryPart then return object.PrimaryPart end
		for _, d in ipairs(object:GetDescendants()) do
			if d:IsA("BasePart") then return d end
		end
	end
	return nil
end

local function isPlayerCharacterPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if model then
		return Players:GetPlayerFromCharacter(model) ~= nil
	end
	return false
end

local function isCreaturePart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then return false end
	-- Exclude player characters; they are handled separately
	if Players:GetPlayerFromCharacter(model) then return false end
	-- Any model with a Humanoid but not a player is treated as a creature/NPC
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then return true end
	-- Also consider explicit tags if available
	if CollectionServiceTags.hasTag(model, CollectionServiceTags.ARENA_ENEMY) or
	   CollectionServiceTags.hasTag(model, CollectionServiceTags.ARENA_ANKH) then
		return true
	end
	return false
end

local function problemWeld(part)
	-- Allow welding to large anchored parts now; keep only essential safety filters
	if part.Transparency >= 1 then
		if DEBUG then print("DEBUG: Skipping invisible part:", part.Name, "Transparency:", part.Transparency) end
		return true
	end

	for _, suspiciousName in pairs(DragDropConfig.SUSPICIOUS_NAMES) do
		if part.Name:find(suspiciousName) then
			if part.Parent and part.Parent.Name == "Chunks" then
				if DEBUG then print("DEBUG: Allowing chunk part as weld target:", part.Name) end
			else
				if DEBUG then print("DEBUG: Skipping suspicious part:", part.Name) end
				return true
			end
		end
	end

	return false
end

local function isWeldableTarget(part)
	return part:IsA("BasePart")
		and part.CanCollide
		and part.CanQuery
		and (ALLOW_ANCHORED_TARGETS or not part.Anchored)
		and not problemWeld(part)
		and not isPlayerCharacterPart(part)
		and not isCreaturePart(part)
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

	local sourcePart = getRepresentativePart(sourceObject)
	if not sourcePart then return targets end

	local actuallyTouching = sourcePart:GetTouchingParts()
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
				local d = (part.Position - sourcePart.Position).Magnitude
				table.insert(targets, { part = part, distance = d, method = "touching" })
				if DEBUG then print("DEBUG: Actually touching:", part.Name, "d:", math.floor(d * 100) / 100) end
			end
		end
	end

	-- Sort by distance (closest first)
		table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)

	if DEBUG then print("DEBUG: Total targets found:", #targets) end
	return targets
end

function WeldSystem.weldObject(draggedObject, currentWeld)
	local targetObject = hoveredObject or draggedObject
	if not targetObject then
		print("No object to weld - hover over a part or drag one")
		return nil, false
	end

	local sourcePart = getRepresentativePart(targetObject)
	if not sourcePart then
		print("No weldable base part found on target object")
		return currentWeld, (currentWeld ~= nil)
	end

	local weldTargets = findWeldTargets(targetObject)

	if #weldTargets == 0 then
		print("No weldable objects found nearby - move closer to another object")
		return currentWeld, (currentWeld ~= nil)
	end

	local existingWelds = {}
	for _, child in pairs(sourcePart:GetChildren()) do
		if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
			table.insert(existingWelds, child)
		end
	end

	if #existingWelds > 0 then
		for _, weld in pairs(existingWelds) do
			local weldedPart = weld.Part0 == sourcePart and weld.Part1 or weld.Part0
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

	-- Remove any existing DragDropWelds from the target object to prevent spam
	for _, child in ipairs(sourcePart:GetChildren()) do
		if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
			child:Destroy()
		end
	end

	local weldId = os.clock() .. "_" .. math.random(1000, 9999)
	local weldName = "DragDropWeld_" .. weldId

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = sourcePart
	weld.Part1 = weldTarget
	weld.Parent = sourcePart
	weld.Name = weldName

	-- Auto-cleanup when either part is removed
	local function teardown()
		if weld.Parent then
			weld:Destroy()
		end
	end
	if weld.Part0 then
		weld.Part0.AncestryChanged:Connect(function(_, parent)
			if not parent then teardown() end
		end)
	end
	if weld.Part1 then
		weld.Part1.AncestryChanged:Connect(function(_, parent)
			if not parent then teardown() end
		end)
	end

	if DEBUG then
		print("Welded", targetObject.Name, "to", weldTarget.Name, "via", bestTarget.method, "detection")
		print("Distance:", math.floor(bestTarget.distance * 100) / 100, "studs")
	end

	if targetObject == draggedObject then
		return weld, true
	else
		return currentWeld, (currentWeld ~= nil)
	end
end
function WeldSystem.getWeldedAssembly(root, isDraggableObjectFunc)
	-- Resolve to a representative BasePart if a Model (or other instance) is passed
	local startPart = getRepresentativePart(root)
	if not startPart then return {} end

	local assembly = { startPart }
	local visited = { [startPart] = true }
	local toCheck = { startPart }

	while #toCheck > 0 do
		local currentPart = table.remove(toCheck, 1)
		if currentPart and currentPart.Parent then
			-- Follow DragDropWeld constraints from currentPart
			for _, child in pairs(currentPart:GetChildren()) do
				if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
					local otherPart = child.Part0 == currentPart and child.Part1 or child.Part0
					if otherPart and otherPart:IsA("BasePart") and not visited[otherPart] and isDraggableObjectFunc(otherPart) then
						visited[otherPart] = true
						table.insert(assembly, otherPart)
						table.insert(toCheck, otherPart)
					end
				end
			end

			-- Look nearby for directly connected DragDropWelds referencing currentPart
			for _, otherPart in pairs(workspace:GetPartBoundsInBox(currentPart.CFrame, currentPart.Size * 3)) do
				if otherPart:IsA("BasePart") and not visited[otherPart] and isDraggableObjectFunc(otherPart) then
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
