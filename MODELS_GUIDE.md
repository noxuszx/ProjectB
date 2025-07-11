# Custom Model Spawning Guide

## 🎯 How to Add Your Own Models

### **Step 1: Create Your Models in Roblox Studio**
1. Build your Fallout desert models (dead trees, rocks, structures, etc.)
2. **Important**: Make sure each model has a **PrimaryPart** set
   - Select your model
   - In Properties, set the PrimaryPart to the main/base part of your model
3. Group everything into a Model
4. Give it a descriptive name (e.g., "DeadTree1", "Boulder1", "AbandonedHouse")

### **Step 2: Export Your Models**
1. Right-click your model in Studio
2. Choose "Export Selection..."
3. Save as `.rbxm` file
4. Name the file the same as your model name

### **Step 3: Set Up Model Folders in Studio**
1. Open `ProjectB.rbxlx` in Roblox Studio
2. In ReplicatedStorage, create this folder structure:
   ```
   ReplicatedStorage/
   └── Models/
       ├── Vegetation/     # Dead trees, cacti, shrubs, plants
       ├── Rocks/         # Boulders, rock formations, debris
       └── Structures/    # Buildings, towers, ruins, settlements
   ```

### **Step 4: Import Your Models**
1. Right-click on the appropriate folder (Vegetation, Rocks, or Structures)
2. Choose "Insert Object" → "Model"
3. Import your `.rbxm` files into the correct folders
4. **Important**: Make sure each imported model has its PrimaryPart set

### **Step 5: Test**
1. Press Play in Studio
2. Your models will automatically spawn based on the configuration!

## ⚙️ Configuration Options

Edit `src/shared/ModelSpawnerConfig.lua` to customize:

### **Spawn Chances**
```lua
VEGETATION_CHANCE = 0.25  -- 25% chance per area
ROCK_CHANCE = 0.15        -- 15% chance per area  
STRUCTURE_CHANCE = 0.05   -- 5% chance per area
```

### **Minimum Distances** (prevents crowding)
```lua
MIN_VEGETATION_DISTANCE = 8   -- studs apart
MIN_ROCK_DISTANCE = 12       -- studs apart
MIN_STRUCTURE_DISTANCE = 30  -- studs apart
```

### **Size Variation** (random scaling)
```lua
VEGETATION_SCALE_RANGE = {0.8, 1.3}  -- 80% to 130% size
ROCK_SCALE_RANGE = {0.7, 1.5}        -- 70% to 150% size
STRUCTURE_SCALE_RANGE = {0.9, 1.1}   -- 90% to 110% size
```

## 📋 Model Categories

### **🌵 Vegetation Models**
- Dead/burnt trees
- Cacti (various sizes)
- Dry shrubs and bushes
- Tumbleweeds
- Sparse grass patches

### **🪨 Rock Models** 
- Large boulders
- Rock formations/arches
- Rubble piles
- Stone clusters
- Small scattered rocks

### **🏢 Structure Models**
- Abandoned buildings
- Radio/communication towers
- Water towers
- Crashed vehicles
- Settlement buildings
- Bunker entrances
- Bridges
- Ruins

## 🎯 Tips for Best Results

### **Model Creation**
- **Set PrimaryPart**: Essential for proper positioning
- **Anchor parts**: Make sure parts are anchored if needed
- **Size appropriately**: Consider the 32x32 stud chunk size
- **Use realistic proportions**: Match Fallout desert aesthetic

### **Performance**
- **Keep part count reasonable**: Avoid overly complex models
- **Use appropriate detail**: High detail for structures, simpler for vegetation
- **Test frequently**: Build and test to see how models look in-game

### **Variety**
- **Create multiple versions**: DeadTree1, DeadTree2, etc.
- **Different sizes**: Small, medium, large variants
- **Mix styles**: Variety makes the world more interesting

## 🔧 Troubleshooting

### **Models Not Spawning?**
1. Check Output window for error messages
2. Ensure models have PrimaryPart set
3. Verify `.rbxm` files are in correct folders
4. Make sure model names don't have special characters

### **Models Floating/Underground?**
- The system automatically positions models on terrain
- If issues persist, check your model's PrimaryPart positioning

### **Too Many/Few Models?**
- Adjust spawn chances in `ModelSpawnerConfig.lua`
- Modify `MAX_OBJECTS_PER_CHUNK` limits

## 📈 Advanced Usage

### **Weight System** (Coming Soon)
You'll be able to make certain models spawn more often:
```lua
MODEL_WEIGHTS = {
    Vegetation = {
        ["CommonShrub"] = 20,  -- Spawns more often
        ["RareCactus"] = 5     -- Spawns less often
    }
}
```

## 🗂️ Organization in Studio

When you run the game, spawned models are organized in Workspace:
- `SpawnedVegetation/` - All vegetation models
- `SpawnedRocks/` - All rock models  
- `SpawnedStructures/` - All structure models

This keeps everything organized and easy to manage!

---

**Ready to create your Fallout desert world? Start by creating a few models and dropping them in the folders!**
