local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PSM = require(game.ServerScriptService.Server.player.PlayerStatsManager)

local WaterBottleService = {}

-- Sound
local SoundPlayer = require(ReplicatedStorage.Shared.modules.SoundPlayer)

local THIRST_RESTORE_AMOUNT = 50
local MAX_BOTTLE_USES = 5

-- State: per-player uses
local usesByUserId: {[number]: number} = {}

-- Remotes (assumed pre-created under ReplicatedStorage.Remotes)
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local updateBottleStateRemote = remotes:FindFirstChild("UpdateBottleState") or Instance.new("RemoteEvent")
updateBottleStateRemote.Name = "UpdateBottleState"
updateBottleStateRemote.Parent = remotes

-- Helpers
local function setUses(player: Player, uses: number)
	usesByUserId[player.UserId] = math.clamp(uses, 0, MAX_BOTTLE_USES)
	updateBottleStateRemote:FireClient(player, usesByUserId[player.UserId])
end

local function getUses(player: Player): number
	return usesByUserId[player.UserId] or MAX_BOTTLE_USES
end

local function playerHasBottle(player: Player): boolean
	local char = player.Character
	if not char then return false end
	if char:FindFirstChild("Water Bottle") then return true end
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp and bp:FindFirstChild("Water Bottle") then return true end
	return false
end

-- API
function WaterBottleService.Init()
	Players.PlayerAdded:Connect(function(player)
		usesByUserId[player.UserId] = MAX_BOTTLE_USES
		player.CharacterAdded:Connect(function()
			if playerHasBottle(player) then
				setUses(player, getUses(player))
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		usesByUserId[player.UserId] = nil
	end)
end

function WaterBottleService.Drink(player: Player)
	if not playerHasBottle(player) then return false end
	local uses = getUses(player)
	if uses <= 0 then return false end
	local ok = PSM.AddThirst(player, THIRST_RESTORE_AMOUNT)
	if not ok then return false end
	setUses(player, uses - 1)
	-- Play drink sound at player's root part on success
	pcall(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			SoundPlayer.playAt("item.water.drink", root)
		end
	end)
	return true
end

function WaterBottleService.Refill(player: Player)
	if not playerHasBottle(player) then return false end
	setUses(player, MAX_BOTTLE_USES)
	return true
end

function WaterBottleService.SyncToClient(player: Player)
	setUses(player, getUses(player))
end

return WaterBottleService

