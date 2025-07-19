print("Hello world, from client!")

local DragDropClient = require(script.dragdrop.DragDropClient)

-- Wait for game to load
task.wait(2)

DragDropClient.init()

print("Client systems initialized!")
