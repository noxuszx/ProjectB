local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.config.SoundConfig)

local last = {}
local DEDUPE_WINDOW = 0.25

local M = {}

function M.preloadAll()
    local ids = {}
    for _, id in pairs(SoundConfig.sounds) do
        if id and id ~= "" then table.insert(ids, id) end
    end
    if #ids > 0 then
        pcall(function()
            ContentProvider:PreloadAsync(ids)
        end)
    end
end

function M.play(key, opts)
    local now = os.clock()
    if last[key] and (now - last[key]) < DEDUPE_WINDOW then return end
    last[key] = now

    local id = SoundConfig.sounds[key]
    if not id or id == "" then return end

    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = (opts and opts.volume) or SoundConfig.volume or 0.5
    s.Parent = SoundService
    s:Play()
    s.Ended:Connect(function()
        s:Destroy()
    end)
end

-- Play at a specific instance (e.g., sell zone part or character root)
function M.playAt(key, parent, opts)
    if not parent then return end
    local id = SoundConfig.sounds[key]
    if not id or id == "" then return end

    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = (opts and opts.volume) or SoundConfig.volume or 0.5
    -- Optional 3D settings (can be tuned per-use via opts)
    if opts and opts.rolloff then
        s.RollOffMaxDistance = opts.rolloff.max or 60
        s.RollOffMinDistance = opts.rolloff.min or 10
        s.EmitterSize = opts.rolloff.emitter or 5
        s.RollOffMode = Enum.RollOffMode.Inverse
    end
    s.Parent = parent
    s:Play()
    s.Ended:Connect(function()
        s:Destroy()
    end)
end

return M

