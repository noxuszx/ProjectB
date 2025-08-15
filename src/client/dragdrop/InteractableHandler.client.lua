local RS  = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RP  = game:GetService("ReplicatedStorage")

local CS_tags 	 = require(RP.Shared.utilities.CollectionServiceTags)
local WeldSystem = require(script.Parent.WeldSystem)

local player 	  = game.Players.LocalPlayer
local camera 	  = workspace.CurrentCamera

local isMobile    = true
local currTargs   = nil
local carrying 	  = false
local currentWeld = nil

local highlight = Instance.new("Highlight")
highlight.Name = "DragDropHighlight"
highlight.FillColor = Color3.fromRGB(0, 162, 255)
highlight.OutlineColor = Color3.fromRGB(0, 162, 255)
highlight.FillTransparency = 0.8
highlight.OutlineTransparency = 0.2

local currentRotationAxis = 1
local rotationCount = { 0, 0, 0 }
local originalCFrame = nil
local rotationStep = math.rad(15)

local function showWeldFeedback(message, duration)
	print("[WeldSystem]", message)
end

local function hasAnchoredParts(object)
	local partToCheck = nil

	if object:IsA("BasePart") then
		partToCheck = object
	elseif object.PrimaryPart then
		partToCheck = object.PrimaryPart
	else
		for _, descendant in pairs(object:GetDescendants()) do
			if descendant:IsA("BasePart") then
				partToCheck = descendant
				break
			end
		end
	end

	if partToCheck and partToCheck.AssemblyRootPart then
		return partToCheck.AssemblyRootPart.Anchored
	end

	return false
end

local function getCurrentRotation()
	local xRotation = CFrame.Angles(rotationCount[1] * rotationStep, 0, 0)
	local yRotation = CFrame.Angles(0, rotationCount[2] * rotationStep, 0)
	local zRotation = CFrame.Angles(0, 0, rotationCount[3] * rotationStep)

	-- Apply rotations in order: X, then Y, then Z
	return xRotation * yRotation * zRotation
end

local range = 12
local carryDistance = 9
local carryDist = 20
local carrySmooth = 0.06
local throwBoost = 8
local lastVelo = Vector3.new()
local targetPos = nil

-- Track temporary physics adjustments for carried character models
local originalMassless = {}
local originalProps = {}

local function setAssemblyMassless(rootModel: Model, isMassless: boolean)
	if not rootModel or not rootModel:IsA("Model") then return end
	for _, d in ipairs(rootModel:GetDescendants()) do
		if d:IsA("BasePart") then
			if isMassless then
				-- store original once
				if originalMassless[d] == nil then
					originalMassless[d] = d.Massless
				end
				d.Massless = true
				-- apply lighter custom physics similar to NPC handling
				if originalProps[d] == nil then
					originalProps[d] = d.CustomPhysicalProperties -- may be nil (use engine default)
				end
				d.CustomPhysicalProperties = PhysicalProperties.new(0.05, 0.2, 0, 0.5, 1)
			else
				-- restore if we have stored state
				if originalMassless[d] ~= nil then
					d.Massless = originalMassless[d]
					originalMassless[d] = nil
				else
					-- default restore
					d.Massless = false
				end
				-- restore original physical properties
				if originalProps[d] ~= nil then
					d.CustomPhysicalProperties = originalProps[d]
					originalProps[d] = nil
				else
					-- clear to engine default
					d.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)
				end
			end
		end
	end
end

UIS.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		LeftClick()
	elseif input.KeyCode == Enum.KeyCode.Z then
		if currTargs then
			local oldWeld = currentWeld
			currentWeld, _ = WeldSystem.weldObject(currTargs, currentWeld)

			if currentWeld and not oldWeld then
				showWeldFeedback("Objects welded together!", 2)
				if hasAnchoredParts(currTargs) then
					showWeldFeedback("Welded to anchored object - dropping item", 2)
					DropItem(false)
				end
			elseif not currentWeld and oldWeld then
				showWeldFeedback("Objects unwelded!", 2)
			elseif not currentWeld then
				showWeldFeedback("No weldable objects nearby", 2)
			end
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		if carrying and currTargs then
			rotationCount[currentRotationAxis] = rotationCount[currentRotationAxis] + 1
			print("Rotated around axis", currentRotationAxis, "- Count:", rotationCount[currentRotationAxis])
		end
	elseif input.KeyCode == Enum.KeyCode.X then
		if carrying and currTargs then
			currentRotationAxis = (currentRotationAxis % 3) + 1
			local axisNames = { "X", "Y", "Z" }
			print("Switched to", axisNames[currentRotationAxis], "axis")
		end
	end
