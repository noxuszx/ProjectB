# Items Folder

This folder is where all item models should be placed for the Item Spawning System to automatically discover and use them.

## How to Add Items

1. **Create or import your item model** in Roblox Studio
2. **Name the model** exactly as it appears in the loot tables (e.g., "Wood", "HealthPotion", "IronSword")
3. **Place the model** in ReplicatedStorage.Items folder
4. **The spawning system will automatically detect** the item and make it available for spawning

## Item Naming Convention

- Use **PascalCase** for item names (e.g., "HealthPotion", "IronSword")
- Names must **exactly match** the entries in `ItemConfig.lua` loot tables
- Avoid spaces and special characters in item names

## Item Requirements

- Items should be **MeshParts** or **Tools** (not Models)
- **MeshParts:** Direct mesh objects for maximum performance
- **Tools:** Must have a Handle (BasePart) for proper positioning
- Items should be compatible with the **drag-drop system**
- Items should be reasonably sized for the game world (0.1 to 50 studs)

## Current Items Referenced in Config

The following items are referenced in the current ItemConfig.lua and should be added:

### Building Materials
- **MetalRoof** - Metal roofing material
- **WoodPlank1** - Wooden plank variant 1
- **WoodPlank2** - Wooden plank variant 2

## Performance Benefits

- **MeshParts** are more performant than Models for simple items
- **Tools** work well for interactive/equipable items
- Both types avoid the overhead of Model containers
- Better memory usage and rendering performance

## Notes

- Items placed here will be **automatically discovered** by the spawning system
- Only **MeshParts** and **Tools** are supported (Models will be skipped)
- No code changes needed when adding new items (just update the loot tables in ItemConfig.lua)
- Items not referenced in any loot table will be ignored
- The spawning system will warn about missing items referenced in loot tables
