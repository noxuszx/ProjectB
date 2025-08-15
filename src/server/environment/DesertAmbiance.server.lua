local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local DesertAmbiance = {}

-- Configuration
local AMBIANCE_CONFIG = {

    MIN_WAIT_TIME = 5,
    MAX_WAIT_TIME = 20,
    SOUNDS = {
        SAND_SLIDE = "sand-slide",
        ANCIENT_MUSIC = "ancient-music",
        SMALL_ROCKS = {"small-rocks1", "small-rocks2", "small-rocks3"}
    },
    
    OVERLAP_CHANCE = 0.4,
    MAX_SIMULTANEOUS = 3
}

local activeSounds = {}
local soundTimers = {}

function DesertAmbiance:init()
    self:startRandomScheduler()
end

function DesertAmbiance:startRandomScheduler()
    task.spawn(function()
        while true do
            local waitTime = math.random(AMBIANCE_CONFIG.MIN_WAIT_TIME, AMBIANCE_CONFIG.MAX_WAIT_TIME)
            task.wait(waitTime)
            local numSounds = 1
            if math.random() < AMBIANCE_CONFIG.OVERLAP_CHANCE then
                numSounds = math.random(2, AMBIANCE_CONFIG.MAX_SIMULTANEOUS)
            end
            
            self:playRandomSounds(numSounds)
        end
    end)
end

function DesertAmbiance:playRandomSounds(count)
    local availableSounds = self:getAllSoundNames()
    local soundsToPlay = {}
    
    for i = 1, math.min(count, #availableSounds) do
        local randomIndex = math.random(#availableSounds)
        table.insert(soundsToPlay, availableSounds[randomIndex])
        table.remove(availableSounds, randomIndex)
    end
    
    -- Play selected sounds
    for _, soundName in ipairs(soundsToPlay) do
        self:playSound(soundName)
    end
    
end

-- Get all available sound names
function DesertAmbiance:getAllSoundNames()
    local sounds = {}
    
    table.insert(sounds, AMBIANCE_CONFIG.SOUNDS.SAND_SLIDE)
    table.insert(sounds, AMBIANCE_CONFIG.SOUNDS.ANCIENT_MUSIC)
    for _, rockSound in ipairs(AMBIANCE_CONFIG.SOUNDS.SMALL_ROCKS) do
        table.insert(sounds, rockSound)
    end
    
    return sounds
end

function DesertAmbiance:playSound(soundName)
    local sound = SoundService:FindFirstChild(soundName)
    
    if sound and sound:IsA("Sound") then
        if not sound.IsPlaying then
            sound:Play()
            
            activeSounds[soundName] = sound
            
            task.spawn(function()
                sound.Ended:Wait()
                activeSounds[soundName] = nil
            end)
        end
    else
        warn("Desert Ambiance: Sound '" .. soundName .. "' not found in SoundService")
    end
end

function DesertAmbiance:getActiveSounds()
    local active = {}
    for soundName, sound in pairs(activeSounds) do
        if sound.IsPlaying then
            table.insert(active, soundName)
        else
            activeSounds[soundName] = nil
        end
    end
    return active
end

function DesertAmbiance:stopAllSounds()
    for _, sound in pairs(activeSounds) do
        if sound.IsPlaying then
            sound:Stop()
        end
    end
    activeSounds = {}
    print("Desert Ambiance: All sounds stopped")
end

DesertAmbiance:init()
_G.DesertAmbiance = DesertAmbiance

return DesertAmbiance