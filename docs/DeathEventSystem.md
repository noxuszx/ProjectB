# Death Event System Implementation

## Overview
This document outlines the implementation plan for the player death event system in ProjectB. The system will replace the default auto-respawn behavior with a custom death UI that gives players control over their respawn choice.

## Current System Analysis

### Existing Death/Ragdoll System
- **File**: `src/server/player/PlayerDeathHandler.server.lua`
- **Functionality**: Handles death events and applies ragdoll physics
- **Current Behavior**: Player dies → ragdoll applied → Roblox auto-respawn occurs

### Auto-Respawn Status
- **Current State**: Roblox's default auto-respawn is active
- **Issue**: Players automatically respawn without choice
- **Solution**: Disable auto-respawn and implement custom respawn system

### UI Pattern Analysis
- **Project Convention**: Uses manually created UI elements in Studio
- **Pattern**: Avoid `Instance.new()` calls, reference existing UI via `WaitForChild()`
- **Example**: `BackpackUI.client.lua` follows this pattern
- **RemoteEvents**: Pre-defined in `default.project.json` structure

## Desired Death Event Flow

```
Player Dies
    ↓
Player Ragdolls (existing system)
    ↓
Auto-Respawn Disabled
    ↓
Death UI Appears
    ↓
┌─────────────────────────────────────┐
│          DEATH SCREEN              │
│                                     │
│     You have died!                  │
│                                     │
│   Time remaining: 30 seconds        │
│                                     │
│  [Respawn]    [Back to Lobby]      │
│                                     │
└─────────────────────────────────────┘
    ↓
Player Choice:
├── Click "Respawn" → Player respawns immediately
├── Click "Back to Lobby" → Do nothing (placeholder for now)
└── 30 seconds expire → Forced back to lobby
```

## Implementation Plan

### 1. Add RemoteEvents to Project Structure
**File**: `default.project.json`
**New RemoteEvents**:
- `PlayerRespawn` - Client requests respawn
- `BackToLobby` - Client requests lobby return  
- `ShowDeathUI` - Server triggers death UI display

### 2. Modify Death Handler
**File**: `src/server/player/PlayerDeathHandler.server.lua`
**Changes**:
- Disable auto-respawn by setting `Players.CharacterAutoLoads = false`
- Fire `ShowDeathUI` RemoteEvent when player dies/ragdolls
- Add 30-second timer with forced lobby action
- Track death state per player

### 3. Create Death UI Client
**File**: `src/client/ui/DeathUI.client.lua`
**Pattern**: Follow `BackpackUI.client.lua` structure
**Functionality**:
- Reference manually created UI elements from StarterGui
- Show death screen with "Respawn" and "Back to Lobby" buttons
- Display 30-second countdown timer
- Handle button clicks via RemoteEvents
- Hide UI when player respawns

### 4. Create Death Service
**File**: `src/server/services/DeathService.server.lua`
**Functionality**:
- Handle `PlayerRespawn` RemoteEvent → `player:LoadCharacter()`
- Handle `BackToLobby` RemoteEvent → placeholder (do nothing for now)
- Manage timer system and force lobby return after 30 seconds
- Clean up death state tracking

### 5. UI Structure (to be created in Studio)
**StarterGui Structure**:
```
StarterGui
└── DeathGui (ScreenGui)
    └── DeathFrame (Frame - main container)
        ├── TitleLabel (TextLabel - "You have died!")
        ├── TimerLabel (TextLabel - countdown display)
        ├── ButtonFrame (Frame - button container)
        │   ├── RespawnButton (TextButton)
        │   └── LobbyButton (TextButton)
        └── Background (ImageLabel/Frame - optional styling)
```

## Technical Requirements

### Server-Side Changes
1. **PlayerDeathHandler.server.lua**:
   - Set `Players.CharacterAutoLoads = false` on server start
   - Fire `ShowDeathUI` RemoteEvent on death
   - Start 30-second countdown timer per player

2. **DeathService.server.lua** (new file):
   - Handle respawn/lobby RemoteEvents
   - Manage death timers
   - Force lobby return on timeout

### Client-Side Changes
1. **DeathUI.client.lua** (new file):
   - Reference manually created UI elements
   - Show/hide death screen based on server events
   - Handle button interactions
   - Display countdown timer

### Project Structure Changes
1. **default.project.json**:
   - Add new RemoteEvents to Remotes folder
   - Ensure proper RemoteEvent structure

## Implementation Steps

1. ✅ Research current death/ragdoll system implementation
2. ✅ Examine existing UI structure and patterns  
3. ✅ Check current auto-respawn system
4. ✅ Create detailed implementation plan
5. ⏳ Add PlayerRespawn and BackToLobby RemoteEvents to project structure
6. ⏳ Modify PlayerDeathHandler to disable auto-respawn and trigger death UI
7. ⏳ Create DeathUI.client.lua following project UI patterns
8. ⏳ Create DeathService.server.lua to handle respawn/lobby logic
9. ⏳ Implement 30-second countdown with forced lobby return
10. ⏳ Test death event flow and UI functionality

## Notes

- **Lobby Functionality**: "Back to Lobby" button will do nothing initially as separate place/experience isn't created yet
- **UI Convention**: Follow project pattern of manually creating UI in Studio rather than using `Instance.new()`
- **RemoteEvent Pattern**: All RemoteEvents pre-defined in project structure, accessed via `WaitForChild()`
- **Timer System**: 30-second countdown with visual feedback, forced action on timeout
- **State Management**: Track death state per player to prevent conflicts
- **Performance**: Minimal impact on existing systems, leverages current ragdoll implementation