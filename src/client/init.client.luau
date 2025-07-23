print("Hello world, from client!")

-- Use the enhanced professional drag-drop system
local DragDropClientInit = require(script.dragdrop.DragDropClientInit)

-- Wait for game to load
task.wait(2)

-- Initialize the enhanced drag-drop system
local success = DragDropClientInit.integrateWithExistingClient()

if success then
    print("Client systems initialized with Enhanced Professional Drag-Drop System!")
else
    warn("Failed to initialize enhanced drag-drop system - falling back to legacy system")

    -- Fallback to legacy system if available
    local legacySuccess, DragDropClient = pcall(require, script.dragdrop.DragDropClient)
    if legacySuccess then
        DragDropClient.init()
        print("Client systems initialized with Legacy Drag-Drop System!")
    else
        warn("No drag-drop system available!")
    end
end
