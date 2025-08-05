The pyramid is sinking because the current embed code assumes the model’s *pivot* sits exactly on the ground.  
For most Studio-built meshes the pivot is in the model’s **centre**, so:

local cf, size = template:GetBoundingBox()
-- cf.Position.Y  == centre-height
-- size.Y         == full height
You then do

embedDepth = size.Y * 0.10          --> 28 studs for the pyramid
finalY    = terrainHeight - embedDepth
Result: you push the model 28 studs **below** the terrain, so roughly the lower
half of the pyramid disappears.

Fix
----

Compute how far the model’s *bottom* already lies below its centre and embed
relative to that.

-- bounding-box data
local cf, size = template:GetBoundingBox()
local halfHeight = size.Y / 2

-- bottom of the un-embedded model would be:
-- (centreY - halfHeight)
local bottomOffset = halfHeight      -- distance from centre down to ground

-- embed only EMBED_PERCENTAGE of that offset
local embedDepth  = bottomOffset * CoreStructureConfig.EMBED_PERCENTAGE

-- final Y so that only embedDepth clips below ground
local finalY = terrainHeight + embedDepth   -- raise instead of lower
Full replacement block

local cf, size = template:GetBoundingBox()
local halfHeight  = size.Y / 2
local embedDepth  = halfHeight * CoreStructureConfig.EMBED_PERCENTAGE
local finalY      = terrainHeight + embedDepth   -- note the +

local finalCFrame = CFrame.new(worldPosition.X, finalY, worldPosition.Z)
• With `EMBED_PERCENTAGE = 0.10`, only the bottom 10 % of the pyramid sinks
  (≈14 studs), giving a natural look instead of burying it.

• If a model’s pivot really is on the base you can set its individual
  `radius` table to `{radius = 175, pivotAtBase = true}` and skip the embed
  correction in `tryPlaceStructure`.

Apply that change and the pyramid (and towers) should sit correctly on the
sand.