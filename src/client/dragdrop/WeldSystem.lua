--[[
    WeldSystem.lua
    Handles welding/unwelding mechanics for drag and drop system
]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WeldSystem = {}
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Weld state
local hoveredObject = nil
local hoverHighlight = nil
local lastTarget = nil
local lastUpdateTime = 0
local UPDATE_THROTTLE = 0.1 -- Only update 10 times per second max

local function createHoverHighlight(object)
    local highlight = Instance.new("SelectionBox")
    highlight.Adornee = object
    highlight.Color3 = Color3.fromRGB(255, 255, 0) -- Yellow for hover
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
    
    -- Only process if target changed or enough time has passed
    if target == lastTarget and (currentTime - lastUpdateTime) < UPDATE_THROTTLE then
        return
    end
    
    lastTarget = target
    lastUpdateTime = currentTime
    
    -- Only highlight draggable objects when not dragging
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

function WeldSystem.weldObject(draggedObject, currentWeld)
    local targetObject = hoveredObject or draggedObject
    if not targetObject then 
        print("No object to weld - hover over a part or drag one")
        return nil, false
    end
    
    -- Check if object is already welded
    local existingWeld = nil
    for _, child in pairs(targetObject:GetChildren()) do
        if child:IsA("WeldConstraint") and child.Name == "DragDropWeld" then
            existingWeld = child
            break
        end
    end
    
    if existingWeld then
        existingWeld:Destroy()
        print("Unwelded", targetObject.Name)
        
        if currentWeld == existingWeld then
            return nil, false
        else
            return currentWeld, (currentWeld ~= nil)
        end
    else
        -- Weld logic - find what the part is directly touching
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        
        -- Filter out target object AND entire player character
        local filterList = {targetObject}
        local character = Players.LocalPlayer.Character
        if character then
            table.insert(filterList, character)
        end
        raycastParams.FilterDescendantsInstances = filterList
        
        local directions = {
            Vector3.new(0, -1, 0),  -- Down
            Vector3.new(0, 1, 0),   -- Up
            Vector3.new(1, 0, 0),   -- Right
            Vector3.new(-1, 0, 0),  -- Left
            Vector3.new(0, 0, 1),   -- Forward
            Vector3.new(0, 0, -1)   -- Back
        }
        
        local weldTarget = nil
        local shortestDistance = math.huge
        
        for _, direction in pairs(directions) do
            local rayOrigin = targetObject.Position
            local rayDirection = direction * (targetObject.Size.Magnitude / 2 + 0.1)
            
            local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
            
            if raycastResult then
                local hitPart = raycastResult.Instance
                local distance = raycastResult.Distance
                
                -- DEBUG: Show what we're hitting
                print("DEBUG: Raycast hit:", hitPart.Name, "Parent:", hitPart.Parent.Name, "Distance:", math.floor(distance * 100) / 100)
                
                -- Comprehensive character check
                if character then
                    if hitPart:IsDescendantOf(character) then
                        print("DEBUG: Skipping - part is descendant of character")
                        continue
                    end
                    if hitPart.Parent == character then
                        print("DEBUG: Skipping - part parent is character")
                        continue
                    end
                    if hitPart == character then
                        print("DEBUG: Skipping - part IS character")
                        continue
                    end
                end
                
                -- Skip common player-related part names
                if hitPart.Name == "Handle" or hitPart.Name == "HumanoidRootPart" or 
                   hitPart.Name:find("Torso") or hitPart.Name:find("Head") or
                   hitPart.Name:find("Arm") or hitPart.Name:find("Leg") then
                    print("DEBUG: Skipping - suspicious part name:", hitPart.Name)
                    continue
                end
                
                if distance < shortestDistance and distance < 0.5 then
                    shortestDistance = distance
                    weldTarget = hitPart
                    print("DEBUG: New closest target:", hitPart.Name, "at distance:", distance)
                end
            end
        end
        
        if weldTarget then
            print("DEBUG: Final weld target:", weldTarget.Name, "Parent:", weldTarget.Parent.Name)
            
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = targetObject
            weld.Part1 = weldTarget
            weld.Parent = targetObject
            weld.Name = "DragDropWeld"
            
            print("Welded", targetObject.Name, "to", weldTarget.Name)
            
            if targetObject == draggedObject then
                return weld, true
            else
                return currentWeld, (currentWeld ~= nil)
            end
        else
            print("No directly touching parts found - move part so it touches another part and press Z")
            return currentWeld, (currentWeld ~= nil)
        end
    end
end

function WeldSystem.getWeldedAssembly(part, isDraggableObjectFunc)
    local assembly = {part}
    local visited = {[part] = true}
    local toCheck = {part}
    
    while #toCheck > 0 do
        local currentPart = table.remove(toCheck, 1)
        
        for _, child in pairs(currentPart:GetChildren()) do
            if child:IsA("WeldConstraint") and child.Name == "DragDropWeld" then
                local otherPart = child.Part0 == currentPart and child.Part1 or child.Part0
                if otherPart and not visited[otherPart] and isDraggableObjectFunc(otherPart) then
                    visited[otherPart] = true
                    table.insert(assembly, otherPart)
                    table.insert(toCheck, otherPart)
                end
            end
        end
        
        for _, otherPart in pairs(workspace:GetPartBoundsInBox(currentPart.CFrame, currentPart.Size * 2)) do
            if not visited[otherPart] then
                for _, child in pairs(otherPart:GetChildren()) do
                    if child:IsA("WeldConstraint") and child.Name == "DragDropWeld" then
                        local connectedPart = child.Part0 == otherPart and child.Part1 or child.Part0
                        if connectedPart == currentPart and isDraggableObjectFunc(otherPart) then
                            visited[otherPart] = true
                            table.insert(assembly, otherPart)
                            table.insert(toCheck, otherPart)
                        end
                    end
                end
            end
        end
    end
    
    return assembly
end

function WeldSystem.cleanup()
    removeHoverHighlight()
    hoveredObject = nil
end

return WeldSystem















