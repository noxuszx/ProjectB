# Pyramid Arena Survival Challenge - Complete Design Document

## Game Overview & Objective

### Arena Challenge Flow
1. **Players complete ball puzzle** → **Enter pyramid interior** → **Discover ankh pedestal**
2. **One player drags ankh** → **All other players teleport to pyramid** → **Players trapped inside** → **Arena challenge begins** → **2-minute survival timer starts**
3. **Survive escalating enemy waves** → **Timer reaches 0:00** → **Victory achieved**
4. **Post-victory choice** → **Return to lobby** or **Continue + Treasure door opens**

### System Goal
Create an epic 2-minute survival challenge that serves as the game's finale, with escalating enemy difficulty and dramatic entrances.

## Arena Timeline & Enemy Spawning

### **Phase 1: The Awakening (0:00)**
- **WideSpawner1**: 5 EgyptianSkeleton + 5 Mummy = 10 enemies
- **WideSpawner2**: 5 EgyptianSkeleton + 5 Mummy = 10 enemies  
- **Total active enemies**: 20 skeletons and mummies surrounding players

### **Phase 2: The Reinforcement (1:00)**
- **WideSpawner1**: 5 EgyptianSkeleton2 
- **WideSpawner2**: 5 EgyptianSkeleton2
- **Total active enemies**: ~30 (previous survivors + new reinforcements)

### **Phase 3: The Elite Strike (1:30)**
- **ScorpionSpawner1-5**: 1 Scorpion each = 5 total elite units
- **Total active enemies**: ~35 maximum

### **Phase 4: Victory (2:00)**
- **"VICTORY! You survived the Pharaoh's Curse!"**
- **Choice UI appears**: Back to Lobby or Continue + Treasure Door Opens

## File Structure & Implementation

### Files to Create

#### 1. `src/server/events/AnkhController.server.lua`
**Ankh Drag Detection & Arena Trigger**

**Responsibilities:**
- Detect when players drag the ankh pedestal using drag/drop system
- Teleport all other players to random positions around pyramid pedestal  
- Trap all players inside pyramid (seal exits)
- Initialize arena challenge and start 2-minute timer
- Coordinate with ArenaSpawner for enemy waves
- Handle victory conditions and post-game choices

**Key Functions:**
```lua
local function onAnkhDragged(player) -- Detect ankh drag interaction
local function teleportPlayersToArena() -- Teleport all other players inside
local function sealPyramid() -- Trap players inside during arena
local function startArenaChallenge() -- Begin 2-minute survival
local function onArenaVictory() -- Handle victory and choices
local function updateTimer() -- Display countdown to all players
```

#### 2. `src/server/events/ArenaSpawner.server.lua`
**Enemy Spawning & Enhanced Aggro System**

**Responsibilities:**
- Spawn enemies at designated spawn points with timing
- Enhance enemy detection/chase ranges for arena combat
- Handle special scorpion entrances with effects
- Tag arena enemies for identification

**Key Functions:**
```lua
local function spawnAtPoint(spawnPoint, enemyType, count)
local function enhanceEnemyAggro(enemy) -- Boost detection ranges to 70
local function spawnSkeletonMummyWave() -- Phase 1 spawning (EgyptianSkeleton + Mummy)
local function spawnSkeleton2Wave() -- Phase 2 spawning (EgyptianSkeleton2)
local function spawnScorpionElites() -- Phase 3 spawning (5 individual Scorpions)
```

#### 3. `src/server/events/ArenaManager.server.lua`
**Central Arena Coordination**

**Responsibilities:**
- Coordinate between AnkhController and ArenaSpawner
- Manage arena state (inactive, active, victory, post-game)
- Control treasure door access
- Handle post-victory player choices

**Key Functions:**
```lua
local function setArenaState(state) -- Manage arena phases
local function openTreasureDoor() -- Grant treasure access after "Continue" choice
local function handlePlayerChoice(choice) -- Handle "Back to Lobby" or "Continue"
local function showVictoryUI() -- Display post-game choice buttons
```

