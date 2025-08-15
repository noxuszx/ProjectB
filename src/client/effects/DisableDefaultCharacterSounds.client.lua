-- DisableDefaultCharacterSounds.client.lua
-- Removes Roblox's default RbxCharacterSounds so custom footsteps don't overlap

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local DEFAULT_SOUND_NAMES = {
	Running = true,
	Jumping = true,
	FreeFalling = true,
	Climbing = true,
	Swimming = true,
	Died = true,
}

local function scrubDefaultSounds(char: Model)
	-- Remove the default manager script if present
	local rcs = char:FindFirstChild("RbxCharacterSounds")
	if rcs then
		rcs:Destroy()
	end
	-- Proactively remove known default sounds anywhere under the character
	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("Sound") and DEFAULT_SOUND_NAMES[inst.Name] then
			inst:Destroy()
		end
	end
	-- If RbxCharacterSounds or a default sound is re-added later, remove it
	char.ChildAdded:Connect(function(child)
		if child.Name == "RbxCharacterSounds" then
			child:Destroy()
		elseif child:IsA("Sound") and DEFAULT_SOUND_NAMES[child.Name] then
			child:Destroy()
		end
	end)
	char.DescendantAdded:Connect(function(desc)
		if desc:IsA("Sound") and DEFAULT_SOUND_NAMES[desc.Name] then
			desc:Destroy()
		end
	end)
end

if player.Character then
	scrubDefaultSounds(player.Character)
end
player.CharacterAdded:Connect(scrubDefaultSounds)
