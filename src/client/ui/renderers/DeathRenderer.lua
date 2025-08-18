-- src/client/ui/renderers/DeathRenderer.lua
-- Applies Death UI state, shows message, and derives countdown from now

local DeathRenderer = {}

function DeathRenderer.render(refs, state, now)
	if not refs or not refs.Gui then return end
	local gui = refs.Gui
	local title = refs.TextLabel or (refs.Gui and refs.Gui:FindFirstChild("TextLabel"))
	local timer = refs.TextTimer or (refs.Gui and refs.Gui:FindFirstChild("TextTimer"))
	local frame = refs.DeathFrame or (refs.Gui and refs.Gui:FindFirstChild("DeathFrame"))

if state.visible then
		if not gui.Enabled then print("[DeathRenderer] Enabling Death UI") end
		gui.Enabled = true
		gui.DisplayOrder = 100
		if title then title.Text = state.message or "YOU DIED" end
		-- Handle countdown if a timeout was provided
		if state.timeoutSeconds and state.timeoutSeconds > 0 then
			local activatedAt = refs._activatedAt or (now or os.clock())
			refs._activatedAt = activatedAt
			local elapsed = (now or os.clock()) - activatedAt
			local remaining = math.max(0, math.floor(state.timeoutSeconds - elapsed))
			if timer then timer.Text = string.format("Returning to lobby in: %ds", remaining) end
		else
			if timer then timer.Text = "Other players are still alive" end
		end
else
		if gui.Enabled then print("[DeathRenderer] Disabling Death UI") end
		gui.Enabled = false
		refs._activatedAt = nil
	end
end

return DeathRenderer