#### 4. `docs/PyramidArenaSystem.md`
**This complete design document**

### Arena Spawn Points Setup

#### **Folder Structure in Workspace:**
```
workspace.ArenaSpawns/
├── WideSpawner1         (Part - spawns 5 EgyptianSkeleton + 5 Mummy, then 5 EgyptianSkeleton2)
├── WideSpawner2         (Part - spawns 5 EgyptianSkeleton + 5 Mummy, then 5 EgyptianSkeleton2)
├── ScorpionSpawner1     (Part - spawns 1 Scorpion)
├── ScorpionSpawner2     (Part - spawns 1 Scorpion)
├── ScorpionSpawner3     (Part - spawns 1 Scorpion)
├── ScorpionSpawner4     (Part - spawns 1 Scorpion)
└── ScorpionSpawner5     (Part - spawns 1 Scorpion)
```

#### **Spawn Point Configuration:**
```lua
-- Each spawn point part setup:
spawnPart.Transparency = 1        -- Invisible
spawnPart.CanCollide = false      -- Non-solid
spawnPart.CanTouch = false        -- No collision events
spawnPart.Anchored = true         -- Static position
spawnPart.Size = Vector3.new(2,2,2) -- Small marker size
```

### CollectionService Tags Required

#### **Add to `CollectionServiceTags.lua`:**
```lua
-- Arena system tags
CollectionServiceTags.ARENA_ANKH = "ARENA_ANKH"           -- Trigger ankh pedestal
CollectionServiceTags.ARENA_ENEMY = "ARENA_ENEMY"         -- Arena-spawned enemies
CollectionServiceTags.TREASURE_DOOR = "TREASURE_DOOR"     -- Post-victory treasure access
CollectionServiceTags.ARENA_SPAWN = "ARENA_SPAWN"         -- Spawn point parts (optional)
```

## Technical Implementation Details

### **Ankh Drag Detection & Player Teleportation**
- **Use existing drag/drop system**: Tag ankh as `DRAGGABLE` + `ARENA_ANKH`
- **Detect interaction**: When player attempts to drag → trigger arena
- **Player teleportation**: All OTHER players teleport to random positions around pyramid pedestal
- **Pyramid sealing**: All exits sealed to trap players inside during arena
- **Server-wide event**: All players in server get UI updates regardless of location
- **One-time trigger**: Prevent multiple arena starts

### **Enhanced Enemy AI for Arena**
```lua
-- Boost enemy aggro ranges during arena spawning
local function enhanceEnemyAggro(enemy)
    if enemy.DetectionRange then
        enemy.DetectionRange = 70  -- Boosted for arena combat
    end
    if enemy.ChaseRange then  
        enemy.ChaseRange = 70      -- Boosted for arena combat
    end
    -- Tag for identification
    CollectionService:AddTag(enemy, "ARENA_ENEMY")
end
```

### **Arena Timer System**
```lua
local arenaTimeRemaining = 120 -- 2 minutes
local arenaActive = false

local function updateArenaTimer()
    while arenaActive and arenaTimeRemaining > 0 do
        task.wait(1)
        arenaTimeRemaining = arenaTimeRemaining - 1
        
        -- Trigger enemy spawns at specific times
        if arenaTimeRemaining == 60 then -- 1:00 remaining
            ArenaSpawner.spawnSkeleton2Wave()
        elseif arenaTimeRemaining == 30 then -- 0:30 remaining  
            ArenaSpawner.spawnScorpionElites()
        end
        
        -- Update UI countdown display
        updateTimerUI(arenaTimeRemaining)
    end
    
    if arenaActive then
        onArenaVictory()
    end
end
```

