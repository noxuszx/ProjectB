Pedestal Ball Detection System - Complete Design Document

  Game Overview & Objective

  Game Flow

  1. Player spawns → Climbs 3 towers → Collects 1 ball from each tower top
  2. Goes to pyramid → Finds 3 pedestals → Places balls on pedestals (any order)
  3. All pedestals occupied → Egypt door slides down → Player can enter

  System Goal

  Create a ZonePlus-based detection system that monitors ball placement on pedestals and
  controls the Egypt door accordingly.

  Technical Requirements

  Core Behavior

  - Door Opens: When ALL 3 pedestals have balls placed on them
  - Door Closes: When ANY ball is removed from any pedestal
  - Ball Flexibility: Any ball can go on any pedestal (no specific matching required)
  - Player Disconnect: Balls drop normally, system continues to work

  Visual Requirements

  - No visual feedback on pedestals (for now)
  - Smooth door animation - slides down to open, slides up to close
  - Responsive detection - immediate response to ball placement/removal

  Implementation Plan

  Files to Create

  1. src/server/events/PedestalController.server.lua

  Main System Controller

  Responsibilities:
  - Initialize the entire pedestal detection system
  - Create ZonePlus zones around each pedestal
  - Track occupancy state of all pedestals
  - Coordinate door opening/closing

  Key Functions:
  -- Find all PEDESTAL tagged parts and create zones
  local function setupPedestals()

  -- Handle when ball enters any pedestal zone
  local function onBallEntered(zone, ball, pedestalIndex)

  -- Handle when ball exits any pedestal zone  
  local function onBallExited(zone, ball, pedestalIndex)

  -- Check if all pedestals occupied and control door
  local function evaluateDoorState()

  State Management:
  local pedestalStates = {
      pedestal1 = false,
      pedestal2 = false,
      pedestal3 = false
  }

  2. src/server/events/EgyptDoor.lua

  Door Animation Module

  Responsibilities:
  - Find and control the Egypt door
  - Provide smooth animation between open/closed states
  - Handle animation interruptions gracefully

  Public API:
  local EgyptDoor = {}
  function EgyptDoor.openDoor()  -- Slide door down
  function EgyptDoor.closeDoor() -- Slide door up
  return EgyptDoor

  Animation Details:
  - Use TweenService for smooth movement
  - Calculate positions based on door's initial placement
  - Door moves vertically (Y-axis) - down to open, up to close
  - Tween duration: ~2-3 seconds with smooth easing

  CollectionService Tags Required

  Add to CollectionServiceTags.lua:

  -- Puzzle system tags
  CollectionServiceTags.PEDESTAL = "PEDESTAL"     -- For pedestal parts in pyramid
  CollectionServiceTags.EGYPT_DOOR = "EGYPT_DOOR" -- For the sliding door
  CollectionServiceTags.TOWER_BALL = "TOWER_BALL" -- For collectible balls from towers

  Technical Implementation Details

  ZonePlus Integration

  - Zone Creation: Create zone around each PEDESTAL tagged part
  - Zone Sizing: Slightly larger than pedestal to allow easy ball placement
  - Zone Positioning: Above pedestals to properly detect dropped/placed balls
  - Multiple Zones: One zone per pedestal, tracked individually

  Ball Detection Logic

  -- Only respond to TOWER_BALL tagged parts
  if not CollectionService:HasTag(part, "TOWER_BALL") then
      return
  end

  -- Update pedestal state
  pedestalStates[pedestalIndex] = (ballCount > 0)

  -- Evaluate if door should open/close
  evaluateDoorState()

  Door Control Logic

  local function evaluateDoorState()
      local allOccupied = pedestalStates.pedestal1 and
                         pedestalStates.pedestal2 and
                         pedestalStates.pedestal3

      if allOccupied then
          EgyptDoor.openDoor()
      else
          EgyptDoor.closeDoor()
      end
  end

  Edge Cases Handled

  - Multiple balls on one pedestal: Still counts as occupied
  - Ball removal during door animation: Interrupts and reverses
  - Player disconnect: Balls drop, zones detect exit normally
  - Missing components: Graceful warnings if tags not found

  Performance Considerations

  - Zone efficiency: ZonePlus handles optimization internally
  - State tracking: Minimal memory footprint with boolean states
  - Animation: Single tween per door operation, cancel previous if needed

  System Flow Diagram

  Game Start
      ↓
  PedestalController initializes
      ↓
  Find PEDESTAL tagged parts → Create ZonePlus zones
      ↓
  Find EGYPT_DOOR tagged part → Initialize EgyptDoor module
      ↓
  Listen for TOWER_BALL zone enter/exit events
      ↓
  Ball placed → Zone detects → Update state → Check all pedestals
      ↓
  All occupied? → YES: Open door | NO: Keep door closed
      ↓
  Ball removed → Zone detects → Update state → Close door immediately

  Testing Scenarios

  1. Basic Flow: Place all 3 balls → door opens → remove 1 ball → door closes
  2. Order Independence: Place balls in different orders → door always opens when complete
  3. Multiple Balls: Place multiple balls on same pedestal → still works correctly
  4. Rapid Changes: Quickly add/remove balls → door responds appropriately
  5. Player Disconnect: Player leaves with ball equipped → ball drops → system updates