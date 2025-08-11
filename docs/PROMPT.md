Here’s a concrete, code-free plan for both items, focusing on architecture, data flow, timing math, and edge cases.

1) Event-Driven Period Changes (Architecture Refactor)
Goal
•  Stop polling every N seconds. Compute the exact moment of each upcoming period boundary and schedule a single callback to fire at that moment. On fire, emit a period-changed event, then schedule the next one.

Core idea
•  Represent game time as a function of a fixed epoch: currentTime = (START_TIME + (now - cycleStartEpoch) / DAY_LENGTH * 24) % 24.
•  Period boundaries are known constants in game hours (e.g., 5.5, 6.0, 8.0, …). Convert the delta between currentTime and the next boundary into real seconds and schedule a one-shot timer.

Scheduling math
•  Inputs:
•  nowSeconds = os.clock() on the server
•  cycleStartEpoch = when the current cycle started (seconds)
•  gameHours = (START_TIME + ((nowSeconds - cycleStartEpoch) / DAY_LENGTH) * 24) % 24
•  boundaries = [DAWN_START, SUNRISE_START, MORNING_START, …, wrap around to next day]
•  Find next boundary hour H_next > gameHours, else wrap to the first boundary + 24.
•  deltaHours = (H_next - gameHours) % 24
•  deltaRealSeconds = (deltaHours / 24) * DAY_LENGTH
•  Schedule a one-shot timer for deltaRealSeconds. When it fires:
•  Compute newPeriod from H_next.
•  Emit: PeriodChanged(newPeriod, oldPeriod).
•  Reschedule using the same procedure for the following boundary.

Lifecycle and rescheduling
•  On init:
•  Capture cycleStartEpoch.
•  Compute currentPeriod from currentTime (once).
•  Compute next boundary and schedule first timer.
•  On time jump (setTime, skipToNextPeriod, or START_TIME change):
•  Cancel any pending timer.
•  Recompute cycleStartEpoch consistent with the new currentTime.
•  Recompute currentPeriod and schedule the next boundary from the new now.
•  On server pause/hitch:
•  task.delay timers fire when resumed; on fire, always recompute currentTime from epoch rather than trusting drifting timers.
•  On config updates (e.g., DAY_LENGTH change at runtime):
•  Cancel, recompute, reschedule.

What this eliminates
•  No Heartbeat in DayNightCycle.
•  No 2-second polling anywhere for period changes. The only work happens:
•  Once at startup
•  Once per period transition
•  When explicit time control APIs are called

Precision and determinism
•  Period transitions happen at the mathematically exact boundary, derived from epoch + constants. Even if the server lags, the handler recomputes currentTime on wake and emits exactly one transition.

Emitted signals and consumers
•  Server emits a single PeriodChanged(newPeriod, oldPeriod) signal (server-internal).
•  If clients need to react to period changes:
•  Prefer: set a replicated attribute (see section 2) to the current period name only at transition times, eliminating event fan-out.
•  Alternative: a RemoteEvent fired once per transition (infrequent, reasonable if you already have this wiring).

2) Use Attributes for Time Sync (Network Optimization)
Goal
•  Replace high-frequency RemoteEvents with low-churn attributes that replicate automatically and allow clients to compute current time locally without per-frame replication.

What to replicate as attributes
•  Publish stable parameters that rarely change:
•  GameBaseEpochSeconds: number (server’s os.clock() when the current cycle baseline was established)
•  StartGameHours: number (the game hours at GameBaseEpochSeconds)
•  DayLengthSeconds: number (TimeConfig.DAY_LENGTH)
•  CurrentPeriod: string (optional, update only at transitions)
•  Optionally publish one-shot “version” or “resync” number to force clients to recompute if you change baselines.

Why this is efficient
•  Attributes replicate only when they change, not per frame.
•  Clients compute currentTime locally:
•  now = os.clock() on client
•  elapsed = now - GameBaseEpochSeconds (client’s monotonic clock; small drift is okay)
•  currentTime = (StartGameHours + (elapsed / DayLengthSeconds) * 24) % 24
•  No continuous network traffic to drive the clock or visuals.

Update cadence and drift
•  Because clients compute from a shared epoch, there’s no need to update GameTime every frame. Only update attributes when:
•  Init
•  Admin/time control changes (setTime/skip)
•  Config changes (DAY_LENGTH, START_TIME)
•  Period transitions (if you expose CurrentPeriod)
•  Drift correction:
•  If you’re concerned about clock skew, occasionally refresh GameBaseEpochSeconds and StartGameHours (e.g., every few minutes). This is a single attribute update, not a stream.

Client visualization pattern
•  Client reads attributes on join or change:
•  Compute currentTime continuously on the client render loop for smooth ClockTime.
•  Optionally subscribe to attribute change for CurrentPeriod to trigger tweens only at transitions.
•  This yields smooth visuals (client sets Lighting.ClockTime each frame locally) with near-zero replication.

Migration plan
•  Server:
•  Add attribute publisher on Lighting (or ReplicatedStorage if you prefer). Set initial GameBaseEpochSeconds, StartGameHours, DayLengthSeconds on init and resend them only when needed.
•  Replace RemoteEvents for periodic time updates with attributes. Keep RemoteEvents only for interactive commands if necessary.
•  From section 1, fire PeriodChanged internally; if clients need it, set Lighting:SetAttribute("CurrentPeriod", period) when it changes.
•  Client:
•  Remove RemoteEvent listeners for time ticks.
•  On attribute change or at startup, cache the three parameters and recompute on the fly each frame for ClockTime.
•  For period visuals (tweens), listen to attribute change of CurrentPeriod and tween once per change.

Edge cases and pitfalls
•  Don’t update a “GameTime” attribute every frame:
•  That defeats the purpose; attributes replicate on every change.
•  Publish baseline/parameters instead; let clients compute time.
•  Attribute scope:
•  Lighting is fine and globally available. Alternatively, ReplicatedStorage folder with a dedicated Instance and attributes is also standard.
•  Clock source:
•  Use os.clock() consistently on server and client for monotonic time deltas. Always recompute currentTime from baseline in handlers; avoid accumulating deltas that drift.
•  Late-joining players:
•  Attributes automatically replicate current values upon join. No special catch-up code needed beyond your client init routine.
•  Admin time jumps:
•  On DayNightCycle.setTime, update StartGameHours and GameBaseEpochSeconds so clients instantly “teleport” to the new time on their next frame. Also update CurrentPeriod to reflect the new period.

Impact summary
•  Event-driven period changes: minimal CPU, precise transitions, simpler logic.
•  Attribute-driven time sync: near-zero bandwidth during normal operation, instant client access, smooth local ClockTime, and single attribute change per period transition (if exposing CurrentPeriod).