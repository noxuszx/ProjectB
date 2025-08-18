-- src/server/services/BackpackPreferenceService.lua
-- Resolves a player's backpack variant (Base/Pro/Prestige) from TeleportData + ProfileService + ownership
-- and provides helpers to equip the correct Tool and compute capacity.
-- NOTE: This is a scaffold. Wiring into PlayerAdded/CharacterAdded will be done later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local GamepassConfig = require(ReplicatedStorage.Shared.config.GamepassConfig)
local ToolGrantService = require(ServerScriptService.Server.services.ToolGrantService)

local BackpackPreferenceService = {}

export type Variant = "Base" | "Pro" | "Prestige"

local TOOL_NAMES = GamepassConfig.TOOL_NAMES
local CAPACITY = GamepassConfig.CAPACITY

local function getProfileService()
    -- Adjust to your actual ProfileService module location.
    local dataFolder = ServerScriptService:FindFirstChild("data")
    if not dataFolder then return nil end
    local ok, ProfileService = pcall(function()
        return require(dataFolder:WaitForChild("ProfileService"))
    end)
    if ok then return ProfileService end
    return nil
end

local function readTeleportChoice(player: Player): Variant?
    -- If you pass TeleportData from the lobby, parse it here.
    local tp = player:GetJoinData() -- Contains TeleportData when arriving from a teleport
    if tp and tp.TeleportData and typeof(tp.TeleportData) == "table" then
        -- Support both per-player map and single choice
        local data = tp.TeleportData
        -- Per-player mapping: TeleportData.BackpackChoices[userId] = "Pro" | "Prestige"
        if typeof(data.BackpackChoices) == "table" then
            local entry = data.BackpackChoices[player.UserId]
            if entry == "Pro" or entry == "Prestige" then
                return entry :: Variant
            end
        end
        -- Legacy/single choice
        local choice = data.BackpackChoice
        if choice == "Pro" or choice == "Prestige" then
            return choice :: Variant
        end
    end
    return nil
end

local function userOwns(userId: number, gamepassId: number?): boolean
    if not gamepassId then return false end
    local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, gamepassId)
    return ok and owns == true
end

local function getOwnership(userId: number)
    local ownsPro = userOwns(userId, GamepassConfig.IDS.PRO)
    local ownsPrestige = userOwns(userId, GamepassConfig.IDS.PRESTIGE)
    return ownsPro, ownsPrestige
end

local function validatePreference(pref: Variant, ownsPro: boolean, ownsPrestige: boolean): Variant
    if pref == "Prestige" and ownsPrestige then return "Prestige" end
    if pref == "Pro" and ownsPro then return "Pro" end
    return "Base"
end

local function resolveFromLatestPurchased(profileData, ownsPro: boolean, ownsPrestige: boolean): Variant
    local last = profileData and profileData.LastPurchasedBackpack
    if last == "Prestige" and ownsPrestige then return "Prestige" end
    if last == "Pro" and ownsPro then return "Pro" end
    -- Fallback priority
    if ownsPrestige then return "Prestige" end
    if ownsPro then return "Pro" end
    return "Base"
end

