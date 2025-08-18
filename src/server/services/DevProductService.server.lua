-- src/server/services/DevProductService.server.lua
-- Handles developer product prompts and receipts for death-related purchases

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DevProductConfig = require(ReplicatedStorage.Shared.config.DevProductConfig)

-- Lazy require to avoid circulars
local function getPlayerDeathHandler()
    local ok, module = pcall(function()
        return require(ServerScriptService.Server.player.PlayerDeathHandler)
    end)
    if ok then return module end
    warn("[DevProductService] Could not require PlayerDeathHandler:", module)
    return nil
end

-- Remote for client to request product prompts
local deathRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Death")
local requestPurchaseRemote = deathRemotes:FindFirstChild("RequestPurchase") or Instance.new("RemoteEvent")
requestPurchaseRemote.Name = "RequestPurchase"
requestPurchaseRemote.Parent = deathRemotes
local purchasePromptResultRemote = deathRemotes:FindFirstChild("PurchasePromptResult") or Instance.new("RemoteEvent")
purchasePromptResultRemote.Name = "PurchasePromptResult"
purchasePromptResultRemote.Parent = deathRemotes
-- Bindable event for server-initiated revives handled by PlayerDeathHandler
local serverReviveBindable = deathRemotes:FindFirstChild("ServerRevive") or Instance.new("BindableEvent")
serverReviveBindable.Name = "ServerRevive"
serverReviveBindable.Parent = deathRemotes

local DevProductService = {}

-- Map userId to a pending action we should perform on successful receipt
local pendingActions = {}
-- Debounce map to avoid multiple Prompts while one is in progress
local inProgress = {}
-- Optional timeout (seconds) to clear stuck pending state
local PENDING_TIMEOUT = 120

local ACTIONS = {
    SELF_REVIVE = "SELF_REVIVE",
    REVIVE_ALL  = "REVIVE_ALL",
}

-- Reverse lookup by productId for robustness
local ACTION_BY_PRODUCT = {}
ACTION_BY_PRODUCT[DevProductConfig.IDS.SELF_REVIVE] = ACTIONS.SELF_REVIVE
ACTION_BY_PRODUCT[DevProductConfig.IDS.REVIVE_ALL]  = ACTIONS.REVIVE_ALL

local function clearPending(userId, reason)
    if pendingActions[userId] then
        print("[DevProductService] Clearing pending action for", userId, "reason=", reason)
    end
    pendingActions[userId] = nil
    inProgress[userId] = nil
end

local function findPendingUserForAction(action)
    for uid, act in pairs(pendingActions) do
        if act == action then
            return uid
        end
    end
    return nil
end

local function promptProduct(player, productId, action)
    if not player or not productId then
        warn("[DevProductService] promptProduct invalid params", player and player.UserId, productId)
        return
    end
    if inProgress[player.UserId] then
        print("[DevProductService] Prompt suppressed - already in progress for", player.UserId, action)
        return
    end
    print("[DevProductService] Prompting productId=", productId, "action=", action, "player=", player.Name)
    pendingActions[player.UserId] = action
    inProgress[player.UserId] = true
    -- Safety timeout to clear pending state if no receipt arrives
    task.delay(PENDING_TIMEOUT, function()
        if inProgress[player.UserId] then
            clearPending(player.UserId, "timeout")
        end
    end)
    MarketplaceService:PromptProductPurchase(player, productId)
end

-- Client requests to buy a death-related product (button clicks)
requestPurchaseRemote.OnServerEvent:Connect(function(player, which)
    print("[DevProductService] Purchase request from", player and player.Name, "which=", which)
    if which == ACTIONS.SELF_REVIVE then
        promptProduct(player, DevProductConfig.IDS.SELF_REVIVE, ACTIONS.SELF_REVIVE)
    elseif which == ACTIONS.REVIVE_ALL then
        promptProduct(player, DevProductConfig.IDS.REVIVE_ALL, ACTIONS.REVIVE_ALL)
    else
        warn("[DevProductService] Unknown purchase action:", which)
    end
end)

-- Client-side prompt result (extra safety, esp. Studio)
purchasePromptResultRemote.OnServerEvent:Connect(function(player, productId, wasPurchased)
    print("[DevProductService] Client prompt result:", player and player.Name, productId, "purchased=", wasPurchased)
    if not player then return end
    if wasPurchased == false then
        -- Clear pending in case server-side PromptProductPurchaseFinished didn't fire
        clearPending(player.UserId, "client_cancel")
    end
end)

function DevProductService.ProcessReceipt(info)
    -- info fields: PlayerId, PurchaseId, ProductId, CurrencySpent, PlaceIdWherePurchased, etc.
    print("[DevProductService] ProcessReceipt PlayerId=", info.PlayerId, "ProductId=", info.ProductId)
    local userId = info.PlayerId
    local productId = info.ProductId

    local inferredAction = ACTION_BY_PRODUCT[productId]
    local action = pendingActions[userId] or inferredAction

    -- In Studio test mode, PlayerId may be -1; try to match pending by action
    if (not action) and (userId == -1) and inferredAction then
        local candidateUserId = findPendingUserForAction(inferredAction)
        if candidateUserId then
            userId = candidateUserId
            action = inferredAction
            print("[DevProductService] Mapped Studio receipt to pending userId=", userId)
        end
    end

    if not action then
        print("[DevProductService] No pending action for", userId, "and no mapping for ProductId=", productId, "- deferring")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local player = Players:GetPlayerByUserId(userId)

    -- Use bindable event to ask PlayerDeathHandler to revive, to avoid requiring a Script
    if action == ACTIONS.SELF_REVIVE then
        print("[DevProductService] Grant SELF_REVIVE to", player and player.Name)
        serverReviveBindable:Fire({ type = ACTIONS.SELF_REVIVE, player = player })
    elseif action == ACTIONS.REVIVE_ALL then
        print("[DevProductService] Grant REVIVE_ALL by", player and player and player.Name)
        serverReviveBindable:Fire({ type = ACTIONS.REVIVE_ALL, player = player })
    end

    clearPending(userId, "granted")
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Attach receipt processor (ensure no other handler is attached)
print("[DevProductService] Setting MarketplaceService.ProcessReceipt handler")
MarketplaceService.ProcessReceipt = DevProductService.ProcessReceipt

-- For developer products, use PromptProductPurchaseFinished to observe immediate result and clear debounce on failure
MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, wasPurchased)
    local pname = (typeof(player) == "Instance" and player:IsA("Player")) and player.Name or tostring(player)
    print("[DevProductService] Prompt finished:", pname, productId, "purchased=", wasPurchased)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
    if not wasPurchased then
        -- Clear pending if user cancelled
        clearPending(player.UserId, "cancelled")
    end
end)

return DevProductService
