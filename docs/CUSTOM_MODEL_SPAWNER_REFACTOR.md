# CustomModelSpawner Refactoring Plan

## Overview
Refactor the CustomModelSpawner system to create a more efficient, maintainable, and performant environmental prop spawning system that properly integrates with existing world structures.

## Design Goals
1. **Performance**: Minimize server frame time through efficient spatial queries
2. **Visual Quality**: Dense, natural-looking prop placement around structures
3. **Reliability**: Predictable spawning with proper collision avoidance
4. **Maintainability**: Clean separation of concerns with modern Roblox patterns

## Current Issues
- ❌ Weighted selection not implemented despite config support
- ❌ Heavy overlap detection using string comparisons
- ❌ Distance-based spacing prevents natural clustering near structures
- ❌ No spawn point protection (0,0,0 radius)
- ❌ Duplicate batch size configurations

## Technical Approach

### 1. Spatial Query Optimization

#### Industry Standard: Spatial Hashing with CollectionService
Instead of string-based filtering, use Roblox's CollectionService for O(1) tag lookups:

```lua
-- Protected geometry tagging system
local PROTECTED_TAGS = {
    VILLAGE = "ProtectedVillage",
    CORE = "ProtectedCore", 
    SPAWNER = "ProtectedSpawner"
}
```

**Benefits:**
- Native C++ performance for tag queries
- No string comparisons in hot paths
- Easy to debug with Studio's tag editor
- Follows Roblox's recommended pattern for entity filtering

#### Overlap Detection Strategy
Use `workspace:GetPartBoundsInBox()` with pre-cached OverlapParams:

```lua
-- Cache OverlapParams at module level (allocated once)
local protectedOverlapParams = OverlapParams.new()
protectedOverlapParams.FilterType = Enum.RaycastFilterType.Include
protectedOverlapParams.MaxParts = 1  -- Early exit on first hit
```

**Key optimizations:**
- `MaxParts = 1` for early termination
- Pre-allocated OverlapParams avoids GC pressure
- Single spatial query instead of multiple raycasts

### 2. Weighted Random Selection

#### Implementation: Alias Method (O(1) selection)
For true weighted random with optimal performance:

```lua
-- Build alias tables during initialization
local function buildAliasTable(weights)
    -- Vose's Alias Method for O(1) weighted selection
    -- Precompute once, sample many times
end
```

**Alternative: Cumulative Distribution (simpler)**
```lua
local function buildCumulativeWeights(models, weights)
    local cumulative = {}
    local total = 0
    for i, model in ipairs(models) do
        local weight = weights[model.Name] or 1.0
        total = total + weight
        cumulative[i] = {model = model, threshold = total}
    end
    return cumulative, total
end
```

### 3. Spawn Protection Zone

#### Modern Approach: Attribute-based Configuration
```lua
-- Use workspace attributes for runtime configuration
workspace:SetAttribute("SpawnProtectionRadius", 50)
workspace:SetAttribute("SpawnProtectionHeight", 100)
```

**Benefits:**
- Visible in Studio properties
- Adjustable without code changes
- Follows Roblox's attribute pattern for configuration

### 4. Template Caching System

#### Object Pool Pattern
```lua
local TemplateCache = {}
TemplateCache.__index = TemplateCache

function TemplateCache.new()
    local self = setmetatable({}, TemplateCache)
    self.templates = {}
    self.boundingBoxes = {}
    self.primaryParts = {}
    return self
end

function TemplateCache:getTemplate(modelName)
    -- Lazy load and cache
    if not self.templates[modelName] then
        self:loadTemplate(modelName)
    end
    return self.templates[modelName]
end
```

**Benefits:**
- Reduced memory allocation
- Pre-computed bounding boxes
- Follows object pool pattern for efficiency

### 5. Frame Budget Integration

#### Single Source of Truth
```lua
-- ModelSpawnerConfig becomes the authority
local FRAME_BUDGETS = {
    Vegetation = {desktop = 10, mobile = 5},
    Rocks = {desktop = 5, mobile = 3},
    Structures = {desktop = 1, mobile = 1}
}

-- FrameBudgetConfig reads from ModelSpawnerConfig
function FrameBudgetConfig.getModelBatchSize(category)
    local config = ModelSpawnerConfig.FRAME_BUDGETS[category]
    local isMobile = UserInputService.TouchEnabled 
                     and not UserInputService.KeyboardEnabled
    return isMobile and config.mobile or config.desktop
end
```

