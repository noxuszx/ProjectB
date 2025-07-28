-- src/shared/modules/CreatureAnimationManager.lua
-- Manages R6 animations for AI creatures using default Roblox animations

local CreatureAnimationManager = {}
CreatureAnimationManager.__index = CreatureAnimationManager

-- Default Roblox R6 Animation IDs
local ANIMATION_IDS = {
    Idle = "rbxassetid://180435571",
    Walk = "rbxassetid://180426354",
    Run = "rbxassetid://180426354" -- Using walk for run, can be changed
}

function CreatureAnimationManager.new(character)
    local self = setmetatable({}, CreatureAnimationManager)
    
    self.character = character
    self.humanoid = character:WaitForChild("Humanoid")
    self.animator = self.humanoid:WaitForChild("Animator", 5) -- Wait up to 5 seconds
    
    -- If no Animator exists, create one
    if not self.animator then
        self.animator = Instance.new("Animator")
        self.animator.Parent = self.humanoid
        -- Debug: Created Animator (removed spam)
    end
    
    -- Animation tracks
    self.animations = {}
    self.currentAnimation = nil
    
    -- Load animations
    self:loadAnimations()
    
    -- Debug: Initialized R6 animations (removed spam)
    
    return self
end

function CreatureAnimationManager:loadAnimations()
    for animName, animId in pairs(ANIMATION_IDS) do
        local animation = Instance.new("Animation")
        animation.AnimationId = animId
        animation.Name = animName
        
        local success, animationTrack = pcall(function()
            return self.animator:LoadAnimation(animation)
        end)
        
        if success and animationTrack then
            self.animations[animName:lower()] = animationTrack
            -- Debug: Loaded animation (removed spam)
        else
            warn("[AnimationManager] Failed to load", animName, "animation for", self.character.Name)
        end
    end
end

function CreatureAnimationManager:playAnimation(animationName, fadeTime, speed)
    fadeTime = fadeTime or 0.2
    speed = speed or 1
    
    local animationTrack = self.animations[animationName:lower()]
    if not animationTrack then
        warn("[AnimationManager] Animation not found:", animationName, "for", self.character.Name)
        return
    end
    
    -- Stop current animation if different
    if self.currentAnimation and self.currentAnimation ~= animationTrack then
        self.currentAnimation:Stop(fadeTime)
    end
    
    -- Play new animation
    if not animationTrack.IsPlaying then
        animationTrack:Play(fadeTime, 1, speed)
        self.currentAnimation = animationTrack
        -- Debug: Playing animation (removed spam)
    end
end

function CreatureAnimationManager:stopAnimation(animationName, fadeTime)
    fadeTime = fadeTime or 0.2
    
    local animationTrack = self.animations[animationName:lower()]
    if animationTrack and animationTrack.IsPlaying then
        animationTrack:Stop(fadeTime)
        if self.currentAnimation == animationTrack then
            self.currentAnimation = nil
        end
    end
end

function CreatureAnimationManager:stopAllAnimations(fadeTime)
    fadeTime = fadeTime or 0.2
    
    for _, animationTrack in pairs(self.animations) do
        if animationTrack.IsPlaying then
            animationTrack:Stop(fadeTime)
        end
    end
    
    self.currentAnimation = nil
end

function CreatureAnimationManager:setIdleAnimation()
    self:playAnimation("idle")
end

function CreatureAnimationManager:setWalkAnimation()
    self:playAnimation("walk")
end

function CreatureAnimationManager:isAnimationPlaying(animationName)
    local animationTrack = self.animations[animationName:lower()]
    return animationTrack and animationTrack.IsPlaying
end

function CreatureAnimationManager:cleanup()
    self:stopAllAnimations(0)
    
    for _, animationTrack in pairs(self.animations) do
        animationTrack:Destroy()
    end
    
    self.animations = {}
    self.currentAnimation = nil
end

return CreatureAnimationManager