### **Scorpion Elite Spawning**
```lua
local function spawnScorpionAtPoint(spawnPoint)
    -- Spawn scorpion with enhanced aggro
    local scorpion = CreatureSpawner.spawnCreature("Scorpion", spawnPoint.Position)
    enhanceEnemyAggro(scorpion)
    CollectionService:AddTag(scorpion, "ARENA_ENEMY")
    return scorpion
end
```

### **Victory & Post-Game System**
```lua
local function onArenaVictory()
    arenaActive = false
    
    -- Show victory UI to all players in server
    showVictoryMessage("VICTORY! You survived the Pharaoh's Curse!")
    
    -- Show choice UI to all players
    showPostGameChoice() -- "Back to Lobby" vs "Continue"
end

local function onPlayerChoice(player, choice)
    if choice == "lobby" then
        -- Teleport to lobby (existing system)
        teleportToLobby(player)
    elseif choice == "continue" then
        -- Open treasure door and continue in current world
        ArenaManager.openTreasureDoor()
        showMessage("The Pharaoh's treasure chamber awaits...")
    end
end
```

### **Player Teleportation System**
```lua
-- Teleport all players (except ankh toucher) to pyramid
local function teleportPlayersToArena(excludePlayer)
    local teleportPositions = {
        -- Random positions around pyramid pedestal
        Vector3.new(-5, 40, 135),
        Vector3.new(5, 40, 135), 
        Vector3.new(0, 40, 140),
        Vector3.new(-3, 40, 130),
        Vector3.new(3, 40, 130)
    }
    
    for _, player in Players:GetPlayers() do
        if player ~= excludePlayer and player.Character then
            local randomPos = teleportPositions[math.random(#teleportPositions)]
            player.Character:SetPrimaryPartCFrame(CFrame.new(randomPos))
        end
    end
end

-- Seal pyramid exits during arena
local function sealPyramid()
    -- Close/block pyramid entrances
    -- Implementation depends on pyramid design
end
```

## System Flow Diagram

```
Player enters pyramid
    ↓
Discovers ankh pedestal
    ↓
Player drags ankh → AnkhController detects
    ↓
All OTHER players teleport to pyramid → Pyramid sealed (players trapped)
    ↓
Arena challenge begins → 2-minute timer starts (server-wide UI)
    ↓
0:00 → ArenaSpawner spawns 20 enemies (EgyptianSkeleton + Mummy via WideSpawner1&2)
    ↓
1:00 → ArenaSpawner spawns 10 EgyptianSkeleton2 (reinforcements via WideSpawner1&2)
    ↓
1:30 → ArenaSpawner spawns 5 Scorpions (individual ScorpionSpawner1-5)
    ↓
2:00 → Timer expires → ArenaManager triggers victory
    ↓
Victory UI → Choice: [Back to Lobby] or [Continue]
    ↓
Choice: Lobby → Teleport away | Continue → Treasure Door Opens → Stay in world
```

## Testing Scenarios
1. **Basic Flow**: Drag ankh → all other players teleport → survive full 2 minutes → choose continue/lobby
2. **Player Teleportation**: Verify all other players teleport to pyramid when ankh dragged
3. **Enemy Spawning**: Verify enemies spawn at correct times with 70 detection range
4. **Pyramid Sealing**: Confirm players cannot escape pyramid during arena
5. **Server-Wide UI**: Timer and victory UI appear for all players regardless of location
6. **Victory Conditions**: Timer reaches 0:00 triggers victory regardless of enemies alive
7. **Post-Game Choices**: Both lobby return and treasure door options work properly
8. **Treasure Door**: Door slides down when "Continue" is chosen

## Future Enhancement Ideas (Optional)
- **Difficulty Scaling**: More enemies based on player count
- **Boss Finale**: Special pharaoh boss at 0:30 remaining
- **Leaderboards**: Track fastest completions or most wins
- **Arena Variations**: Different enemy combinations per attempt
- **Cinematic Elements**: Arena walls seal when challenge begins
- **Power-ups**: Temporary weapons spawn during intense moments