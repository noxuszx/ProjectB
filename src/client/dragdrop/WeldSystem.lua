--[[
    WeldSystem.lua
    Handles welding/unwelding mechanics for drag and drop system
]]
--

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragDropConfig        = require(ReplicatedStorage.Shared.config.DragDropConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local SoundPlayer           = require(ReplicatedStorage.Shared.modules.SoundPlayer)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WeldEvent = Remotes:WaitForChild("WeldAction")

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
	-- "Weld to anything": allow any BasePart except player/creature parts.
	-- Anchored targets are allowed.
	return part and part:IsA("BasePart")
		and not isPlayerCharacterPart(part)
		and not isCreaturePart(part)
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

	-- Fallback: allow welding to whatever is under the cursor within a reasonable range
	local cursorTarget = mouse.Target
	if cursorTarget and cursorTarget:IsA("BasePart") and isWeldableTarget(cursorTarget) then
		local alreadyFound = false
		for _, existing in pairs(targets) do
			if existing.part == cursorTarget then
				alreadyFound = true
				break
			end
		end
		if not alreadyFound then
			local d = (cursorTarget.Position - sourcePart.Position).Magnitude
			-- No distance limit: if user points at it, let them weld it
			table.insert(targets, { part = cursorTarget, distance = d, method = "cursor" })
			if DEBUG then print("DEBUG: Cursor fallback target:", cursorTarget.Name, "d:", math.floor(d * 100) / 100) end
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

	-- If already welded to anything and player hits weld again, request Detach on server
	local foundDragDropWeld = nil
	local weldedPartner = nil
	-- Search on the representative part first
	for _, child in pairs(sourcePart:GetChildren()) do
		if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
			foundDragDropWeld = child
			weldedPartner = (child.Part0 == sourcePart) and child.Part1 or child.Part0
			break
		end
	end
	-- If not found and the target is a Model, search its BasePart descendants
	if not foundDragDropWeld and targetObject and targetObject:IsA("Model") then
		for _, d in ipairs(targetObject:GetDescendants()) do
			if d:IsA("BasePart") then
				for _, child in ipairs(d:GetChildren()) do
					if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
						foundDragDropWeld = child
						weldedPartner = (child.Part0 == d) and child.Part1 or child.Part0
						break
					end
				end
				if foundDragDropWeld then break end
			end
		end
	end
	if foundDragDropWeld and weldedPartner then
		WeldEvent:FireServer("Detach", foundDragDropWeld.Part0, foundDragDropWeld.Part1)
		pcall(function()
			SoundPlayer.playAt("weld.detach", sourcePart, { volume = 0.6 })
		end)
		return currentWeld, (currentWeld ~= nil)
	end

	-- Otherwise Attach to the best target (closest)
	local bestTarget = weldTargets[1]
	local weldTarget = bestTarget.part
	WeldEvent:FireServer("Attach", sourcePart, weldTarget)
	pcall(function()
		SoundPlayer.playAt("weld.attach", sourcePart, { volume = 0.6, rolloff = { min = 6, max = 50, emitter = 5 } })
	end)

	-- We no longer return a client weld instance; server will replicate the authoritative weld
	return currentWeld, (currentWeld ~= nil)
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