### 6. Streaming-Enabled Compatibility

#### Future-proofing for StreamingEnabled
```lua
-- Use persistent models for templates
local function setupPersistentTemplates()
    for _, template in pairs(templates) do
        template:SetAttribute("StreamingMode", "Persistent")
    end
end

-- Handle streaming radius for prop density
local function getStreamingAdjustedDensity(baseConfig)
    if workspace.StreamingEnabled then
        local streamRadius = workspace.StreamingTargetRadius
        -- Adjust density based on streaming radius
        return baseConfig * math.min(1, streamRadius / 512)
    end
    return baseConfig
end
```

## Implementation Phases

### Phase 1: Core Infrastructure (Priority 1)
1. Implement CollectionService tagging in spawners
2. Create TemplateCache system
3. Add spawn protection zone check
4. Refactor overlap detection to use tags

### Phase 2: Optimization (Priority 2)
1. Implement weighted selection (cumulative method)
2. Consolidate frame budget configuration
3. Add template bounding box caching
4. Remove distance-based spacing logic

### Phase 3: Polish & Future-proofing (Priority 3)
1. Add streaming compatibility checks
2. Implement debug visualization tools
3. Add performance metrics collection
4. Create unit tests for critical functions

## Performance Targets
- **Spawn Time**: < 2 seconds for full world population
- **Frame Budget**: < 16ms per frame during spawning
- **Memory**: < 50MB for cached templates
- **Overlap Checks**: < 0.1ms per prop

## Testing Strategy

### Unit Tests
```lua
-- Test weighted selection distribution
function testWeightedSelection()
    local weights = {TreeA = 10, TreeB = 30, TreeC = 60}
    local samples = 10000
    local counts = {}
    -- Verify distribution matches weights within 5% tolerance
end

-- Test overlap detection accuracy
function testOverlapDetection()
    -- Place known protected geometry
    -- Verify props don't spawn inside
    -- Verify props can spawn adjacent
end
```

### Integration Tests
1. Spawn world with all systems active
2. Verify no props inside protected areas
3. Check spawn protection zone is clear
4. Measure frame times during spawning

### Performance Profiling
```lua
local ProfilingService = game:GetService("ProfilingService")
-- Use MicroProfiler tags for detailed analysis
debug.profilebegin("CustomModelSpawner:SpawnModel")
-- ... spawning logic
debug.profileend()
```

## Migration Path
1. **Backward Compatibility**: Keep existing API surface unchanged
2. **Feature Flag**: Use workspace attribute to toggle new system
3. **Gradual Rollout**: Test on internal servers before production
4. **Monitoring**: Track performance metrics post-deployment

## Code Quality Standards
- ✅ Type annotations for all public functions
- ✅ Consistent error handling with pcall for external calls
- ✅ Clear separation between configuration and logic
- ✅ Comprehensive inline documentation
- ✅ Follow Roblox-Lua style guide

## Risk Mitigation
- **Risk**: Tag collision with other systems
  - **Mitigation**: Use namespaced tags (e.g., "CMS:Protected")
  
- **Risk**: Performance regression on mobile
  - **Mitigation**: Adaptive batch sizes based on device
  
- **Risk**: Memory leaks from cached templates
  - **Mitigation**: Weak references for unused templates

## Success Metrics
- 50% reduction in overlap check time
- Natural prop clustering around structures
- Zero props in spawn protection zone
- Maintained 60 FPS during world generation

## References
- [Roblox CollectionService Best Practices](https://create.roblox.com/docs/reference/engine/classes/CollectionService)
- [Spatial Query Optimization](https://devforum.roblox.com/t/spatial-query-api/1016887)
- [Vose's Alias Method](https://www.keithschwarz.com/darts-dice-coins/)
- [Roblox Performance Guide](https://create.roblox.com/docs/production/performance)