end)

UIS.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and carrying then
		LeftUnClick()
	end
end)

-- Touch controls removed - mobile dragging now handled by MobileActionController buttons
-- UIS.TouchStarted and UIS.TouchEnded connections disabled to prevent direct touch drag

RS.RenderStepped:Connect(function(dT)
	local ray = Ray.new(camera.CFrame.Position, camera.CFrame.LookVector * range)
	local hitPart, position = workspace:FindPartOnRay(ray, player.Character)

	local targObj = nil

	if hitPart then
		-- Prefer selecting a ragdolled character model rather than a single limb
		local hitModel = hitPart:FindFirstAncestorOfClass("Model")
		local hitModelPlayer = hitModel and game.Players:GetPlayerFromCharacter(hitModel)
		if hitModel and CS_tags.hasTag(hitModel, CS_tags.DRAGGABLE) and hitModelPlayer ~= player then
			-- Entire character is draggable; select the model (lighter to move)
			targObj = hitModel
		else
			-- Fallback to original: part or its parent if tagged
			if CS_tags.isDraggable(hitPart) then
				targObj = hitPart
			elseif hitPart.Parent and CS_tags.isDraggable(hitPart.Parent) then
				targObj = hitPart.Parent
			end
		end
	end

	if targObj and not carrying and targObj ~= currTargs then
		currTargs = targObj
		highlight.Parent = targObj
	elseif not targObj and currTargs ~= nil and not carrying then
		currTargs = nil
		highlight.Parent = nil
	end

	if carrying and currTargs ~= nil then
		-- If the carried target was removed from the world (e.g., sold or destroyed), force-drop locally
		if not currTargs.Parent then
			DropItem(false)
			highlight.Parent = nil
			return
		end
		if hasAnchoredParts(currTargs) then
			showWeldFeedback("Can't move - attached to anchored object", 1)
			DropItem(false)
			highlight.Parent = nil
			return
		end

		targetPos = camera.CFrame.Position + (camera.CFrame.LookVector * carryDistance)

		if currTargs:IsA("MeshPart") or currTargs:IsA("Part") then
			local positionCFrame = CFrame.new(targetPos)
			local rotationCFrame = originalCFrame.Rotation * getCurrentRotation()
			local targetCFrame = positionCFrame * rotationCFrame

			local currentCFrame = currTargs.CFrame
			local newCFrame = currentCFrame:Lerp(targetCFrame, carrySmooth)
			currTargs.CFrame = newCFrame
			currTargs.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

			if (camera.CFrame.Position - currTargs.CFrame.Position).Magnitude > carryDist then
				DropItem(false)
			end
		elseif currTargs.PrimaryPart then
			local positionCFrame = CFrame.new(targetPos)
			local rotationCFrame = originalCFrame.Rotation * getCurrentRotation()
			local targetCFrame = positionCFrame * rotationCFrame

			local currentCFrame = currTargs.PrimaryPart.CFrame
			local newCFrame = currentCFrame:Lerp(targetCFrame, carrySmooth)
			currTargs:SetPrimaryPartCFrame(newCFrame)
			currTargs.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

			if (camera.CFrame.Position - currTargs.PrimaryPart.CFrame.Position).Magnitude > carryDist then
				DropItem(false)
			end
		else
			currTargs:MoveTo(targetPos)

			local cf, size = currTargs:GetBoundingBox()
			if (camera.CFrame.Position - cf.Position).Magnitude > carryDist then
				DropItem(false)
			end
		end
	end

	WeldSystem.updateHoveredObject(carrying, CS_tags.isDraggable)
end)

