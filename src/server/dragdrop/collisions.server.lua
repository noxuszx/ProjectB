local PhysicsService = game:GetService("PhysicsService")

-- Ensure groups exist
pcall(function() PhysicsService:RegisterCollisionGroup("Item") end)
pcall(function() PhysicsService:RegisterCollisionGroup("player") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Creature") end)

-- Set collision rules
PhysicsService:CollisionGroupSetCollidable("Item", "player", false)
PhysicsService:CollisionGroupSetCollidable("Creature", "player", true) -- Creatures can collide with players
PhysicsService:CollisionGroupSetCollidable("Creature", "Item", true)   -- Creatures can collide with items

local Players = game.Players

local function setCharacterCollisionGroup(char: Model)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = "player"
		end
	end
	-- Keep it consistent for any future parts (e.g., accessories)
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "player"
		end
	end)
end

-- Apply for existing players (in case this script starts after some have joined)
for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then
		setCharacterCollisionGroup(p.Character)
	end
	p.CharacterAdded:Connect(setCharacterCollisionGroup)
end

Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(setCharacterCollisionGroup)
end)
