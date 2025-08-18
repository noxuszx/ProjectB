-- src/client/ui/core/Store.lua
-- Minimal observable store for UI state

local Store = {}
Store.__index = Store

local function shallowDump(tbl)
	local parts = {}
	for k, v in pairs(tbl or {}) do
		local vv
		if type(v) == "table" then
			local sub = {}
			for kk, vv2 in pairs(v) do table.insert(sub, tostring(kk)..":"..tostring(vv2)) end
			vv = "{"..table.concat(sub, ",").."}"
		else
			vv = tostring(v)
		end
		table.insert(parts, tostring(k).."="..vv)
	end
	return "{"..table.concat(parts, ", ").."}"
end

export type State = {
	arena: { active: boolean, endTime: number? }?,
	victory: { visible: boolean, message: string? }?,
	death: { visible: boolean, message: string? }?,
	now: number?,
}

function Store.new(initial: State?)
	local self = setmetatable({}, Store)
	self.state = initial or {
		arena = { active = false, endTime = 0 },
		victory = { visible = false, message = "" },
		death = { visible = false, message = "" },
		now = os.clock(),
	}
	self._subs = {}
	self._nextId = 1
	self._lastLogKey = string.format("a:%s e:%s v:%s d:%s",
		tostring(self.state.arena and self.state.arena.active),
		tostring(self.state.arena and self.state.arena.endTime),
		tostring(self.state.victory and self.state.victory.visible),
		tostring(self.state.death and self.state.death.visible)
	)
	return self
end

local function shallowMerge(a, b)
	local r = {}
	for k, v in pairs(a or {}) do r[k] = v end
	for k, v in pairs(b or {}) do
		if type(v) == "table" and type(r[k]) == "table" then
			-- shallow merge for first-level tables
			local t = {}
			for kk, vv in pairs(r[k]) do t[kk] = vv end
			for kk, vv in pairs(v) do t[kk] = vv end
			r[k] = t
		else
			r[k] = v
		end
	end
	return r
end

function Store:set(partial: State)
	self.state = shallowMerge(self.state, partial)
	-- Only log when key visibility/timer configs actually changed
	local key = string.format("a:%s e:%s v:%s d:%s",
		tostring(self.state.arena and self.state.arena.active),
		tostring(self.state.arena and self.state.arena.endTime),
		tostring(self.state.victory and self.state.victory.visible),
		tostring(self.state.death and self.state.death.visible)
	)
	if key ~= self._lastLogKey then
		self._lastLogKey = key
		print("[Store]", key)
	end
	for _, fn in pairs(self._subs) do
		fn(self.state)
	end
end

function Store:subscribe(fn: (State) -> ())
	local id = tostring(self._nextId)
	self._nextId += 1
	self._subs[id] = fn
	-- immediately call with current state
	fn(self.state)
	return function()
		self._subs[id] = nil
	end
end

return Store

