-- src/shared/profile/ProfileSchema.lua
-- Shared default schema for ProfileService data related to backpack preferences and player stats.
-- Used by both the lobby place and the game place.

local ProfileSchema = {
    Defaults = {
        -- Which backpack to equip in the game place on spawn.
        -- One of: "Base" | "Pro" | "Prestige"
        BackpackPreference = "Base",

        -- Unix timestamps for auditing/stability of default resolution.
        BackpackPreferenceUpdatedAt = 0,

        -- Tracks which backpack pass was most recently purchased (if both are owned).
        -- One of: nil | "Pro" | "Prestige"
        LastPurchasedBackpack = nil,
        LastPurchasedAt = 0,

        -- Persistent player stats
        Wins = 0, -- Total arena wins accumulated across sessions
    },
}

return ProfileSchema
