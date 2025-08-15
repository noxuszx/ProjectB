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
    MAX_SIMULTANEOUS = 3,
    
    -- Volume settings (0.0 to 1.0)
    VOLUME = {
        SAND_SLIDE = 0.2,
        ANCIENT_MUSIC = 0.1,
        SMALL_ROCKS = 0.1,
        DEFAULT = 0.1
    }
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
            -- Set volume based on config
            local volume = self:getVolumeForSound(soundName)
            sound.Volume = volume
            
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

function DesertAmbiance:getVolumeForSound(soundName)
    -- Check specific sound volumes
    if soundName == AMBIANCE_CONFIG.SOUNDS.SAND_SLIDE then
        return AMBIANCE_CONFIG.VOLUME.SAND_SLIDE
    elseif soundName == AMBIANCE_CONFIG.SOUNDS.ANCIENT_MUSIC then
        return AMBIANCE_CONFIG.VOLUME.ANCIENT_MUSIC
    else
        -- Check if it's a small rocks sound
        for _, rockSound in ipairs(AMBIANCE_CONFIG.SOUNDS.SMALL_ROCKS) do
            if soundName == rockSound then
                return AMBIANCE_CONFIG.VOLUME.SMALL_ROCKS
            end
        end
    end
    
    -- Default volume
    return AMBIANCE_CONFIG.VOLUME.DEFAULT
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