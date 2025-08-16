-- RevivalFeedback.client.lua
-- Handles revival feedback messages for players attempting revival without healing items

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local deathRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Death")
local revivalFeedbackRemote = deathRemotes:WaitForChild("RevivalFeedback")

local function showRevivalMessage(messageType)
	if messageType == "requires_healing_item" then
		-- Create a simple notification
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "RevivalFeedback"
		screenGui.DisplayOrder = 200
		screenGui.Parent = playerGui
		
		local frame = Instance.new("Frame")
		frame.Name = "MessageFrame"
		frame.Size = UDim2.new(0, 300, 0, 60)
		frame.Position = UDim2.new(0.5, -150, 0.5, -30)
		frame.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
		frame.BorderSizePixel = 0
		frame.Parent = screenGui
		
		-- Add corner radius
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame
		
		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.Position = UDim2.new(0, 0, 0, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = "Requires Bandage or Medkit!"
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextScaled = true
		textLabel.FontFace = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Light)
		textLabel.Parent = frame
		
		-- Animate in
		frame.Position = UDim2.new(0.5, -150, 0.5, -70)
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local slideIn = TweenService:Create(frame, tweenInfo, {Position = UDim2.new(0.5, -150, 0.5, -30)})
		slideIn:Play()
		
		-- Auto-remove after 3 seconds
		task.wait(3)
		local fadeOut = TweenService:Create(frame, TweenInfo.new(0.5), {
			Position = UDim2.new(0.5, -150, 0.5, 10),
			BackgroundTransparency = 1
		})
		local textFadeOut = TweenService:Create(textLabel, TweenInfo.new(0.5), {
			TextTransparency = 1
		})
		
		fadeOut:Play()
		textFadeOut:Play()
		
		fadeOut.Completed:Connect(function()
			screenGui:Destroy()
		end)
	end
end

revivalFeedbackRemote.OnClientEvent:Connect(showRevivalMessage)