here’s a focused review and an optimization plan without changing any code yet.

Most critical issues
•  Duplicate per-frame work
•  You have two Heartbeat listeners: one in DayNightCycle updating time every frame and another in Lighting polling every frame to detect period changes. That doubles per-frame compute and garbage.
•  Per-frame server replication of Lighting
•  DayNightCycle sets Lighting.ClockTime every Heartbeat on the server, and Lighting tweens server-side. Lighting property changes replicate to all clients; doing this every frame (and especially tweening) creates continuous network replication and can cause jitter on lower-end clients.
•  Polling instead of signaling
•  Lighting determines period changes by polling getCurrentPeriod() each frame. DayNightCycle also computes period transitions. This is redundant and wastes cycles.
•  Service lookups inside hot path
•  DayNightCycle calls game:GetService("Lighting") inside updateTime. That’s minor but unnecessary churn on a per-frame path.
•  Unused update interval configuration
•  TimeConfig.UPDATE_INTERVAL exists but is not used. The system runs every frame regardless of that setting, leaving a tuning knob unused.
•  Preset field mismatch
•  LIGHTING_PRESETS include ClockTime but Lighting tween/apply functions don’t use it. This can cause confusion and unnecessary data in presets, and risks accidental application later in a hot path.

High-impact performance upgrades
•  Switch to event-driven period changes
•  Have DayNightCycle emit a PeriodChanged signal when the period changes, and make Lighting subscribe. Remove the Heartbeat polling in Lighting.
•  Impact: cuts one whole per-frame loop and eliminates repeated period computations.
•  Move visual work to the client; keep time authoritative on the server
•  Server: maintain current time and fire lightweight events (e.g., PeriodChanged, rare re-sync packets).
•  Client: set Lighting.ClockTime each frame locally and tween Lighting properties on period changes. Optionally re-sync time from server every N seconds to correct drift.
•  Impact: massively reduces replication traffic; smoother visuals per client; server does far less work.
•  Throttle updates using the existing UPDATE_INTERVAL
•  If you prefer server-driven ClockTime, update on a fixed cadence (e.g., 10–20 Hz) instead of every Heartbeat. Compute currentTime from os.clock so it stays accurate even when ticking less frequently.
•  Impact: reduces per-frame cost and replication bandwidth while keeping time accurate.
•  Cache services and constants outside hot paths
•  Cache Lighting, TweenService, and any TweenInfo objects outside update loops.
•  Impact: small but free micro-optimization; avoids repeated lookups/allocations each frame.
•  Minimize tween churn
•  Only create a tween on actual period changes; cancel and replace safely when transitioning. You already cancel currentTween; ensure transitions can’t thrash if periods toggle quickly (rare).
•  Impact: avoids unnecessary object allocations; smoother transitions.
•  Reduce state checks and allocations in hot path
•  Avoid calling getCurrentPeriod() multiple times per frame across modules; compute once and broadcast.
•  Avoid string.format or other formatting in any per-frame path (keep formatting to debug/inspection).
•  Clarify preset usage
•  Either remove ClockTime from presets (since time advances independently), or explicitly use it only on period boundary if desired. Be consistent to avoid extra writes to Lighting.
•  Impact: reduces risk of accidental, redundant property changes.

Optional improvements
•  Use attributes or a single replicated Value object for time sync
•  Use e.g., Lighting:SetAttribute("GameTime") or a Value in ReplicatedStorage to expose time, and let clients compute visuals. Fire a RemoteEvent only for period changes.
•  Server fallback tick
•  If moving visuals client-side, the server can tick as slowly as needed (e.g., 2–5 Hz) just to maintain authoritative time for game logic and period transitions.

Expected impact summary
•  Removing the Lighting Heartbeat and switching to period signals: medium CPU reduction server-side, cleaner architecture.
•  Moving visual updates (ClockTime + tweens) to clients: large reduction in network replication and server work; smoother client visuals.
•  Throttling updates (if server-driven visuals retained): moderate reduction in CPU and replication overhead.
•  Caching and micro-optimizations: small but free gains and less GC pressure.