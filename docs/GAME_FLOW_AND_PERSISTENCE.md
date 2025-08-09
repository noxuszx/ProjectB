# Game Flow and Persistence Plan

## User’s Game Flow (verbatim)

"the readme is a bit outdated but heres how a normal playthrough goes for a player:
Player enters lobby (different place/experince) -> player enters queue zone to team up with players if they want  -> player gets teleported to different place (this is the current experience/place  what you are seeing now) -> Player enters the game -> player explores -> player conquers towers and retrieves all progression orbs -> player places orbs at pedestals in pyramid to trigger ending event -> player finshes ending event -> player gets a +1 win on leaderboard and most number of days survived  is also included in leaderboard. Leaderboard is the same for players in the lobby place and in the game place. Is this the part where we use profile stores?"

## Assistant’s Recommendation (verbatim)

"Short answer: Yes—this is exactly where you use a player profile store (e.g., ProfileService over DataStoreService) to persist cross-place stats like total wins and best days survived, and then use an OrderedDataStore for the visible “top players” leaderboard.

Recommended setup
- Persisted player profile (ProfileService):
  - Keys are per-user (e.g., Player_<UserId>) and shared across your lobby place and game place (same universe/scope).
  - Suggested schema:
    - totalWins: number (increment when a run is completed)
    - bestDaysSurvived: number (update if this run’s days > best)
    - optionally: lifetimeDaysSurvived, lastRunDays, lastCompletedAt, etc.
  - Load on PlayerAdded in both places using ProfileService.LoadProfileAsync with session locking and a template.
  - Update on end-of-run (when the ending event completes) before teleporting back or returning to lobby.

- Global leaderboard (OrderedDataStore):
  - If you want a universal top list visible in both places, write to an OrderedDataStore at the same time as you update the profile.
  - You can maintain:
    - Top by totalWins (keyed by userId, value = totalWins)
    - Top by bestDaysSurvived (keyed by userId, value = bestDaysSurvived)
  - If you want a single combined board, encode a sortable value, e.g. value = totalWins * 1_000_000 + bestDaysSurvived for tie-breaking by days.
  - Read top N entries in both places to display the same board.

- Session vs persistent data:
  - Your session-based money should remain non-persistent (resets each join).
  - The run outcome (win count and best days) is persistent and written once at the end of the run.

- Teleport and cross-place flow:
  - Use TeleportService with TeleportData for transient run context (party info, seeds, etc.), not for long-term stats.
  - The lobby and game places both load/update the same ProfileService store; no special cross-place plumbing needed for persistence.

- Reliability tips:
  - Use ProfileService with a template and .Reconcile() to handle new fields.
  - Respect session locking and .ListenToRelease to handle server shutdowns/kicks safely.
  - Debounce end-of-run updates (prevent double increments on retries).
  - For OrderedDataStores, update only when values change (e.g., on run completion), not every frame.
  - Consider MemoryStoreService for the queue/party system; don’t store queue state in ProfileService.

Typical end-of-run logic
1) Determine this run’s daysSurvived and whether the ending event was completed.
2) Load player profile (if not already loaded) and:
   - totalWins += 1 (if completed)
   - bestDaysSurvived = max(bestDaysSurvived, daysSurvived)
3) Write to OrderedDataStores:
   - SetAsync(userId, totalWins) for the Wins board
   - SetAsync(userId, bestDaysSurvived) for the Days board
   - or update a combined board as needed
4) Confirm success, then teleport back to lobby.

If you want, I can inspect your codebase for the current data layer and sketch the exact integration points (e.g., where the ending event fires, where PlayerAdded/Removing are handled), and suggest concrete code using ProfileService and OrderedDataStores."
