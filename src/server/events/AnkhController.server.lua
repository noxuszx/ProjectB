-- src/server/events/AnkhController.server.lua
-- Detects arena trigger via dragging the Ankh and coordinates player teleport + start

local Players 			= game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace 		= game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ArenaConfig  = require(ReplicatedStorage.Shared.config.ArenaConfig)
local CS_tags 	   = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)
local ArenaManager = require(script.Parent.ArenaManager)

local AnkhController = {}

local started = false

local getTeleportPositions
local teleportOthersToArena

----------------------------------------------------------------------------------------

getTeleportPositions = function()

	local tagged = CollectionService:GetTagged(CS_tags.ARENA_TELEPORT_MARKER)
	local positions = {}
	for _, inst in ipairs(tagged) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
			table.insert(positions, inst.Position)
		end
	end
	if #positions > 0 then
		return positions
	end
	if ArenaConfig.Paths.TeleportMarkersFolder then
		local ok, folder = pcall(function()
			return Workspace:FindFirstChild(ArenaConfig.Paths.TeleportMarkersFolder, true)
		end)
		if ok and folder then
			for _, part in ipairs(folder:GetChildren()) do
				if part:IsA("BasePart") then
					table.insert(positions, part.Position)
				end
			end
			if #positions > 0 then
				return positions
			end
		end
	end
	return ArenaConfig.TeleportPositions
end


teleportOthersToArena = function(excludePlayer)
	local positions = getTeleportPositions()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= excludePlayer and player.Character and player.Character.PrimaryPart then
			local target = positions[math.random(1, #positions)]
			local model = player.Character
			if model and model.PrimaryPart then
				pcall(function()
					model:PivotTo(CFrame.new(target))
				end)
			end
		end
	end
end

local function onAnkhDragged(player, part)
	if started then
		return
	end
	if not ArenaConfig.Enabled then
		return
	end
	started = true
	teleportOthersToArena(player)
	ArenaManager.start()
end

local function connectDragDetection()

	local ankhs = CollectionService:GetTagged(CS_tags.ARENA_ANKH)
	for _, inst in ipairs(ankhs) do
		if inst:IsA("BasePart") then
			inst.Touched:Connect(function(hit)
				local character = hit and hit:FindFirstAncestorOfClass("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if player then
					onAnkhDragged(player, inst)
				end
			end)
		end
	end

	CollectionService:GetInstanceAddedSignal(CS_tags.ARENA_ANKH):Connect(function(inst)
		if inst:IsA("BasePart") then
			inst.Touched:Connect(function(hit)
				local character = hit and hit:FindFirstAncestorOfClass("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if player then
					onAnkhDragged(player, inst)
				end
			end)
		end
	end)
end

local function connectDragBridge()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		warn("[AnkhController] Remotes folder not found. Drag bridge not connected.")
		return
	end
	local pickup = remotes:FindFirstChild("PickupItem")
	if not pickup then
		warn("[AnkhController] Remotes.PickupItem not found. Drag bridge not connected.")
		return
	end
	pickup.OnServerEvent:Connect(function(player, object)
		if started then
			return
		end
		if not object then
			return
		end
		local isTagged = false
		local okHas, res = pcall(function()
			return CollectionService:HasTag(object, CS_tags.ARENA_ANKH)
		end)
		if okHas then
			isTagged = res
		else
		end
		local ancestor = object.Parent
		while (not isTagged) and ancestor do
			local okHasA, resA = pcall(function()
				return CollectionService:HasTag(ancestor, CS_tags.ARENA_ANKH)
			end)
			if okHasA and resA then
				isTagged = true
				break
			end
			ancestor = ancestor.Parent
		end
		if isTagged then
			started = true
			teleportOthersToArena(player)
			local ok, err = pcall(function()
				ArenaManager.start()
			end)
			if not ok then
				warn("[AnkhController] Failed to start arena:", err)
			end
		end
	end)
end

connectDragBridge()
connectDragDetection()

return AnkhController
