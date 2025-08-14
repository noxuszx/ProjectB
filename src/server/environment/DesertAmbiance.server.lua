local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local DesertAmbiance = {}

-- Configuration
local AMBIANCE_CONFIG = {
    -- Time ranges for random sound playback (in seconds)
    MIN_WAIT_TIME = 5,
    MAX_WAIT_TIME = 20,
    
    -- Sound names in SoundService
    SOUNDS = {
        SAND_SLIDE = "sand-slide",
        ANCIENT_MUSIC = "ancient-music",
        SMALL_ROCKS = {"small-rocks1", "small-rocks2", "small-rocks3"}
    },
    
    -- Chance for multiple sounds to play simultaneously (0-1)
    OVERLAP_CHANCE = 0.4,
    MAX_SIMULTANEOUS = 3
}

-- Track active sounds and timers
local activeSounds = {}
local soundTimers = {}

-- Initialize the ambiance system
function DesertAmbiance:init()
    print("Desert Ambiance System: Initializing...")
    
    -- Start the random sound scheduler
    self:startRandomScheduler()
    
    print("Desert Ambiance System: Active")
end

-- Start the random sound scheduling system
function DesertAmbiance:startRandomScheduler()
    spawn(function()
        while true do
            -- Wait random time between sound events
            local waitTime = math.random(AMBIANCE_CONFIG.MIN_WAIT_TIME, AMBIANCE_CONFIG.MAX_WAIT_TIME)
            wait(waitTime)
            
            -- Determine how many sounds to play
            local numSounds = 1
            if math.random() < AMBIANCE_CONFIG.OVERLAP_CHANCE then
                numSounds = math.random(2, AMBIANCE_CONFIG.MAX_SIMULTANEOUS)
            end
            
            -- Play random sounds
            self:playRandomSounds(numSounds)
        end
    end)
end

-- Play a specified number of random sounds
function DesertAmbiance:playRandomSounds(count)
    local availableSounds = self:getAllSoundNames()
    local soundsToPlay = {}
    
    -- Select random sounds (avoid duplicates)
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
    
    -- Add sand slide sound
    table.insert(sounds, AMBIANCE_CONFIG.SOUNDS.SAND_SLIDE)
    
    -- Add ancient music sound
    table.insert(sounds, AMBIANCE_CONFIG.SOUNDS.ANCIENT_MUSIC)
    
    -- Add all small rocks sounds
    for _, rockSound in ipairs(AMBIANCE_CONFIG.SOUNDS.SMALL_ROCKS) do
        table.insert(sounds, rockSound)
    end
    
    return sounds
end

-- Play a specific sound by name
function DesertAmbiance:playSound(soundName)
    local sound = SoundService:FindFirstChild(soundName)
    
    if sound and sound:IsA("Sound") then
        -- Don't play if already playing
        if not sound.IsPlaying then
            sound:Play()
            
            -- Track the sound
            activeSounds[soundName] = sound
            
            -- Clean up when sound ends
            spawn(function()
                sound.Ended:Wait()
                activeSounds[soundName] = nil
            end)
        end
    else
        warn("Desert Ambiance: Sound '" .. soundName .. "' not found in SoundService")
    end
end

-- Get currently playing sounds
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

-- Stop all ambient sounds (useful for debugging or cleanup)
function DesertAmbiance:stopAllSounds()
    for _, sound in pairs(activeSounds) do
        if sound.IsPlaying then
            sound:Stop()
        end
    end
    activeSounds = {}
    print("Desert Ambiance: All sounds stopped")
end

-- Initialize the system
DesertAmbiance:init()

-- Optional: Expose for debugging
_G.DesertAmbiance = DesertAmbiance

return DesertAmbiance