--[[
    TemplateCache.lua
    Template caching system for CustomModelSpawner optimization
    Pre-loads and caches model templates with computed bounding boxes and primary parts
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TemplateCache = {}
TemplateCache.__index = TemplateCache

function TemplateCache.new()
    local self = setmetatable({}, TemplateCache)
    self.templates = {}        -- [modelName] = model template
    self.boundingBoxes = {}    -- [modelName] = {cframe, size}
    self.primaryParts = {}     -- [modelName] = primary part reference
    return self
end

-- Get a template by name, lazy loading if necessary
function TemplateCache:getTemplate(modelName, category, modelFolders)
    if not self.templates[modelName] then
        self:_loadTemplate(modelName, category, modelFolders)
    end
    return self.templates[modelName]
end

-- Get cached bounding box for a template
function TemplateCache:getBoundingBox(modelName)
    return self.boundingBoxes[modelName]
end

-- Public helper: cache a template instance (Model or MeshPart) directly
function TemplateCache:addTemplate(instance)
    if not instance then return end
    local name = instance.Name
    if self.boundingBoxes[name] then return end -- already cached

    local success, _, size = pcall(function()
        if instance:IsA("Model") then
            return instance:GetBoundingBox()
        elseif instance:IsA("MeshPart") then
            return instance.CFrame, instance.Size
        end
    end)

    if success and size then
        self.boundingBoxes[name] = {size = size}
    else
        self.boundingBoxes[name] = {size = Vector3.new(1,1,1)}
        warn("[TemplateCache] Failed to cache instance bounding box for", name)
    end
end

-- Get cached primary part for a template
function TemplateCache:getPrimaryPart(modelName)
    return self.primaryParts[modelName]
end

-- Check if a template is cached
function TemplateCache:isCached(modelName)
    return self.templates[modelName] ~= nil
end

-- Private: Load and cache a template
function TemplateCache:_loadTemplate(modelName, category, modelFolders)
    if not category or not modelFolders or not modelFolders[category] then
        warn("[TemplateCache] Cannot load template - missing category or folder path:", modelName, category)
        return false
    end
    
    -- Navigate to the model folder
    local folder = ReplicatedStorage
    for part in modelFolders[category]:gmatch("[^%.]+") do
        folder = folder:FindFirstChild(part)
        if not folder then
            warn("[TemplateCache] Model folder not found:", modelFolders[category])
            return false
        end
    end
    
    -- Find the specific model
    local model = folder:FindFirstChild(modelName)
    if not model then
        warn("[TemplateCache] Model not found:", modelName, "in", modelFolders[category])
        return false
    end
    
    if not (model:IsA("Model") or model:IsA("MeshPart")) then
        warn("[TemplateCache] Invalid model type:", modelName, model.ClassName)
        return false
    end
    
    -- Cache the template
    self.templates[modelName] = model
    
    -- Pre-compute and cache bounding box
    local success, cframe, size = pcall(function()
        if model:IsA("Model") then
            return model:GetBoundingBox()
        elseif model:IsA("MeshPart") then
            return model.CFrame, model.Size
        end
    end)
    
    if success and size then
        self.boundingBoxes[modelName] = {cframe = cframe, size = size}
    else
        warn("[TemplateCache] Failed to compute bounding box for:", modelName)
        self.boundingBoxes[modelName] = {cframe = CFrame.new(), size = Vector3.new(1, 1, 1)}
    end
    
    -- Cache primary part for Models
    if model:IsA("Model") then
        local primaryPart = model.PrimaryPart
        if not primaryPart then
            -- Find first BasePart as fallback
            primaryPart = model:FindFirstChildOfClass("BasePart")
            if primaryPart then
                model.PrimaryPart = primaryPart
            end
        end
        self.primaryParts[modelName] = primaryPart
    end
    
    print("[TemplateCache] Cached template:", modelName, "(" .. model.ClassName .. ")")
    return true
end

-- Pre-load all templates for a category
function TemplateCache:preloadCategory(category, modelFolders)
    if not modelFolders or not modelFolders[category] then
        warn("[TemplateCache] Cannot preload category - missing folder path:", category)
        return 0
    end
    
    local folder = ReplicatedStorage
    for part in modelFolders[category]:gmatch("[^%.]+") do
        folder = folder:FindFirstChild(part)
        if not folder then
            warn("[TemplateCache] Model folder not found:", modelFolders[category])
            return 0
        end
    end
    
    local count = 0
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") or child:IsA("MeshPart") then
            if self:_loadTemplate(child.Name, category, modelFolders) then
                count = count + 1
            end
        end
    end
    
    print("[TemplateCache] Preloaded", count, category, "templates")
    return count
end

-- Get cache statistics
function TemplateCache:getStats()
    local templateCount = 0
    local memoryEstimate = 0
    
    for modelName, template in pairs(self.templates) do
        templateCount = templateCount + 1
        -- Rough memory estimate (very approximate)
        if template:IsA("Model") then
            memoryEstimate = memoryEstimate + #template:GetDescendants() * 100  -- ~100 bytes per instance
        else
            memoryEstimate = memoryEstimate + 500  -- ~500 bytes per MeshPart
        end
    end
    
    return {
        templateCount = templateCount,
        memoryEstimateKB = math.floor(memoryEstimate / 1024),
        boundingBoxCount = #self.boundingBoxes,
        primaryPartCount = #self.primaryParts
    }
end

-- Clear cached templates (for memory management)
function TemplateCache:clear()
    self.templates = {}
    self.boundingBoxes = {}
    self.primaryParts = {}
    print("[TemplateCache] Cache cleared")
end

return TemplateCache