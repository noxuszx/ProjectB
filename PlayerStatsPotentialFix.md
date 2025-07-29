There are two very common reasons this kind of screen-GUI script “doesn’t work” even though no Lua error is thrown:

1. The script runs before PlayerGui is actually ready (especially if you place it directly in StarterPlayerScripts).
2. The frames/bars you create end up behind the Roblox top-bar, or they are parented to the wrong container so they never appear.
Your code only shows the creation part; it never puts the UI into a ScreenGui instance, and it never sets ResetOnSpawn.
Because of that, the frames are parented straight to PlayerGui, which means:
• They will be destroyed every time the character respawns (because the default parent is a PlayerGui that is reset).
• They can render in the wrong ZIndex layer, so they look “missing”.
Fix (minimal change):
```
function StatsDisplay.createUI()
    -- 1. Make a ScreenGui container first
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StatsDisplayGui"
    screenGui.ResetOnSpawn = false      -- keep it between spawns
    screenGui.Parent = playerGui

    -- 2. Now parent the root frame to that ScreenGui
    statsFrame = Instance.new("Frame")
    statsFrame.Name = "StatsDisplay"
    statsFrame.Size = UDim2.new(0, PlayerStatsConfig.UI.BAR_WIDTH + 20, 0, 80)
    statsFrame.Position = UDim2.new(0, PlayerStatsConfig.UI.BAR_POSITION_LEFT_OFFSET, 0, 50)
    statsFrame.BackgroundTransparency = 1
    statsFrame.Parent = screenGui      -- <-- here

    -- rest of your code is unchanged ...
```
After this change:
• The bars appear in a dedicated ScreenGui, so they are always on top and never get reset on respawn.
• If you still don’t see them, set BackgroundTransparency = 0 temporarily and give the Frame a bright color to verify it is actually there; then switch it back.
If the bars still refuse to update, check the Output window for any warnings after the server fires UpdatePlayerStats, but 90 % of the time the missing ScreenGui is the culprit.