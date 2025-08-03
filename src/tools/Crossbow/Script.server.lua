tool = script.Parent
Event = tool:WaitForChild('MinigunEvent')	--This script already worked pretty well. No major changes here.

Event.OnServerEvent:connect(function(plr, MPosition)
	
	local ray = Ray.new(tool.Parent.Zone.CFrame.p, (MPosition + Vector3.new(math.random(-0.1,0.1),math.random(-0.1,0.1),math.random(-0.1,0.1)) - tool.Parent.Zone.CFrame.p).unit * 300)
	local part, position = workspace:FindPartOnRay(ray, plr.Character, false, true)

	local beam = Instance.new("Part", workspace)
	beam.BrickColor = BrickColor.new("Ghost grey")
	beam.FormFactor = "Custom"
	beam.Material = "SmoothPlastic"
	beam.Transparency = 0
	beam.Anchored = true
	beam.Locked = true
	beam.CanCollide = false
	local sound = tool.Parent.Zone.Sound:Clone()
	sound.Name = "Shoot"
	sound.Parent = tool.Parent.Zone
	sound:Play()

	local distance = (tool.Parent.Zone.CFrame.p - position).magnitude
	beam.Size = Vector3.new(0.1, 0.1, distance)
	beam.CFrame = CFrame.new(tool.Parent.Zone.CFrame.p, position) * CFrame.new(0, 0, -distance / 2)
	
	game:GetService("Debris"):AddItem(beam, 0.05)

	if part then
		local humanoid = part.Parent:FindFirstChild("Humanoid")
	
		if not humanoid then
			humanoid = part.Parent.Parent:FindFirstChild("Humanoid")
		end
	
		if humanoid then
			humanoid:TakeDamage(95)
		end
	end
end)


