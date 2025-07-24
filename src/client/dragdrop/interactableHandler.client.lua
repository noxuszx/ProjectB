local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RP = game:GetService("ReplicatedStorage")

local CS_tags = require(RP.Shared.utilities.CollectionServiceTags)

local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
-- Create highlight object dynamically
local highlight = Instance.new("SelectionBox")
highlight.Name = "DragDropHighlight"
highlight.Color3 = Color3.fromRGB(0, 162, 255)
highlight.LineThickness = 0.2
highlight.Transparency = 0.8
local isMobile = true

local currTargs = nil
local carrying = false

local range = 12
local carryDistance = 9
local carryDist = 20
local carrySmooth = .06
local throwBoost = 8
local lastVelo = Vector3.new()
local targetPos = nil

RS.RenderStepped:Connect(function(dT)
	local ray = Ray.new(camera.CFrame.Position, camera.CFrame.LookVector * range)
	local model, position = workspace:FindPartOnRay(ray, player.Character)

	local targObj = nil

	if model then
		if CS_tags.isDraggable(model) then
			targObj = model
		elseif model.Parent and CS_tags.isDraggable(model.Parent) then
			targObj = model.Parent
		end
	end

	if targObj and not carrying and targObj ~= currTargs then
		currTargs = targObj
		-- Set SelectionBox to highlight the target object
		highlight.Adornee = targObj
		highlight.Parent = workspace
	elseif not targObj and currTargs ~= nil and not carrying then
		currTargs = nil
		-- Remove highlight
		highlight.Adornee = nil
		highlight.Parent = nil
	end
	
	if carrying and currTargs ~= nil then
		targetPos = camera.CFrame.Position + (camera.CFrame.LookVector * carryDistance)

		if currTargs:IsA("MeshPart") or currTargs:IsA("Part") then
			local currentCFrame = currTargs.CFrame
			local newCFrame = currentCFrame:Lerp(CFrame.new(targetPos, targetPos + camera.CFrame.LookVector), carrySmooth)
			currTargs.CFrame = newCFrame
			currTargs.AssemblyLinearVelocity = Vector3.new(0,0,0)

			if (camera.CFrame.Position - currTargs.CFrame.Position).Magnitude > carryDist then
				DropItem(false)
			end
		elseif currTargs.PrimaryPart then
			local currentCFrame = currTargs.PrimaryPart.CFrame
			local newCFrame = currentCFrame:Lerp(CFrame.new(targetPos, targetPos + camera.CFrame.LookVector), carrySmooth)
			currTargs:SetPrimaryPartCFrame(newCFrame)
			currTargs.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0,0,0)

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


end)

UIS.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)  
	if gameProcessedEvent then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		LeftClick()
	end
end)

UIS.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)  
	if gameProcessedEvent then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and carrying then
		LeftUnClick()
	end
end)

UIS.TouchStarted:Connect(function(touchPositions: {any}, gameProcessedEvent: boolean)  
	if gameProcessedEvent then return end

	LeftClick()
end)
UIS.TouchEnded:Connect(function(touchPositions: {any}, gameProcessedEvent: boolean)  
	if gameProcessedEvent then return end

	if carrying then
		LeftUnClick()
	end
	
end)

function LeftClick()
	if currTargs ~= nil then
		if not CS_tags.isDraggable(currTargs) then
			return
		end

		carrying = true
		if currTargs == nil then return end
		RP.Remotes.PickupItem:FireServer(currTargs)

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
		--i have targetPos for the target position
		--and i also have currTargs.PrimaryPart.Position for the object's position
		--adjust velocity here
		DropItem(true)
	end
end

function DropItem(AddForce : boolean ?)
	local velocity = Vector3.new(0,0,0)
	if AddForce and targetPos then
		-- Calculate velocity based on object type
		local objectPosition
		if currTargs:IsA("MeshPart") or currTargs:IsA("Part") then
			objectPosition = currTargs.Position
		elseif currTargs.PrimaryPart then
			objectPosition = currTargs.PrimaryPart.Position
		else
			objectPosition = currTargs:GetBoundingBox().Position
		end
		velocity = (targetPos - objectPosition) * throwBoost
	end

	RP.Remotes.DropItem:FireServer(currTargs, velocity)

	-- Reset collision group for the object and its descendants
	if currTargs:IsA("MeshPart") or currTargs:IsA("Part") then
		-- Direct part - reset collision group
		currTargs.CollisionGroup = "Default"
	else
		-- For Tools and Models - reset collision group for all parts
		for _, d in ipairs(currTargs:GetDescendants()) do
			if d:IsA("MeshPart") or d:IsA("Part") then
				d.CollisionGroup = "Default"
			end
		end
	end

	carrying = false
end
