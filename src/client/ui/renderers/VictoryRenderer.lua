-- src/client/ui/renderers/VictoryRenderer.lua
-- Applies Victory UI state and simple fade-in without loops

local TweenService = game:GetService("TweenService")

local VictoryRenderer = {}

function VictoryRenderer.render(refs, state, now)
	if not refs or not refs.Gui then return end
	local gui = refs.Gui
	local textLabel = refs.TextLabel
	local textTimer = refs.TextTimer
	local frame = refs.VictoryFrame
	local lobbyBtn = refs.LobbyBTN
	local continueBtn = refs.ContinueBTN

if state.visible then
		if not gui.Enabled then print("[VictoryRenderer] Enabling Victory UI") end
		gui.Enabled = true
		gui.DisplayOrder = 100
		if textLabel then textLabel.Text = state.message or "VICTORY!" end
		-- Initial visibility
		if textLabel then textLabel.TextTransparency = 0 end
		if textTimer then textTimer.TextTransparency = 0 end
		if frame then frame.BackgroundTransparency = 1 end -- keep frame invisible per user preference
		if lobbyBtn then lobbyBtn.BackgroundTransparency = 0; lobbyBtn.TextTransparency = 0 end
		if continueBtn then continueBtn.BackgroundTransparency = 0; continueBtn.TextTransparency = 0 end
		-- Derive countdown from a fixed 30s window starting when visible first became true
		-- We can store a start time on first activation by caching in refs
		refs._activatedAt = refs._activatedAt or (now or os.clock())
		local elapsed = (now or os.clock()) - (refs._activatedAt or 0)
		local remaining = math.max(0, 30 - math.floor(elapsed))
		if textTimer then
			textTimer.Text = string.format("GOING BACK TO LOBBY IN %ds", remaining)
		end
		-- Auto-hide will be triggered by controller when time elapses (optional)
else
		if gui.Enabled then print("[VictoryRenderer] Disabling Victory UI") end
		gui.Enabled = false
		refs._activatedAt = nil
	end
end

return VictoryRenderer

