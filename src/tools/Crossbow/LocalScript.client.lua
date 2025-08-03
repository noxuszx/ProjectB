local tool = script.Parent
local event = tool:WaitForChild('MinigunEvent')
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local db = false
Waiting = 2.4
local mouseDown = false
local equipped = false

tool.Parent.Equipped:connect(function(mouse)	--I made an equipped variable so that the gun will stop firing when it's unequipped.
	equipped = true
end)

tool.Parent.Unequipped:Connect(function()
	equipped = false
end)

mouse.Button1Down:connect(function()
	mouseDown = true
	while mouseDown and not db and equipped do	--you can use "and" and "or" for while loops as well! This is another change.
		db = true
		event:FireServer(mouse.Hit.p)	--Instead of using "MPosition", you can just write "mouse.Hit.p" inside of the event as one of the arguments.
		wait(Waiting)
		db = false
	end
end)

mouse.Button1Up:Connect(function()
	mouseDown = false
end)