function LeftClick()
	if currTargs ~= nil then
		if not CS_tags.isDraggable(currTargs) then
			return
		end

		-- Check if object is welded to anchored parts before picking up
		if hasAnchoredParts(currTargs) then
			showWeldFeedback("Can't pick up - attached to anchored object", 2)
			return
		end

		carrying = true
		if currTargs == nil then
			return
		end

		-- Store original orientation and reset rotation counts
		if currTargs:IsA("MeshPart") or currTargs:IsA("Part") then
			originalCFrame = currTargs.CFrame
		elseif currTargs.PrimaryPart then
			originalCFrame = currTargs.PrimaryPart.CFrame
		else
			-- Fallback for objects without PrimaryPart
			local cf, size = currTargs:GetBoundingBox()
			originalCFrame = cf
		end

		-- Reset rotation state
		rotationCount = { 0, 0, 0 }
		currentRotationAxis = 1 -- Start with X axis

		RP.Remotes.PickupItem:FireServer(currTargs)

		-- If dragging a character model, make it lighter while being carried
		local targHumanoid = currTargs:IsA("Model") and currTargs:FindFirstChildOfClass("Humanoid")
		if targHumanoid then
			setAssemblyMassless(currTargs, true)
		end

		if currTargs:IsA("MeshPart") or currTargs:IsA("Part") then
			currTargs.CollisionGroup = "Item"
		elseif currTargs:IsA("Tool") then
			for _, d in ipairs(currTargs:GetDescendants()) do
				if d:IsA("MeshPart") or d:IsA("Part") then
					d.CollisionGroup = "Item"
				end
			end
		elseif currTargs:IsA("Model") then
			for _, d in ipairs(currTargs:GetDescendants()) do
				if d:IsA("MeshPart") or d:IsA("Part") then
					d.CollisionGroup = "Item"
				end
			end
		end
	end
end

function LeftUnClick()
	carrying = false
	if currTargs then
		DropItem(true)
	end
end

function DropItem(AddForce: boolean?)
	local velocity = Vector3.new(0, 0, 0)
	if AddForce and targetPos then
		local objectPosition
		if currTargs:IsA("MeshPart") or currTargs:IsA("Part") then
			objectPosition = currTargs.Position
		elseif currTargs.PrimaryPart then
			objectPosition = currTargs.PrimaryPart.Position
		else
			objectPosition = targetPos
		end
		velocity = (targetPos - objectPosition) * throwBoost
	end

	carrying = false
	currentWeld = nil
	WeldSystem.cleanup()

	-- Reset rotation state
	rotationCount = { 0, 0, 0 }
	currentRotationAxis = 1
	originalCFrame = nil

	RP.Remotes.DropItem:FireServer(currTargs, velocity)

	-- Restore mass on character models
	if currTargs and currTargs:IsA("Model") and currTargs:FindFirstChildOfClass("Humanoid") then
		setAssemblyMassless(currTargs, false)
	end

	local objectToReset = currTargs
	task.spawn(function()
		task.wait(0.6) -- Wait slightly longer than server network ownership transfer

		-- Reset collision group for the object and its descendants
		if objectToReset and objectToReset.Parent then -- Check if object still exists
			if objectToReset:IsA("MeshPart") or objectToReset:IsA("Part") then
				-- Direct part - reset collision group
				objectToReset.CollisionGroup = "Default"
			else
				-- For Tools and Models - reset collision group for all parts
				for _, d in ipairs(objectToReset:GetDescendants()) do
					if d:IsA("MeshPart") or d:IsA("Part") then
						d.CollisionGroup = "Default"
					end
				end
			end
		end
	end)
end

-- Function to get current highlighted target for backpack system
function GetCurrentTarget()
	return currTargs
end

local function IsCarrying()
	return carrying == true
end

-- New exported helpers for mobile buttons
local function TryWeld()
	if currTargs then
		local oldWeld = currentWeld
		currentWeld, _ = WeldSystem.weldObject(currTargs, currentWeld)
		if currentWeld and not oldWeld then
			showWeldFeedback("Objects welded together!", 2)
			if hasAnchoredParts(currTargs) then
				showWeldFeedback("Welded to anchored object - dropping item", 2)
				DropItem(false)
			end
		elseif not currentWeld and oldWeld then
			showWeldFeedback("Objects unwelded!", 2)
		elseif not currentWeld then
			showWeldFeedback("No weldable objects nearby", 2)
		end
	end
end

local function RotateOnce()
	if carrying and currTargs then
		rotationCount[currentRotationAxis] = rotationCount[currentRotationAxis] + 1
	end
end

local function CycleAxis()
	if carrying and currTargs then
		currentRotationAxis = (currentRotationAxis % 3) + 1
	end
end

local function StartDrag()
	LeftClick()
end

local function StopDrag()
	if carrying then
		LeftUnClick()
	end
end

-- Export for other scripts to use
_G.InteractableHandler = {
	GetCurrentTarget = GetCurrentTarget,
	IsCarrying = IsCarrying,
	TryWeld = TryWeld,
	RotateOnce = RotateOnce,
	CycleAxis = CycleAxis,
	StartDrag = StartDrag,
	StopDrag = StopDrag,
}
