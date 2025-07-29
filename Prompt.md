Fix: clamp the minimum height (or use a MeshPart with a special mesh so the geometry doesn’t vanish).
```lua
Copy
local minHeight = 0.05
local rawHeight   = originalWaterSize.Y * waterPercentage
local newHeight   = math.max(rawHeight, minHeight)
```
or, more simply, stop shrinking once it’s almost empty:
```lua
Copy
if usesLeft <= 0 then
    waterPart.Transparency = 1
else
    local pct = math.max(usesLeft / 5, 0.05)   -- never less than 5 %
    waterPart.Size = Vector3.new(
        originalWaterSize.X,
        originalWaterSize.Y * pct,
        originalWaterSize.Z
    )
    waterPart.Transparency = 0.4
end
```
After clamping (or increasing the original cylinder height in Studio) the part will remain visible down to the last drop.