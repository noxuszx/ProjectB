
# Weapon Animation Fix

Here is the corrected `playWeaponAnimation` function for `src/shared/weapons/weaponController.lua`.

This version replaces the deprecated `humanoid:LoadAnimation()` with the correct `animator:LoadAnimation()` method, which resolves the issue of animations not playing.

```lua
local function playWeaponAnimation()
	local player = Players.LocalPlayer
	if not player or not player.Character then return end

	local humanoid = player.Character:FindFirstChild("Humanoid")
	if not humanoid then return end

    -- Get the Animator from the Humanoid
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        warn("[WeaponController] Animator not found in Humanoid!")
        return
    end

	if animationTrack then
		animationTrack:Stop()
		animationTrack = nil
	end

	if currentWeaponConfig and currentWeaponConfig.Animation and currentWeaponConfig.Animation ~= "" then
		-- Create a temporary Animation instance
        local animation = Instance.new("Animation")
		animation.AnimationId = currentWeaponConfig.Animation

		-- Load the animation onto the Animator
		animationTrack = animator:LoadAnimation(animation)
        animationTrack:Play()
        debugPrint("Playing animation: " .. currentWeaponConfig.Animation)
        
        -- The animation instance can be destroyed after loading
        animation:Destroy()
	else
		debugPrint("No animation configured for weapon: " .. (currentWeapon and currentWeapon.Name or "unknown"))
	end
end
```
