-- src/client/ui/core/Maid.lua
-- Simple cleanup helper for connections and tasks

local Maid = {}
Maid.__index = Maid

function Maid.new()
	local self = setmetatable({}, Maid)
	self._tasks = {}
	return self
end

function Maid:give(task)
	table.insert(self._tasks, task)
	return task
end

function Maid:clean()
	for _, t in ipairs(self._tasks) do
		local ty = typeof(t)
		if ty == "RBXScriptConnection" then
			t:Disconnect()
		elseif type(t) == "function" then
			pcall(t)
		elseif typeof(t) == "Instance" then
			pcall(function() t:Destroy() end)
		end
	end
	self._tasks = {}
end

return Maid