function BackpackPreferenceService.resolveVariant(player: Player): Variant
    local teleportChoice = readTeleportChoice(player)
    local ownsPro, ownsPrestige = getOwnership(player.UserId)

    -- Load profile (lazy, so this module doesn't hard-depend if not present yet)
    local ProfileService = getProfileService()
    local profileData
    if ProfileService then
        local accessor = _G.ProfileAccessor
        if accessor and accessor.getProfileData then
            profileData = accessor:getProfileData(player)
        end
    end

    -- Priority 1: Teleport choice (if valid by ownership)
    if teleportChoice then
        local validated = validatePreference(teleportChoice, ownsPro, ownsPrestige)
        print("[BPS][DEBUG] resolveVariant: using TeleportData=", teleportChoice, "validated=", validated)
        if validated ~= "Base" or (not ownsPro and not ownsPrestige) then
            return validated
        end
    end

    -- Priority 2: Stored preference (if valid)
    if profileData and profileData.BackpackPreference then
        local validated = validatePreference(profileData.BackpackPreference, ownsPro, ownsPrestige)
        print("[BPS][DEBUG] resolveVariant: using Profile pref=", profileData.BackpackPreference, "validated=", validated)
        if validated ~= "Base" or (not ownsPro and not ownsPrestige) then
            return validated
        end
    else
        print("[BPS][DEBUG] resolveVariant: no profileData or no BackpackPreference for", player.Name)
    end

    -- Priority 3: Latest purchased (or ownership priority)
    local fallback = resolveFromLatestPurchased(profileData, ownsPro, ownsPrestige)
    print("[BPS][DEBUG] resolveVariant: fallback latestPurchased/ownership=", fallback)
    return fallback
end

function BackpackPreferenceService.getCapacityForVariant(variant: Variant): number
    return CAPACITY[variant] or CAPACITY.Base
end

function BackpackPreferenceService.getToolNameForVariant(variant: Variant): string
    return TOOL_NAMES[variant] or TOOL_NAMES.Base
end

-- Equip chosen variant: grant correct tool, remove other variants, and move chosen tool to Character
function BackpackPreferenceService.equipChosenBackpack(player: Player, variant: Variant)
    local toolName = BackpackPreferenceService.getToolNameForVariant(variant)
    if not toolName then
        warn("[BPS] No toolName for variant", variant)
        return
    end
    print("[BPS][DEBUG] Equip variant=", variant, "tool=", toolName, "for", player.Name)

    -- Remove other variants from Character and Backpack
    local function purge(container)
        if not container then return end
        -- normalize names to handle case differences
        local valid = {
            [string.lower(TOOL_NAMES.Base)] = true,
            [string.lower(TOOL_NAMES.Pro)] = true,
            [string.lower(TOOL_NAMES.Prestige)] = true,
            -- also accept common variants
            ["backpackpro"] = true,
            ["backpackprestige"] = true,
        }
        local keep = string.lower(toolName)
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") then
                local n = string.lower(t.Name)
                if valid[n] and n ~= keep then
                    t:Destroy()
                end
            end
        end
    end

    local character = player.Character
    local playerBackpack = player:FindFirstChild("Backpack")
    print("[BPS][DEBUG] Before purge - Character tools:", character and #character:GetChildren() or 0, "Backpack items:", playerBackpack and #playerBackpack:GetChildren() or 0)
    purge(character)
    purge(playerBackpack)

    -- Grant tool if missing
    local has = false
    if character and character:FindFirstChild(toolName) then has = true end
    if not has then
        local backpack = playerBackpack
        if backpack and backpack:FindFirstChild(toolName) then has = true end
    end

    if not has then
        print("[BPS][DEBUG] Granting tool", toolName)
        ToolGrantService.grantTool(player, toolName)
    else
        print("[BPS][DEBUG] Tool already present", toolName)
    end

    -- Ensure StarterGear matches selection for future spawns
    local starterGear = player:FindFirstChild("StarterGear")
    if starterGear then
        -- purge variants in StarterGear
        for _, t in ipairs(starterGear:GetChildren()) do
            if t:IsA("Tool") then
                local n = string.lower(t.Name)
                if n == string.lower(TOOL_NAMES.Base) or n == string.lower(TOOL_NAMES.Pro) or n == string.lower(TOOL_NAMES.Prestige) or n == "backpackpro" or n == "backpackprestige" then
                    if n ~= string.lower(toolName) then
                        t:Destroy()
                    end
                end
            end
        end
        -- add desired tool if missing
        if not starterGear:FindFirstChild(toolName) then
            local toolsFolder = ReplicatedStorage:FindFirstChild("Tools") or ReplicatedStorage:FindFirstChild("Items")
            local template = toolsFolder and toolsFolder:FindFirstChild(toolName)
            if template and template:IsA("Tool") then
                local clone = template:Clone()
                clone.Parent = starterGear
                print("[BPS][DEBUG] StarterGear updated with", toolName)
            else
                warn("[BPS] Could not find template for StarterGear:", toolName)
            end
        end
    else
        warn("[BPS] StarterGear not found for", player.Name)
    end

    -- Move tool to character to ensure it's equipped
    task.defer(function()
        character = character or player.Character
        if not character then return end
        local backpack = player:FindFirstChild("Backpack")
        if not backpack then return end
        local tool = character:FindFirstChild(toolName) or backpack:FindFirstChild(toolName)
        if tool and tool:IsA("Tool") then
            tool.Parent = character
        end
        -- Purge again to be safe
        purge(character)
        purge(backpack)
    end)
end

return BackpackPreferenceService
