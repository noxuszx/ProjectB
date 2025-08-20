local PhysicsService = game:GetService("PhysicsService")

-- Clients also need to know about the collision groups if they set CollisionGroup locally
-- (which InteractableHandler does during pickup/drag). If the group isn't registered on the
-- client, setting the CollisionGroup property can fall back to Default in local simulation,
-- causing the player to still collide with MeshParts while dragging.

-- Safe to call repeatedly; pcall prevents errors if already registered.
pcall(function() PhysicsService:RegisterCollisionGroup("Item") end)
pcall(function() PhysicsService:RegisterCollisionGroup("player") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Creature") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Admins") end)

-- Mirror the server's collision matrix so client-side prediction matches server behavior.
pcall(function()
    PhysicsService:CollisionGroupSetCollidable("Item", "player", false)
    PhysicsService:CollisionGroupSetCollidable("Creature", "player", true)
    PhysicsService:CollisionGroupSetCollidable("Creature", "Item", true)
    PhysicsService:CollisionGroupSetCollidable("Item", "Admins", false)
end)
