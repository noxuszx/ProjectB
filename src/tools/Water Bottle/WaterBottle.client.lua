local PLR = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local plr = PLR.LocalPlayer
local tool = script.Parent

local drink = RP.Remotes:WaitForChild("DrinkWater")
local updateBottleStateRemote = RP.Remotes:WaitForChild("UpdateBottleState")
local requestCurrentUsesRemote = RP.Remotes:WaitForChild("RequestCurrentUses")
local activatedConnection = nil
local stateConnection = nil

-- Find both water parts
local largeWater = tool:FindFirstChild("LargeWater")
local smallWater = tool:FindFirstChild("SmallWater")

if largeWater then
	largeWater.Transparency = 0.4 -- Make visible initially
end

if smallWater then
	smallWater.Transparency = 0.4 -- Make visible initially
end

local function updateWaterLevel(usesLeft)
	if usesLeft <= 0 then
		if largeWater then
			largeWater.Transparency = 1.0
		end
		if smallWater then
			smallWater.Transparency = 1.0
		end
	elseif usesLeft <= 2 then
		if largeWater then
			largeWater.Transparency = 1.0
		end
		if smallWater then
			smallWater.Transparency = 0.4
		end
	else
		if largeWater then
			largeWater.Transparency = 0.4
		end
		if smallWater then
			smallWater.Transparency = 1.0
		end
	end
end

local function onBottleStateUpdate(usesLeft)
	updateWaterLevel(usesLeft)
end

local function onActivated()
	drink:FireServer()
end

local function onEquipped()
	if activatedConnection then
		activatedConnection:Disconnect()
	end
	if stateConnection then
		stateConnection:Disconnect()
	end
	
	activatedConnection = tool.Activated:Connect(onActivated)
	stateConnection = updateBottleStateRemote.OnClientEvent:Connect(onBottleStateUpdate)
	requestCurrentUsesRemote:FireServer()
end

local function onUnequipped()
	if activatedConnection then
		activatedConnection:Disconnect()
		activatedConnection = nil
	end
	if stateConnection then
		stateConnection:Disconnect()
		stateConnection = nil
	end
end

tool.Equipped:Connect(onEquipped)
tool.Unequipped:Connect(onUnequipped)