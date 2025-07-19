--[[
    DragDropConfig.lua
    Configuration for drag and drop physics system
]]--

local DragDropConfig = {}


DragDropConfig.MAX_DRAG_DISTANCE = 10 		-- Increased range for easier dragging
DragDropConfig.DRAG_HEIGHT_OFFSET = 2 		-- How high above ground to drag objects
DragDropConfig.DRAG_SMOOTHNESS = 0.1 		-- Lower value for more responsive movement

DragDropConfig.UPDATE_RATE = 0.05 			-- Faster updates for smoother dragging (20fps)
DragDropConfig.NETWORK_UPDATE_RATE = 0.1 	-- How often to send position to server (seconds)
DragDropConfig.MAX_CONCURRENT_DRAGS = 5 	-- Max objects one player can drag simultaneously

DragDropConfig.DRAGGABLE_CATEGORIES = {
    ["DraggableItems"] = true,              -- Future folder for draggable items
    ["Workspace"] = true,                   -- For testing with regular parts
}

DragDropConfig.EXCLUDED_CATEGORIES = {
    ["SpawnedVegetation"] = true,
    ["SpawnedRocks"] = true,
    ["SpawnedStructures"] = true,
    ["Chunks"] = true
}

DragDropConfig.MIN_DRAG_MASS = 0.1 			-- Minimum part mass to be draggable
DragDropConfig.MAX_DRAG_MASS = 500 			-- Maximum part mass to be draggable
DragDropConfig.SNAP_TO_TERRAIN = true 		-- Whether to snap objects to terrain when dropped

DragDropConfig.HIGHLIGHT_COLOR = Color3.fromRGB(0, 255, 255)
DragDropConfig.HIGHLIGHT_TRANSPARENCY = 0.7

DragDropConfig.REQUIRE_PERMISSIONS = false 	-- Whether to check permissions before dragging
DragDropConfig.ADMIN_ONLY = false 			-- Whether only admins can drag objects

return DragDropConfig






