local module = {}

local remote = game.ReplicatedStorage.Remotes.Ragdoll
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

function module.Ragdoll(char : CharacterMesh)
	local humanoid : Humanoid = char:WaitForChild("Humanoid")
	if humanoid:GetState() == Enum.HumanoidStateType.Physics then return true end
	humanoid.BreakJointsOnDeath = false
	
	local ragdollSuccess = false
	
	for index, joint in pairs(char:GetDescendants()) do
		if joint:IsA("Motor6D") then
			if not remote then return false end
			local socket = Instance.new("BallSocketConstraint")
			local a1 = Instance.new("Attachment")
			local a2 = Instance.new("Attachment")
			a1.Parent = joint.Part0
			a2.Parent = joint.Part1
			socket.Parent = joint.Parent
			local plr = game.Players:GetPlayerFromCharacter(char)
			remote:FireClient(plr, nil, "manualM")
			socket.Attachment0 = a1
			socket.Attachment1 = a2
			a1.CFrame = joint.C0
			a2.CFrame = joint.C1
			socket.LimitsEnabled = true

			if joint.Name == "Root" then
				socket:Destroy()
				local hinge = Instance.new("HingeConstraint")
				hinge.Parent = joint.Parent
				hinge.Attachment0 = a1
				hinge.Attachment1 = a2
				hinge.LimitsEnabled = true
			end
			
			if joint.Name == "Neck" then
				socket:Destroy()
				local hinge = Instance.new("HingeConstraint")
				hinge.Parent = joint.Parent
				hinge.Attachment0 = a1
				hinge.Attachment1 = a2
				hinge.LimitsEnabled = true
			end
			socket.TwistLimitsEnabled = true
			joint.Enabled = false
			ragdollSuccess = true
		end
	end
	
	-- If ragdoll was successful, make the body draggable (tag the model DRAGGABLE; parts WELDABLE)
	if ragdollSuccess then
		-- Mirror NPC behavior: fully enter physics state for lighter, predictable dragging
		local humanoid: Humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			humanoid.PlatformStand = true
		end
		CollectionServiceTags.addTag(char, CollectionServiceTags.DRAGGABLE)
		CollectionServiceTags.tagDescendants(char, CollectionServiceTags.WELDABLE)
		print("[RagdollModule] Player ragdolled and tagged for dragging:", char.Name)
	end
	
	return ragdollSuccess
end

function module.NpcRagdoll(char : Model, sec : number) -- npcc
	local humanoid : Humanoid = char and char.Humanoid
	local root = humanoid and humanoid.RootPart
	humanoid.BreakJointsOnDeath = false
	if humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
		for index, joint in pairs(char:GetDescendants()) do
			if joint:IsA("Motor6D") then
				local socket = Instance.new("BallSocketConstraint")
				local a1 = Instance.new("Attachment")
				local a2 = Instance.new("Attachment")
				a1.Parent = joint.Part0
				a2.Parent = joint.Part1
				socket.Parent = joint.Parent
				socket.Attachment0 = a1
				socket.Attachment1 = a2
				a1.CFrame = joint.C0
				a2.CFrame = joint.C1
				socket.LimitsEnabled = true
				socket.TwistLimitsEnabled = true
				humanoid.PlatformStand = true
				if joint.Name == "Root" then
					socket:Destroy()
					local hinge = Instance.new("HingeConstraint")
					hinge.Parent = joint.Parent
					hinge.Attachment0 = a1
					hinge.Attachment1 = a2
					hinge.LimitsEnabled = true
				end
				if joint.Name == "Neck" then
					socket:Destroy()
					local hinge = Instance.new("HingeConstraint")
					hinge.Parent = joint.Parent
					hinge.Attachment0 = a1
					hinge.Attachment1 = a2
					hinge.LimitsEnabled = true
				end
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
				joint.Enabled = false
			end
		end
		task.wait(sec)

		for index, joint in pairs(char:GetDescendants()) do
			if joint:IsA("Motor6D") then
				local socket = joint.Parent:FindFirstChild("BallSocketConstraint") or joint.Parent:FindFirstChild("HingeConstraint")
				local a1 = joint.Part0:FindFirstChild("Attachment")
				local a2 = joint.Part1:FindFirstChild("Attachment")
				socket:Destroy()
				a1:Destroy()
				a2:Destroy()
				humanoid.PlatformStand = false
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				joint.Enabled = true
			end
		end
	end
end

