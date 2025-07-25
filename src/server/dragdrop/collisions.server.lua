local PhysicsService = game:GetService("PhysicsService")

PhysicsService:RegisterCollisionGroup("Item")
PhysicsService:RegisterCollisionGroup("player")
PhysicsService:RegisterCollisionGroup("Creature")

-- Set collision rules
PhysicsService:CollisionGroupSetCollidable("Item", "player", false)
PhysicsService:CollisionGroupSetCollidable("Creature", "player", true) -- Creatures can collide with players
PhysicsService:CollisionGroupSetCollidable("Creature", "Item", true)   -- Creatures can collide with items

local Players = game.Players

Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function(c)
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("MeshPart") or d:IsA("Part") then
				d.CollisionGroup = "player"
			end
		end
	end)
end)