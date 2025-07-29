I thought it was bc of the model that might have lots of parts but with only two BaseParts the model itself is trivial, so the framedrop has to come from something that happens every time a rabbit dies but not when a wolf dies.
Let’s look at the only two things that differ between the two cases:
The rabbit carcass (the original NPC itself) is still in Workspace when you call dropFood.
The raycast in getDropPosition is done with a blacklist that currently only contains foodFolder; the rabbit (or its debris) is not blacklisted, so the ray is hitting the dead rabbit’s parts and the engine has to check collisions against every physics part in the carcass.
When a wolf dies, its body is either removed immediately or is so large that the ray hits the ground first and short-circuits.
Rabbits are small, so the ray often starts inside the body and has to sweep through several of its parts before reaching open air, causing a burst of physics queries → framedrop.
## Fix
Blacklist the dying creature itself (or simply wait one frame so the corpse is already gone).

```lua
local blacklist = {foodFolder}
if dyingCreatureModel then
    table.insert(blacklist, dyingCreatureModel)
end
raycastParams.FilterDescendantsInstances = blacklist
```
or, if the NPC framework removes the corpse a frame later:

```lua
task.defer(function()
    foodModel.Parent = foodFolder
end)
```
Either change will stop the ray from scanning the rabbit corpse and should remove the framedrop.