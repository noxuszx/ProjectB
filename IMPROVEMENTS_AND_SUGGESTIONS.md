# Project Improvement Suggestions

This document outlines potential improvements for various systems in the project.

---

## VillageSpawner.lua Improvements

### [] 1. Enforce Minimum Distance Between Villages
*   **Issue**: The spawner picks random locations for villages without checking if they are too close to already spawned villages, causing them to overlap.
*   **Suggestion**: Implement a "check-then-add" logic. Before spawning a new village, check its proposed location against a list of already spawned village positions. Ensure the distance is greater than a new configuration value (e.g., `MIN_VILLAGE_DISTANCE`). Only if the location is valid, spawn the village and add its position to the list.

---

## CustomModelSpawner.lua Improvements

### [] 1. Remove Generation Delay to Improve Performance
*   **Issue**: The `wait(ModelSpawnerConfig.GENERATION_DELAY)` call inside the main spawning loop artificially slows down the entire world generation process.
*   **Suggestion**: Remove the `wait()` call completely. Initial world generation should be as fast as possible. A brief, one-time period of high CPU usage during the loading screen is preferable to a long, drawn-out loading time.

### [] 2. Implement Bounding Box Check to Avoid Overlapping
*   **Issue**: The spawner currently places models without checking if the area is already occupied by other objects like villages or creature spawners, leading to models spawning on top of each other.
*   **Suggestion**: Before placing a model, use the `workspace:GetPartsInBox()` method to check if the target area is clear. This provides a simple and reliable way to detect any existing parts (excluding the terrain itself) and prevent the spawner from placing models in occupied space.

---

## FoodDropSystem.lua Improvements

### [] 1. Centralize Tags in `CollectionServiceTags`
*   **Issue**: The string `"Consumable"` is hardcoded in `FoodDropSystem.lua`.
*   **Suggestion**: Add a `CONSUMABLE` field to the `CollectionServiceTags` module to avoid magic strings and improve maintainability.

### [] 2. More Robust Unique Naming
*   **Issue**: `tick()` is used for generating unique food model names. While likely sufficient, it could theoretically produce collisions in high-frequency scenarios.
*   **Suggestion**: For greater robustness, consider using a simple incrementing counter or a dedicated UUID library if available.

### [] 3. Use a Raycast Whitelist for Drops
*   **Issue**: The raycast in `getDropPosition` uses a blacklist to ignore the `foodFolder`. This could allow food to spawn on unintended objects.
*   **Suggestion**: Switch to a whitelist to ensure food only spawns on designated surfaces like terrain.

### [] 4. Tag-Based Cooking Surface Detection
*   **Issue**: Cooking surfaces are detected by checking model names with `string.find`, which can be error-prone.
*   **Suggestion**: Use `CollectionService` to add a `"CookingSurface"` tag to all valid cooking models. This makes detection more explicit and reliable.

### [] 5. Optimize `onTouched` Function
*   **Issue**: The `isCooked` check is performed after other checks in the `onTouched` function.
*   **Suggestion**: Move the `isCooked` check to the beginning of the function to exit earlier and improve efficiency.

---

## BaseCreature.lua Improvements

### [] 1. Deferred Destruction with `Debris` Service
*   **Issue**: Destroying a creature's model (`model:Destroy()`) synchronously in the `die()` function can cause a lag spike.
*   **Suggestion**: Use the `Debris` service (`Debris:AddItem(model, 0)`) to defer the destruction of the model to the next frame. This will prevent the main game thread from being blocked and will result in a smoother experience.
