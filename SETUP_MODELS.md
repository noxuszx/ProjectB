# Custom Model Setup Instructions

## 🎯 You're absolutely right about Rojo!

I made an error in how Rojo handles model files. Here's the **correct approach**:

### **❌ What Doesn't Work in Rojo:**
- Adding `.rbxm` files directly through `$path` in project.json
- Expecting Rojo to automatically sync model files

### **✅ Correct Approach:**

## **Step 1: Manual Setup in Studio**

1. **Open `ProjectB.rbxlx` in Roblox Studio**

2. **Create the folder structure in ReplicatedStorage:**
   - Right-click ReplicatedStorage → Insert Object → Folder
   - Name it "Models"
   - Inside Models, create three folders:
     - "Vegetation"
     - "Rocks" 
     - "Structures"

3. **Import your models:**
   - Create your models in Studio or import .rbxm files
   - Drag/place them into the appropriate folders
   - **Important**: Set PrimaryPart for each model

## **Step 2: Enable the Spawning System**

Once you have models in the folders:

1. **Edit `src/server/ChunkInit.server.lua`:**
   ```lua
   -- Uncomment these lines:
   local CustomModelSpawner = require(script.Parent.CustomModelSpawner)
   
   -- And uncomment this:
   CustomModelSpawner.init(
       ChunkConfig.RENDER_DISTANCE,
       ChunkConfig.CHUNK_SIZE,
       ChunkConfig.SUBDIVISIONS
   )
   ```

2. **Rebuild and test:**
   ```bash
   rojo build -o ProjectB.rbxlx
   ```

## **Step 3: Alternative Approach (If you prefer Rojo workflow)**

If you want to keep everything in Rojo, you could:

1. **Create the models as Lua module scripts** that generate parts procedurally
2. **Use InsertService** to load models from the catalog/your inventory
3. **Pre-build models in Studio** and save them with the place file

## **Current Status:**

- ✅ Terrain system working
- ✅ Custom model spawning code ready
- ⏳ Waiting for manual model setup in Studio
- ⏳ Need to uncomment spawning code after setup

## **Why This Approach:**

Rojo is primarily designed for:
- **Code synchronization** (.lua files)
- **Project structure** (folders, scripts, properties)
- **Development workflow** 

**NOT for:**
- **Asset management** (.rbxm, .rbxl files)
- **Model synchronization**
- **Binary content**

For models, the Studio workflow is still the standard approach!

## **Next Steps:**

1. **Set up the folder structure manually in Studio**
2. **Add a few test models** 
3. **Uncomment the spawning code**
4. **Test and iterate**

Sorry for the confusion about Rojo's capabilities! The spawning system is ready - it just needs the manual setup step in Studio first.
