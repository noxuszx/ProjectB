-- src/shared/config/DragDropConfig.lua
-- Configuration file for the Drag and Drop System
-- This file defines settings for dragging, welding, and object interaction

local DragDropConfig = {
    -- Physics and interaction settings
    DRAG_RANGE = 12,                    -- Maximum distance to detect draggable objects
    CARRY_DISTANCE = 9,                 -- Distance to maintain objects while dragging
    MAX_CARRY_DISTANCE = 20,            -- Maximum distance before auto-dropping
    CARRY_SMOOTHNESS = 0.06,            -- Smoothing factor for drag movement
    THROW_BOOST = 8,                    -- Velocity multiplier when throwing objects
    
    -- Weld system settings
    WELD_DETECTION_RADIUS = 3.0,        -- Radius to search for weld targets
    WELD_HOVER_UPDATE_THROTTLE = 0.1,   -- Throttle hover updates (seconds)
    
    -- Object filtering - parts with these names are problematic for welding
    SUSPICIOUS_NAMES = {
        "HumanoidRootPart",
        "Head", 
        "Torso",
        "Left Arm", "Right Arm",
        "Left Leg", "Right Leg",
        "LeftUpperArm", "RightUpperArm",
        "LeftLowerArm", "RightLowerArm", 
        "LeftUpperLeg", "RightUpperLeg",
        "LeftLowerLeg", "RightLowerLeg",
        "LeftHand", "RightHand",
        "LeftFoot", "RightFoot",
        "UpperTorso", "LowerTorso"
    },
    
    -- Collision groups
    ITEM_COLLISION_GROUP = "Item",
    PLAYER_COLLISION_GROUP = "player",
    
    -- Visual feedback
    HOVER_HIGHLIGHT_COLOR = Color3.fromRGB(0, 162, 255),
    WELD_HIGHLIGHT_COLOR = Color3.fromRGB(0, 255, 0),
    
    -- Performance settings
    MAX_CONCURRENT_DRAGS = 10,          -- Maximum objects that can be dragged simultaneously
    RAYCAST_FILTER_DESCENDANTS = true,  -- Filter player character from raycasts
}

return DragDropConfig
