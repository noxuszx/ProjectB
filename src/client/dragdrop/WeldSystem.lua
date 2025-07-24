--[[
    WeldSystem.lua
    Handles welding/unwelding mechanics for drag and drop system
]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragDropConfig = require(ReplicatedStorage.Shared.config.DragDropConfig)
local CollectionServiceTags = require(ReplicatedStorage.Shared.utilities.CollectionServiceTags)

local WeldSystem = {}
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Weld state
local hoveredObject = nil
local hoverHighlight = nil
local lastTarget = nil
local lastUpdateTime = 0
local UPDATE_THROTTLE = 0.1

local function isPlayerCharacterPart(part)
    local model = part:FindFirstAncestorOfClass("Model")
    if model then
        return Players:GetPlayerFromCharacter(model) ~= nil
    end
    return false
end

local function problemWeld(part)
    if part.Anchored and part.Size.Magnitude > 100 then
        print("DEBUG: Skipping extremely large anchored part:", part.Name, "Size:", part.Size.Magnitude)
        return true
    end

    if part.Transparency >= 1 then
        print("DEBUG: Skipping invisible part:", part.Name, "Transparency:", part.Transparency)
        return true
    end

    for _, suspiciousName in pairs(DragDropConfig.SUSPICIOUS_NAMES) do
        if part.Name:find(suspiciousName) then
            if part.Parent and part.Parent.Name == "Chunks" then
                print("DEBUG: Allowing chunk part as weld target:", part.Name)
            else
                print("DEBUG: Skipping suspicious part:", part.Name)
                return true
            end
        end
    end

    return false
end

local function isWeldableTarget(part)
    return part:IsA("BasePart")
        and part.CanCollide
        and not problemWeld(part)
        and not isPlayerCharacterPart(part)
        and CollectionServiceTags.isWeldable(part)
end

local function createHoverHighlight(object)
    local highlight = Instance.new("SelectionBox")
    highlight.Adornee = object
    highlight.Color3 = Color3.fromRGB(255, 255, 0)
    highlight.Transparency = 0.5
    highlight.LineThickness = 0.15
    highlight.Parent = object
    return highlight
end

local function removeHoverHighlight()
    if hoverHighlight then
        hoverHighlight:Destroy()
        hoverHighlight = nil
    end
end

function WeldSystem.updateHoveredObject(isDragging, isDraggableObjectFunc)
    local currentTime = tick()
    local target = mouse.Target
    
    if target == lastTarget and (currentTime - lastUpdateTime) < UPDATE_THROTTLE then
        return
    end
    
    lastTarget = target
    lastUpdateTime = currentTime
    
    if not isDragging and target and target ~= hoveredObject then
        if isDraggableObjectFunc(target) then
            removeHoverHighlight()
            hoveredObject = target
            hoverHighlight = createHoverHighlight(target)
        end
    elseif not target or isDragging or (target and not isDraggableObjectFunc(target)) then
        if hoveredObject then
            removeHoverHighlight()
            hoveredObject = nil
        end
    end
end

local function findWeldTargets(sourceObject, maxDistance)
    local targets = {}
    local sourcePos = sourceObject.Position
    local sourceSize = sourceObject.Size
    maxDistance = maxDistance or 2.0 

    -- Use a smaller search area to be more precise
    local searchSize = sourceSize + Vector3.new(maxDistance * 1.2, maxDistance * 1.2, maxDistance * 1.2)
    local touchingParts = workspace:GetPartBoundsInBox(sourceObject.CFrame, searchSize)
    for _, part in pairs(touchingParts) do
        if part ~= sourceObject and isWeldableTarget(part) then
            -- Calculate actual surface-to-surface distance more accurately
            local centerDistance = (part.Position - sourcePos).Magnitude
            local sourceRadius = sourceSize.Magnitude / 2
            local targetRadius = part.Size.Magnitude / 2
            local surfaceDistance = math.max(0, centerDistance - sourceRadius - targetRadius)

            -- Only include if actually close enough (stricter check)
            if surfaceDistance <= maxDistance * 0.8 then -- More restrictive multiplier
                table.insert(targets, {part = part, distance = surfaceDistance, method = "proximity"})
                print("DEBUG: Found nearby part:", part.Name, "surface distance:", math.floor(surfaceDistance * 100) / 100)
            end
        end
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local filterList = {sourceObject}
    if Players.LocalPlayer.Character then
        table.insert(filterList, Players.LocalPlayer.Character)
    end

    for _, part in pairs(workspace:GetPartBoundsInBox(sourceObject.CFrame, sourceObject.Size * 5)) do
        if part ~= sourceObject and not part.CanCollide then
            table.insert(filterList, part)
        end
    end

    raycastParams.FilterDescendantsInstances = filterList

    -- More comprehensive directional scanning
    local directions = {
        Vector3.new(0, -1, 0),   -- Down
        Vector3.new(0, 1, 0),    -- Up
        Vector3.new(1, 0, 0),    -- Right
        Vector3.new(-1, 0, 0),   -- Left
        Vector3.new(0, 0, 1),    -- Forward
        Vector3.new(0, 0, -1),   -- Back
        -- Diagonal directions for better coverage
        Vector3.new(1, 1, 0).Unit,
        Vector3.new(-1, 1, 0).Unit,
        Vector3.new(1, -1, 0).Unit,
        Vector3.new(-1, -1, 0).Unit,
    }

    for _, direction in pairs(directions) do
        -- Cast rays from the surface of the part, not the center
        local rayOrigin = sourcePos + direction * (sourceSize.Magnitude / 2)
        local rayDistance = maxDistance * 2  -- More generous raycast distance
        local raycastResult = workspace:Raycast(rayOrigin, direction * rayDistance, raycastParams)

        if raycastResult then
            local hitPart = raycastResult.Instance
            local distance = raycastResult.Distance

            if isWeldableTarget(hitPart) and distance <= maxDistance then
                local alreadyFound = false
                for _, existing in pairs(targets) do
                    if existing.part == hitPart then
                        alreadyFound = true
                        break
                    end
                end

                if not alreadyFound then
                    table.insert(targets, {part = hitPart, distance = distance, method = "raycast"})
                    print("DEBUG: Raycast found:", hitPart.Name, "Parent:", hitPart.Parent and hitPart.Parent.Name or "nil",
                          "Material:", hitPart.Material.Name, "Anchored:", hitPart.Anchored,
                          "Transparency:", hitPart.Transparency, "CanCollide:", hitPart.CanCollide,
                          "direction:", tostring(direction), "distance:", math.floor(distance * 100) / 100)
                end
            end
        else
            -- Debug: Show when raycast finds nothing
            print("DEBUG: Raycast in direction", tostring(direction), "found nothing")
        end
    end

    -- Method 3: GetTouchingParts as fallback (for parts that are actually touching)
    local actuallyTouching = sourceObject:GetTouchingParts()
    for _, part in pairs(actuallyTouching) do
        if isWeldableTarget(part) then
            local alreadyFound = false
            for _, existing in pairs(targets) do
                if existing.part == part then
                    alreadyFound = true
                    break
                end
            end

            if not alreadyFound then
                table.insert(targets, {part = part, distance = 0, method = "touching"})
                print("DEBUG: Actually touching:", part.Name)
            end
        end
    end

    -- Sort by distance (closest first)
    table.sort(targets, function(a, b) return a.distance < b.distance end)

    print("DEBUG: Total targets found:", #targets)
    return targets
end

function WeldSystem.weldObject(draggedObject, currentWeld)
    local targetObject = hoveredObject or draggedObject
    if not targetObject then
        print("No object to weld - hover over a part or drag one")
        return nil, false
    end

    local weldTargets = findWeldTargets(targetObject, 3.0)

    if #weldTargets == 0 then
        print("No weldable objects found nearby - move closer to another object")
        return currentWeld, (currentWeld ~= nil)
    end

    local existingWelds = {}
    for _, child in pairs(targetObject:GetChildren()) do
        if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
            table.insert(existingWelds, child)
        end
    end

    if #existingWelds > 0 then
        for _, weld in pairs(existingWelds) do
            local weldedPart = weld.Part0 == targetObject and weld.Part1 or weld.Part0
            for _, target in pairs(weldTargets) do
                if target.part == weldedPart then
                    weld:Destroy()
                    print("Unwelded", targetObject.Name, "from", weldedPart.Name)
                    return currentWeld, (currentWeld ~= nil)
                end
            end
        end
    end

    -- Create new weld to the closest target
    local bestTarget = weldTargets[1]
    local weldTarget = bestTarget.part

    local weldId = tick() .. "_" .. math.random(1000, 9999)
    local weldName = "DragDropWeld_" .. weldId

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = targetObject
    weld.Part1 = weldTarget
    weld.Parent = targetObject
    weld.Name = weldName

    print("Welded", targetObject.Name, "to", weldTarget.Name, "via", bestTarget.method, "detection")
    print("Distance:", math.floor(bestTarget.distance * 100) / 100, "studs")

    if targetObject == draggedObject then
        return weld, true
    else
        return currentWeld, (currentWeld ~= nil)
    end
end

function WeldSystem.getWeldedAssembly(part, isDraggableObjectFunc)
    local assembly = {part}
    local visited = {[part] = true}
    local toCheck = {part}

    while #toCheck > 0 do
        local currentPart = table.remove(toCheck, 1)

        -- Enhanced: Check for all DragDropWeld constraints (supports multiple welds per part)
        for _, child in pairs(currentPart:GetChildren()) do
            if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
                local otherPart = child.Part0 == currentPart and child.Part1 or child.Part0
                if otherPart and not visited[otherPart] and isDraggableObjectFunc(otherPart) then
                    visited[otherPart] = true
                    table.insert(assembly, otherPart)
                    table.insert(toCheck, otherPart)
                end
            end
        end

        for _, otherPart in pairs(workspace:GetPartBoundsInBox(currentPart.CFrame, currentPart.Size * 3)) do
            if not visited[otherPart] and isDraggableObjectFunc(otherPart) then
                for _, child in pairs(otherPart:GetChildren()) do
                    if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
                        local connectedPart = child.Part0 == otherPart and child.Part1 or child.Part0
                        if connectedPart == currentPart then
                            visited[otherPart] = true
                            table.insert(assembly, otherPart)
                            table.insert(toCheck, otherPart)
                            break
                        end
                    end
                end
            end
        end
    end

    return assembly
end

function WeldSystem.getPartWelds(part)
    local welds = {}
    for _, child in pairs(part:GetChildren()) do
        if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
            table.insert(welds, child)
        end
    end
    return welds
end

function WeldSystem.getAssemblyWeldCount(assembly)
    local totalWelds = 0
    local countedWelds = {}

    for _, part in pairs(assembly) do
        for _, child in pairs(part:GetChildren()) do
            if child:IsA("WeldConstraint") and child.Name:find("DragDropWeld") then
                if not countedWelds[child] then
                    countedWelds[child] = true
                    totalWelds = totalWelds + 1
                end
            end
        end
    end

    return totalWelds
end

function WeldSystem.cleanup()
    removeHoverHighlight()
    hoveredObject = nil
end

return WeldSystem
