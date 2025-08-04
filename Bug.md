 Cash Collection Frame Drop Investigation Report

  Problem Statement

  Issue: First-time cash collection via proximity prompt causes a significant frame drop that
  appears in the MicroProfiler.
  Observed Behavior: Frame drop occurs after holding E on a cash object and the UI reflects the
  money update. *Player Holds E -> Money UI Updates  -> Framedrop

  MicroProfiler Analysis

  Initial Findings:
  - Long Worker thread activity
  - Write Marshalled event
  - Main/RenderViewUpdate with WaitForLock underneath

  After Animation Removal:
  - RenderViewUpdate/WaitForLock disappeared ✅
  - Write Marshalled persists ❌

  Investigation Steps Taken

  1. Initial Hypothesis - UI Creation Overhead

  Theory: Runtime UI creation causing first-time initialization lag
  Action: Suggested migrating from runtime Instance.new() UI creation to Studio-created UI
  Files Modified: EconomyUI.client.lua - replaced createMoneyUI() with initializeExistingUI()
  Result: User reported this wasn't the actual problem

  2. Animation System Analysis

  Theory: RunService.Heartbeat animation loop blocking render thread
  Issue Identified: updateMoneyDisplay() function (lines 44-102) contained:
  - RunService.Heartbeat connection running every frame
  - Expensive tick(), math.floor(), and tostring() calculations per frame
  - Simultaneous TweenService + RunService animations
  - String operations on every heartbeat

  Action: Temporarily disabled animation with simple direct update
  Files Modified: EconomyUI.client.lua:44-53
  Result: RenderViewUpdate/WaitForLock disappeared, confirming animation was causing render
  thread blocking

  3. Debug Logging Investigation

  Theory: Print statements causing Write Marshalled overhead
  Issue Identified: Debug logging enabled in EconomyConfig.lua with multiple print statements
  firing during cash collection:
  - EconomyService.lua:114 - Server-side money change log
  - CashCollectionHandler.server.lua:68 - Cash collection log
  - EconomyUI.client.lua:51 - Client-side money update log

  Action: Disabled debug logging by setting Debug.Enabled = false
  Files Modified: EconomyConfig.lua:89
  Result: Write Marshalled persists - this was not the root cause

  Current System Architecture

  Cash Collection Flow

  1. ProximityPrompt triggered → CashCollectionHandler.server.lua:onCashCollected()
  2. Server validates → EconomyService.addMoney(player, cashValue)
  3. RemoteEvent fires → updateMoneyRemote:FireClient(player, newAmount)
  4. Client receives → onMoneyUpdated() → updateMoneyDisplay()
  5. Cash item destroyed → cashItem:Destroy()

  Files Involved

  - CashCollectionHandler.server.lua - Proximity prompt handling
  - EconomyService.lua - Money management and RemoteEvent firing
  - EconomyUI.client.lua - Client-side UI updates
  - EconomyConfig.lua - Configuration and debug settings

  Remaining Issues

  Write Marshalled Persists

  Current Status: Still present in MicroProfiler after:
  - ✅ Animation removal (eliminated RenderViewUpdate/WaitForLock)
  - ❌ Debug logging disabled (no effect)

  Potential Remaining Causes

  1. RemoteEvent overhead - updateMoneyRemote:FireClient() marshalling
  2. Object destruction - cashItem:Destroy() sending data to clients
  3. Other system interactions - Unknown systems triggered by money changes
  4. First-time RemoteEvent setup - Initial RemoteEvent connection overhead

  Next Investigation Steps

  1. Profile RemoteEvent alone - Test with minimal RemoteEvent fire, no UI updates
  2. Check for cascading system calls - Look for other systems listening to money changes
  3. Investigate object destruction timing - Test delaying cashItem:Destroy()
  4. Monitor for unknown RemoteEvents - Check if other systems fire during cash collection

  Files Modified During Investigation

  - src/client/ui/EconomyUI.client.lua - UI creation method and animation logic
  - src/shared/config/EconomyConfig.lua - Debug settings

  The RenderViewUpdate/WaitForLock issue has been resolved, but the Write Marshalled root cause
  remains unidentified