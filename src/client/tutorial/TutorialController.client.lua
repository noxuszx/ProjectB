-- src/client/tutorial/TutorialController.client.lua
-- Client-side tutorial orchestrator

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local TutorialSteps = require(ReplicatedStorage.Shared.tutorial.TutorialSteps)
local TutorialConfig = require(ReplicatedStorage.Shared.tutorial.Config)
local HighlightManager = require(script.Parent.HighlightManager)

-- Layout helper: positions and sizes the tutorial bar responsively
local layoutWired = false
local function layoutTutorialBar()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local gui = pg:FindFirstChild("TutorialGui")
	if not gui then
		return
	end
	local frame = gui:FindFirstChild("TutorialFrame")
	local label = frame and frame:FindFirstChild("TutorialText")
	if not frame or not label then
		return
	end

	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local isPhone = UserInputService.TouchEnabled and vp.X < 1000

	-- Compute a top offset: prefer GuiService inset if non-zero, otherwise a fixed margin to avoid top buttons
	local ok, topLeftInset = pcall(function()
		local tl, _ = GuiService:GetGuiInset()
		return tl
	end)
	local insetY = (ok and topLeftInset and topLeftInset.Y) or 0
	local marginY = 12
	local fallbackTop = 36 -- when Topbar is disabled, give some breathing room
	local topOffset = (insetY > 0 and (insetY + marginY)) or (fallbackTop + marginY)

	-- Smaller on phones to avoid covering too much of the screen
	local barHeight = isPhone and 44 or 60
	local fontSize = isPhone and 16 or 20

	-- We control exact pixel placement regardless of core insets to keep it simple and stable
	frame.Position = UDim2.new(0, 0, 0, topOffset)
	frame.Size = UDim2.new(1, 0, 0, barHeight)

	local horizontalPadding = (isPhone and 8) or 10
	label.Size = UDim2.new(1, -(horizontalPadding * 2), 1, 0)
	label.Position = UDim2.new(0, horizontalPadding, 0, 0)
	label.TextSize = fontSize
	label.TextWrapped = true
end

-- Simple UI binding: assumes there is a ScreenGui named TutorialGui with Frame:TutorialFrame and TextLabel:TutorialText
local function getTutorialUI()
	local pg = player:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("TutorialGui")
	if not gui then
		-- Create minimal fallback UI if not present
		gui = Instance.new("ScreenGui")
		gui.Name = "TutorialGui"
		gui.ResetOnSpawn = false
		-- We will manually offset from the top to avoid overlap
		gui.IgnoreGuiInset = true
		gui.Parent = pg
		local frame = Instance.new("Frame")
		frame.Name = "TutorialFrame"
		frame.Size = UDim2.new(1, 0, 0, 60)
		frame.Position = UDim2.new(0, 0, 0, 48)
		frame.BackgroundTransparency = 0.5
		frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		frame.Parent = gui
		local label = Instance.new("TextLabel")
		label.Name = "TutorialText"
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -20, 1, 0)
		label.Position = UDim2.new(0, 10, 0, 0)
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Font = Enum.Font.Gotham
		label.TextSize = 20
		label.TextWrapped = true
		label.Parent = frame
	else
		-- Ensure we control exact placement
		gui.IgnoreGuiInset = true
	end

	-- Apply responsive layout and wire updates once
	layoutTutorialBar()
	if not layoutWired then
		layoutWired = true
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(layoutTutorialBar)
		end
		UserInputService.LastInputTypeChanged:Connect(function()
			task.defer(layoutTutorialBar)
		end)
	end

	local frame = gui:FindFirstChild("TutorialFrame")
	local label = frame and frame:FindFirstChild("TutorialText")
	return gui, frame, label
end

local function setTutorialText(text)
	local _, frame, label = getTutorialUI()
	if label then
		label.Text = text or ""
	end
	if frame then
		frame.Visible = text ~= nil and text ~= ""
	end
end

local currentStepIndex = 0
local currentTarget = nil
local connections = {}

local function cleanupCurrent()
	for _, conn in ipairs(connections) do
		if conn and conn.Disconnect then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
	connections = {}
	if currentTarget then
		HighlightManager.detachHighlight(currentTarget)
		currentTarget = nil
	end
end

local function findTargetForStep(step)
	local ok, result = pcall(function()
		return step.targetSelector and step.targetSelector(player)
	end)
	if ok then
		return result
	end
	return nil
end

local function startStep(step)
	setTutorialText(step.text)
	currentTarget = findTargetForStep(step)
	if currentTarget then
		HighlightManager.attachHighlight(currentTarget)
	end
end

