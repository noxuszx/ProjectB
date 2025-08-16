-- src/client/tutorial/HighlightManager.lua
-- Lightweight highlight utilities for tutorial targets

local HighlightManager = {}

-- Create a Highlight adorning the target (BasePart or Model)
function HighlightManager.attachHighlight(target, options)
    if not target then return nil end
    -- Reuse existing if present
    local existing = target:FindFirstChild("TutorialHighlight")
    if existing and existing:IsA("Highlight") then
        existing.Enabled = true
        return existing
    end

    local adornTarget = target
    if target:IsA("Model") then
        adornTarget = target.PrimaryPart or target:FindFirstChildOfClass("BasePart") or target
    end

    local h = Instance.new("Highlight")
    h.Name = "TutorialHighlight"
    h.Adornee = target -- let Highlight handle models; Roblox supports Model Adornee
    h.Enabled = true
    -- Visible fill and outline to highlight the entire object
    h.FillTransparency = (options and options.FillTransparency) or 0.4
    h.OutlineTransparency = (options and options.OutlineTransparency) or 0.1
    h.FillColor = (options and options.FillColor) or Color3.fromRGB(255, 230, 120) -- warm gold fill
    h.OutlineColor = (options and options.OutlineColor) or Color3.fromRGB(255, 200, 0) -- bright outline
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = target

    return h
end

function HighlightManager.detachHighlight(target)
    if not target then return end
    local h = target:FindFirstChild("TutorialHighlight")
    if h and h:IsA("Highlight") then
        h:Destroy()
    end
end

return HighlightManager

