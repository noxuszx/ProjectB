# Player Stats System Design

This document outlines the design for a simple, robust, and reliable Health, Hunger, and Thirst system. The core philosophy is **server authority**, where the server manages all stats and the client is only responsible for displaying them.

---

## System Components

The system will consist of three main components:

1.  **Server-Side Logic:** `PlayerStatsManager.lua`
2.  **Client-Side Display:** `StatsDisplay.client.lua`
3.  **Shared Components:** A configuration file and a `RemoteEvent`. (remote event will be manually added by me in the studio)

---

## 1. Server-Side Logic: `PlayerStatsManager.lua`

This module is the brain of the operation, managing the stats for all players from a single, authoritative script.

*   **Location:** `src/server/player/PlayerStatsManager.lua`
*   **Responsibilities:**
    *   **Data Storage:** Maintain a table where the key is the `player` object and the value is a table of their stats (e.g., `{ Health = 100, Hunger = 100, Thirst = 100 }`).
    *   **Player Tracking:** Use `Players.PlayerAdded` and `Players.PlayerRemoving` to create and clean up stat tables for players.
    *   **Stat Decay Loop (The "Ticker"):** A persistent `while wait(interval) do` loop that runs on the server. On each tick, it will:
        1.  Iterate through all online players.
        2.  Decrease their Hunger and Thirst according to the config.
        3.  Check for starvation or dehydration (if Hunger or Thirst is 0) and apply damage if necessary.
        4.  Fire a `RemoteEvent` to send the updated stats to the client.
    *   **API Functions:** Provide a clear API for other server scripts:
        *   `PlayerStatsManager.TakeDamage(player, amount)`
        *   `PlayerStatsManager.Heal(player, amount)`
        *   `PlayerStatsManager.AddHunger(player, amount)`
        *   `PlayerStatsManager.AddThirst(player, amount)`

---

## 2. Client-Side Display: `StatsDisplay.client.lua`

This `LocalScript` is responsible for all UI-related tasks on the client.

*   **Location:** `src/client/StatsDisplay.client.lua`
*   **Responsibilities:**
    *   **UI Management:** Create and manage the Health, Hunger, and Thirst UI elements (status bars, text labels, etc.).
    *   **Event Listener:** Listen for the `UpdatePlayerStats` `RemoteEvent` from the server.
    *   **UI Updates:** When the event is received, update the size, color, and text of the UI elements to reflect the new stats sent by the server. The client performs no stat calculations itself.

---

## 3. Shared Components

These components are accessible by both the server and the client to ensure consistency.

### Configuration File: `PlayerStatsConfig.lua`

*   **Location:** `src/shared/config/PlayerStatsConfig.lua`
*   **Purpose:** To centralize all balanceable variables for the system.
*   **Example Content:**
    ```lua
    return {
        MAX_HEALTH = 100,
        MAX_HUNGER = 100,
        MAX_THIRST = 100,

        TICK_INTERVAL = 5, -- Seconds between each decay tick
        HUNGER_DECAY_PER_TICK = 0.5,
        THIRST_DECAY_PER_TICK = 1.0,

        STARVATION_DAMAGE_PER_TICK = 2,
        DEHYDRATION_DAMAGE_PER_TICK = 3,
    }
    ```

### Remote Event: `UpdatePlayerStats`

*   **Location:** `ReplicatedStorage`
*   **Purpose:** To act as the secure communication channel between the server and the client.
*   **Workflow:**
    1.  **Server:** `UpdatePlayerStats:FireClient(player, newStatsTable)`
    2.  **Client:** `UpdatePlayerStats.OnClientEvent:Connect(function(newStatsTable) ... end)`

---

## Design Benefits

*   **Simple & Centralized:** Core logic is contained in a single manager script.
*   **Secure & Robust:** Server authority prevents client-side exploits.
*   **Efficient & Lightweight:** A single server loop and minimal network traffic make it highly performant.
*   **Decoupled & Modular:** Other game systems (like food consumption) can interact with the stats system through a clean API without needing to know about its internal workings.