local function advance()
	cleanupCurrent()
	currentStepIndex += 1
	local step = TutorialSteps.Steps[currentStepIndex]
	if not step then
		setTutorialText("")
		return
	end
	startStep(step)
	if step.id == "drag_basics" then
		local IH = _G.InteractableHandler
		local completed = false
		if IH and typeof(IH) == "table" and IH.StartDrag and IH.StopDrag then
			local origStart, origStop = IH.StartDrag, IH.StopDrag
			local sawStart = false
			IH.StartDrag = function(...)
				sawStart = true
				return origStart(...)
			end
			IH.StopDrag = function(...)
				local r = origStop(...)
				if sawStart and not completed then
					completed = true
					advance()
				end
				return r
			end
			-- Ensure we restore the patched functions on cleanup
			table.insert(connections, {
				Disconnect = function()
					if _G.InteractableHandler then
						_G.InteractableHandler.StartDrag = origStart
						_G.InteractableHandler.StopDrag = origStop
					end
				end,
			})
			-- Secondary guard: detect a true->false transition of IsCarrying
			local RS = game:GetService("RunService")
			local prev = IH.IsCarrying and IH.IsCarrying()
			table.insert(
				connections,
				RS.Heartbeat:Connect(function()
					if completed or not IH or not IH.IsCarrying then
						return
					end
					local now = IH.IsCarrying()
					if prev == true and now == false then
						completed = true
						advance()
					end
					prev = now
				end)
			)
		else
			-- Minimal fallback: short timeout to avoid stall
			task.delay(6, function()
				if not completed then
					completed = true
					advance()
				end
			end)
		end
	elseif step.id == "cook_food" then
		-- No-remote approach: attach to highlighted target's IsCooked attribute and also poll/observe new consumables
		local completed = false
		local function completeOnce()
			if not completed then
				completed = true
				advance()
			end
		end
		-- If currentTarget is a Model/BasePart with IsCooked attribute, listen for change
		if currentTarget and currentTarget:GetAttribute("IsCooked") ~= nil then
			table.insert(
				connections,
				currentTarget:GetAttributeChangedSignal("IsCooked"):Connect(function()
					local val = currentTarget:GetAttribute("IsCooked")
					if val == true then
						completeOnce()
					end
				end)
			)
		end
		-- Light polling to catch cooking of other items
		task.spawn(function()
			for i = 1, 60 do -- ~15s at 0.25s interval
				if completed then
					return
				end
				task.wait(0.25)
				for _, inst in ipairs(CollectionService:GetTagged("CONSUMABLE")) do
					if inst:IsDescendantOf(workspace) then
						local cooked = inst:GetAttribute("IsCooked") == true
							or CollectionService:HasTag(inst, "CookedMeat")
						if cooked then
							completeOnce()
							return
						end
					end
				end
			end
		end)
		-- Also react to new consumables entering the world
		table.insert(
			connections,
			CollectionService:GetInstanceAddedSignal("CONSUMABLE"):Connect(function(inst)
				if completed then
					return
				end
				if inst and inst:IsDescendantOf(workspace) then
					local cooked = inst:GetAttribute("IsCooked") == true or CollectionService:HasTag(inst, "CookedMeat")
					if cooked then
						completeOnce()
					else
						-- Listen on this instance specifically as well
						local conn
						conn = inst:GetAttributeChangedSignal("IsCooked"):Connect(function()
							if inst:GetAttribute("IsCooked") == true then
								if conn then
									conn:Disconnect()
								end
								completeOnce()
							end
						end)
						table.insert(connections, conn)
					end
				end
			end)
		)
		-- Final safety: timeout auto-advance to avoid permanent stall
		task.delay(20, function()
			completeOnce()
		end)
	elseif step.id == "eat_food" then
		-- Detect hunger increase via PlayerStats Update remote if exposed on client
		local updateStats = ReplicatedStorage:FindFirstChild("UpdatePlayerStats")
		if updateStats and updateStats:IsA("RemoteEvent") then
			table.insert(
				connections,
				updateStats.OnClientEvent:Connect(function(stats)
					if stats and stats.Hunger and stats.Hunger > 0 then
						advance()
					end
				end)
			)
		else
			-- Fallback: if any CONSUMABLE disappears nearby
			task.delay(4, function()
				advance()
			end)
		end
	elseif step.id == "sell_item" then
		-- Money update indicates sell or other gain; accept first increase
		local econRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Economy")
		local updateMoney = econRemotes:WaitForChild("UpdateMoney")
		local lastMoney = 0
		table.insert(
			connections,
			updateMoney.OnClientEvent:Connect(function(newAmount)
				if newAmount and newAmount > lastMoney then
					advance()
				end
				lastMoney = newAmount or lastMoney
			end)
		)
	elseif step.id == "buy_item" then
		-- Complete on first BuyPrompt trigger or money decrease
		local econRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Economy")
		local updateMoney = econRemotes:WaitForChild("UpdateMoney")
		local lastMoney = math.huge
		table.insert(
			connections,
			updateMoney.OnClientEvent:Connect(function(newAmount)
				if lastMoney ~= math.huge and newAmount and newAmount < lastMoney then
					-- Completed tutorial
					setTutorialText("")
					cleanupCurrent()
				end
				lastMoney = newAmount or lastMoney
			end)
		)
	end
end

-- Public start
if TutorialConfig.Enabled then
	advance()
else
	-- Hide UI if present
	local _, frame = (function()
		local pg = player:FindFirstChild("PlayerGui")
		local gui = pg and pg:FindFirstChild("TutorialGui")
		local frame = gui and gui:FindFirstChild("TutorialFrame")
		return gui, frame
	end)()
	if frame then
		frame.Visible = false
	end
end
