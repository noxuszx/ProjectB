-- src/client/ui/renderers/ArenaRenderer.lua
-- Applies Arena UI state to instances without running loops

local TweenService = game:GetService("TweenService")

local ArenaRenderer = {}

local function formatTime(seconds: number)
	local s = math.max(0, math.floor(seconds + 0.5))
	local m = math.floor(s / 60)
	local sec = s % 60
	return string.format("%d:%02d", m, sec)
end

function ArenaRenderer.render(refs, state, now)
	if not refs or not refs.Gui then return end
	local gui = refs.Gui
	local mainText = refs.MainText
	local timerText = refs.TimerText

	if state.active then
		gui.Enabled = true
		if mainText then
			mainText.Text = "AN ANCIENT EVIL HAS AWAKENED"
			mainText.TextTransparency = 0
		end
		if timerText then
			local endTime = tonumber(state.endTime or 0) or 0
			local remaining = math.max(0, endTime - (now or os.clock()))
			timerText.Text = "SURVIVE FOR " .. formatTime(remaining)
		end
	else
		gui.Enabled = false
	end
end

return ArenaRenderer

