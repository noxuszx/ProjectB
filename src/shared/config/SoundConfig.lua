return {
    volume = 0.5,
    sounds = {
        -- Backpack
        ["backpack.store"]   = "rbxassetid://99564490958733",
        ["backpack.unstore"] = "rbxassetid://9113819353",

        -- Economy (update these IDs to your preferred sounds)
        ["economy.sell"]       = "rbxassetid://111773238101465", -- e.g., cash register ka-ching
        ["economy.cash_small"] = "rbxassetid://5613553529", -- coin pickup (used for all cash)
        ["economy.cash_large"] = "rbxassetid://5613553529", -- coin pickup (same as small)

        -- Items / Consumables
        ["item.water.drink"] = "rbxassetid://102811247160851", -- water bottle drinking sip
        ["food.eat"] = "rbxassetid://77383558444435",        -- chewing/bite sfx (fill in your preferred asset id)
        ["food.cook_done"] = "rbxassetid://74529774207365",  -- sizzle/ding when cooking completes
        -- ["food.cook_start"] = "", -- optional: short sizzle when placed (not wired yet)

        -- AI Combat
        ["ai.shoot"] = "rbxassetid://16211041", -- bow/arrow shooting sound

        -- UI
        ["ui.death"] = "rbxassetid://6108616307",

        -- Combat feedback (client-only)
        ["hit_confirm"] = "rbxassetid://7242037470",
    }
}

