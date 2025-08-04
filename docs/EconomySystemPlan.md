# Economy System Implementation Plan

## Overview
A roguelike economy system that integrates with the existing drag/drop system. Players collect sellable items, drag them to sell zones for instant money, then use that money to buy items from buy zones with visual affordability indicators.

## System Architecture

### 1. Configuration (`src/shared/config/EconomyConfig.lua`)
- **Sellable Items**: 3 tiers with CollectionService tags
  - `SELLABLE_LOW`: 15 coins (scrap metal, wood scraps, cloth)
  - `SELLABLE_MID`: 25 coins (refined materials, tools, electronics)
  - `SELLABLE_HIGH`: 50 coins (gems, advanced components, rare metals)
- **Buyable Items**: Configurable spawn list with costs and weights
- **Zone Settings**: Touch cooldowns, spawn heights, interaction ranges
- **UI Settings**: Colors, positions, sizes for money display
- **Performance Settings**: Batch processing, debounce timers

### 2. Server-Side Core (`src/server/services/EconomyService.lua`)
- **Player Money Management**: Session-based (resets on join)
- **Sell System**: 
  - Listen for SELLABLE_* tagged items touching SELL_ZONE tagged parts
  - Validate item ownership via drag/drop system integration
  - Destroy item and award coins instantly
  - Debounce protection against spam
- **Buy System**:
  - Manage buy-once restrictions per zone
  - Handle ammo items (multiple purchases allowed)
  - Spawn items directly on buy zone parts
  - Validate player has sufficient funds
- **Integration**: Extend existing player stats system for money storage

### 3. Client-Side UI (`src/client/ui/EconomyUI.client.lua`)
- **Money Display**: 
  - Green background with white text
  - Gold dollar sign on left, money amount on right
  - Positioned on right side, above inventory counter
  - Smooth animations for money changes
- **Buy Zone Highlighting**:
  - Green highlight when affordable
  - Red highlight when not affordable
  - Updates in real-time as money changes
  - Uses existing highlighting system

### 4. Network Architecture (`default.project.json` additions)
New RemoteEvents structure:
```
Remotes/
├── Economy/
│   ├── SellItem         (Client → Server)
│   ├── BuyItem          (Client → Server) 
│   ├── UpdateMoney      (Server → Client)
│   └── RefreshBuyZones  (Server → Client)
```

## Implementation Flow

### Selling Process
1. Player drags SELLABLE_* tagged item to SELL_ZONE part
2. Server detects Touched event via CollectionService
3. Validate item has sellable tag and isn't on cooldown
4. Award money based on tag type (15/25/50)
5. Destroy item instantly
6. Update client money display
7. Apply cooldown to prevent spam

### Buying Process  
1. Player approaches BUY_ZONE tagged part
2. Client highlights zone green (affordable) or red (not affordable)
3. Proximity prompt appears when in range
4. Player activates prompt
5. Server validates money and zone availability
6. Deduct cost and spawn random item on zone
7. Mark zone as used (except for ammo items)
8. Update all clients with new money amount

### Item Spawning & Tagging
- **World Spawns**: Items spawn with appropriate SELLABLE_* tags
- **Buy Zone Items**: Purchased items spawn as DRAGGABLE (existing system)
- **Ammo Exception**: Allow multiple purchases from same zone

## Performance Optimizations

### CollectionService Integration
- Use existing tag system for maximum performance
- Leverage GetTagged() for efficient zone detection
- Minimal memory footprint

### Event Batching
- Batch money updates when multiple items sold quickly
- Debounce touch events to prevent double-processing
- Cache buy zone states to reduce network calls

### Highlighting Efficiency
- Update buy zone highlights only when money changes
- Use distance-based highlighting (only nearby zones)
- Reuse existing highlight objects

## File Structure
```
src/
├── shared/
│   └── config/
│       └── EconomyConfig.lua
├── server/
│   ├── services/
│   │   └── EconomyService.lua
│   └── handlers/
│       ├── SellZoneHandler.server.lua
│       └── BuyZoneHandler.server.lua
└── client/
    └── ui/
        └── EconomyUI.client.lua
```

## Integration Points

### With Existing Systems
- **PlayerStatsConfig**: Add money field to player data
- **DragDropSystem**: Sellable items work with existing dragging
- **CollectionService**: Use existing tag infrastructure  
- **UI System**: Position relative to existing inventory counter
- **Highlighting**: Extend existing object highlighting system

### Tag Dependencies
- **Existing**: DRAGGABLE, STORABLE (maintained)
- **New**: SELLABLE_LOW, SELLABLE_MID, SELLABLE_HIGH
- **New**: SELL_ZONE, BUY_ZONE

## Testing Strategy
1. **Unit Tests**: Sell/buy individual items, money calculations
2. **Integration Tests**: Drag sellable items to sell zones
3. **Performance Tests**: Rapid selling, multiple buy zones
4. **Edge Cases**: Simultaneous selling, network lag scenarios
5. **UI Tests**: Money display updates, highlighting accuracy

## Rollout Plan
1. **Phase 1**: Core config and server service
2. **Phase 2**: Sell zone system with basic UI
3. **Phase 3**: Buy zone system with highlighting
4. **Phase 4**: Polish, optimization, and testing
5. **Phase 5**: Integration testing with full game systems

## Risk Mitigation
- **Exploit Prevention**: Server-side validation of all transactions
- **Performance**: Debouncing and batching to prevent spam
- **Network**: Minimal RemoteEvent calls, efficient data structures
- **Integration**: Careful testing with existing drag/drop system

This system leverages your existing architecture patterns while adding minimal overhead. The session-based nature keeps it simple and performant for a roguelike experience.