function module.PermanentNpcRagdoll(char : Model) -- Permanent ragdoll for creature death
	if not char or not char:FindFirstChild("Humanoid") then
		warn("[RagdollModule] Invalid character passed to PermanentNpcRagdoll")
		return false
	end
	
	local humanoid : Humanoid = char.Humanoid
	local root = humanoid.RootPart
	
	if not root then
		warn("[RagdollModule] No RootPart found for character:", char.Name)
		return false
	end
	
	-- Prevent default character cleanup
	humanoid.BreakJointsOnDeath = false
	humanoid.PlatformStand = true
	
	-- Only ragdoll if not already in physics state
	if humanoid:GetState() == Enum.HumanoidStateType.Physics then
		return true
	end
	
	print("[RagdollModule] Applying permanent ragdoll to:", char.Name)
	
	local ragdollSuccess = false
	
	-- Convert Motor6D joints to physics constraints
	for index, joint in pairs(char:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			pcall(function()
				-- Create constraint based on joint type
				local constraint
				local a1 = Instance.new("Attachment")
				local a2 = Instance.new("Attachment")
				
				a1.Parent = joint.Part0
				a2.Parent = joint.Part1
				a1.CFrame = joint.C0
				a2.CFrame = joint.C1
				
				-- Special handling for Root and Neck joints
				if joint.Name == "Root" or joint.Name == "Neck" then
					constraint = Instance.new("HingeConstraint")
					constraint.LimitsEnabled = true
				else
					constraint = Instance.new("BallSocketConstraint")
					constraint.LimitsEnabled = true
					constraint.TwistLimitsEnabled = true
				end
				
				constraint.Parent = joint.Parent
				constraint.Attachment0 = a1
				constraint.Attachment1 = a2
				
				-- Disable the motor joint
				joint.Enabled = false
				ragdollSuccess = true
			end)
		end
	end
	
	if ragdollSuccess then
		-- Set humanoid to physics state
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		
		char:SetAttribute("Ragdolled", true)
		char:SetAttribute("RagdollTime", os.clock())
		
		CollectionServiceTags.addTag(char, CollectionServiceTags.DRAGGABLE)
		CollectionServiceTags.tagDescendants(char, CollectionServiceTags.WELDABLE)
		print("[RagdollModule] Successfully ragdolled and tagged for dragging:", char.Name)
		return true
	else
		warn("[RagdollModule] Failed to ragdoll character:", char.Name)
		return false
	end
end
function module.TimedRagdoll(char : Model, sec : number) -- uhh
	local humanoid = char:WaitForChild("Humanoid")
	humanoid.BreakJointsOnDeath = false

	if not remote then return end
	local plr = game.Players:GetPlayerFromCharacter(char)
	remote:FireClient(plr, "Make", sec)
	if humanoid:GetState() ~= Enum.HumanoidStateType.Physics then

		for index, joint in pairs(char:GetDescendants()) do
			if joint:IsA("Motor6D") then
				local socket = Instance.new("BallSocketConstraint")
				local a1 = Instance.new("Attachment")
				local a2 = Instance.new("Attachment")
				a1.Parent = joint.Part0
				a2.Parent = joint.Part1
				socket.Parent = joint.Parent
				socket.Attachment0 = a1
				socket.Attachment1 = a2
				a1.CFrame = joint.C0
				a2.CFrame = joint.C1
				socket.LimitsEnabled = true
				socket.TwistLimitsEnabled = true
				if joint.Name == "Root" then
					socket:Destroy()
					local hinge = Instance.new("HingeConstraint")
					hinge.Parent = joint.Parent
					hinge.Attachment0 = a1
					hinge.Attachment1 = a2
					hinge.LimitsEnabled = true
				end
				if joint.Name == "Neck" then
					socket:Destroy()
					local hinge = Instance.new("HingeConstraint")
					hinge.Parent = joint.Parent
					hinge.Attachment0 = a1
					hinge.Attachment1 = a2
					hinge.LimitsEnabled = true
				end
				joint.Enabled = false
			end
		end
		
		task.wait(sec)

		local plr = game.Players:GetPlayerFromCharacter(char)
		if plr then
			remote:FireClient(plr, "Destroy", sec)
		end

		for index, joint in pairs(char:GetDescendants()) do
			if joint:IsA("Motor6D") then
				local socket = joint.Parent:FindFirstChild("BallSocketConstraint") or joint.Parent:FindFirstChild("HingeConstraint")
				local a1 = joint.Part0:FindFirstChild("Attachment")
				local a2 = joint.Part1:FindFirstChild("Attachment")
				socket:Destroy()
				a1:Destroy()
				a2:Destroy()
				joint.Enabled = true
			end
		end
	end
end

function module.Unragdoll(char : CharacterMesh) -- again, the character
	for index, joint in pairs(char:GetDescendants()) do
		if joint:IsA("Motor6D") then
			if not remote then return end
			local humanoid = char:WaitForChild("Humanoid")
			local socket = joint.Parent:FindFirstChild("BallSocketConstraint") or joint.Parent:FindFirstChild("HingeConstraint")
			local a1 = joint.Part0:FindFirstChild("Attachment")
			local a2 = joint.Part1:FindFirstChild("Attachment")
			socket:Destroy()
			a1:Destroy()
			a2:Destroy()
			local plr = game.Players:GetPlayerFromCharacter(char)
			remote:FireClient(plr, nil, "manualD")
			joint.Enabled = true
		end
	end
end

return module

-- fr fr, forum: "https://devforum.roblox.com/t/emilios-ragdoll-module-easy-ahh-ragdolls-r15-and-r6/2865426"

