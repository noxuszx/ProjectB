High-impact changes
1) Make isDraggable O(1) by relying on tags instead of parent-name checks
•  You already tag large environment folders as NON_DRAGGABLE and WELDABLE in initializeDefaultTags.
•  Use only tag checks at runtime and remove the chain of parent.Name checks and the workspace-parent heuristic. That avoids extra property reads and ancestry assumptions and lets you control behavior purely via data (tags).

Example:
•  Before: multiple HasTag calls + parent.Name checks + Anchored/parent == workspace branch.
•  After: two HasTag checks decide it.

Proposed implementation:
•  Keep the “NonDraggable beats Draggable” precedence you already have.
•  If neither tag exists, default to false (or decide policy based on your game needs).
•  If you need default-draggable behavior for loose parts, assign DRAGGABLE during init instead of probing per call.

2) Prefer event-driven tagging over scanning
•  Instead of scanning workspace in initializeDefaultTags and tagging all descendants every time, add listeners that auto-tag new instances as they appear:
•  For each folder you treat as non-draggable (Chunks, SpawnedVegetation, etc.), connect to DescendantAdded once and add the appropriate tags to BasePart descendants.
•  For items/templates that will later be cloned, tag them at authoring time or on first clone using a central listener.

Benefits:
•  Zero cost on subsequent spawns.
•  No need to re-run a global scan; new content becomes consistent automatically.

Sketch:
•  When game starts (server), for each “NonDraggable” folder F:
•  Tag all current descendants once (non-blocking chunking, see #5).
•  Connect F.DescendantAdded: if BasePart, add NON_DRAGGABLE, WELDABLE.

3) Cache “live instances” per tag to avoid repeated filtering
•  getLiveTagged currently calls CollectionService:GetTagged(tag) and filters by IsDescendantOf(workspace) each time.
•  Maintain a small cache per tag that is updated via GetInstanceAddedSignal(tag) and GetInstanceRemovedSignal(tag), and track whether instance is live via AncestryChanged.
•  Then getLiveTagged can return a pre-built array (copy if you need immutability) without scanning.

Sketch:
•  On start:
•  For each tag you use frequently, create:
◦  liveSet: { [Instance] = true }
◦  liveList: array
•  On GetInstanceAddedSignal(tag): connect inst.AncestryChanged and add/remove from liveSet/liveList if inst:IsDescendantOf(workspace).
•  On GetInstanceRemovedSignal(tag): remove from liveSet/liveList.
•  getLiveTagged(tag) returns liveList or a copy of it.

4) Chunk large tagging work to avoid frame hitches
•  Tagging thousands of parts in a frame can hitch the server.
•  Process in batches (e.g., 512 or 1024 instances per step) using task.defer() (or RunService.Heartbeat) to yield.

Sketch:
•  Collect an array via GetDescendants().
•  For i = 1, n, step BATCH do
•  for j in i..i+BATCH-1: AddTag
•  task.defer(function() end) or task.wait()

5) Minimize method calls in hot paths
•  Replace pairs with ipairs for arrays from GetChildren/GetDescendants — typically faster and avoids hash iteration.
•  Avoid repeated calls to hasTag for the same object/tag combo in a single function (store to local).
•  Hoist frequently used services/strings/local references outside loops.

Concrete code refinements
A) isDraggable simplified to tags-only
•  Current code checks:
•  NON_DRAGGABLE tag
•  DRAGGABLE tag
•  Parent folder names
•  Anchored and parent == workspace
•  If you tag during initialize (or via listeners) to reflect intended state, you can eliminate ancestry/name checks.

Suggested:
function CollectionServiceTags.isDraggable(object)
    if not object or not object.Parent then
        return false
    end
    if CollectionServiceTags.hasTag(object, CollectionServiceTags.NON_DRAGGABLE) then
        return false
    end
    if CollectionServiceTags.hasTag(object, CollectionServiceTags.DRAGGABLE) then
        return true
    end
    return false
end

If you still want a default policy for “loose, non-anchored top-level parts,” assign DRAGGABLE in initializeDefaultTags to those parts once instead of re-evaluating per call.

B) Use ipairs and GetDescendants in tagFolder
•  Reduce recursion/closure overhead and use a single traversal.

Before:
for _, child in pairs(container:GetChildren()) do
    ...
    if recursive and (child:IsA("Folder") or child:IsA("Model")) then
        processObjects(child)
    end
end

After:
local function tagFolder(folder, tag)
    if not folder or not tag then return 0 end
    local count = 0
    for _, inst in ipairs(folder:GetDescendants()) do
        if inst:IsA("BasePart") then
            CollectionServiceTags.addTag(inst, tag)
            count += 1
        end
    end
    return count
end

C) Guard or remove debug prints
•  initializeDefaultTags currently prints quite a bit; that can be costly and noisy at scale. Wrap in a DEBUG flag:

local DEBUG = false
local function dprint(...)
    if DEBUG then
        print(...)
    end
end

Replace print(...) calls with dprint(...).

D) Precompute name sets once
•  Where you still rely on name lookups (prefer avoiding it), convert to a set for O(1) membership:

local NON_DRAGGABLE_FOLDERS = {
    Chunks = true,
    SpawnedVegetation = true,
    SpawnedRocks = true,
    SpawnedStructures = true,
}

Then if you must check a parent folder by name, use if NON_DRAGGABLE_FOLDERS[parent.Name] then ...

E) Event-driven auto-tagging example for non-draggable folders
•  On server startup:

local function tagBasePart(inst, tags)
    if inst:IsA("BasePart") then
        for _, t in ipairs(tags) do
            CollectionService:AddTag(inst, t)
        end
    end
end

local function tagExistingAndListen(folder, tags)
    if not folder then return end
    for _, inst in ipairs(folder:GetDescendants()) do
        tagBasePart(inst, tags)
    end
    folder.DescendantAdded:Connect(function(inst)
        tagBasePart(inst, tags)
    end)
end

-- Usage:
tagExistingAndListen(workspace:FindFirstChild("Chunks"), { CollectionServiceTags.NON_DRAGGABLE, CollectionServiceTags.WELDABLE })
tagExistingAndListen(workspace:FindFirstChild("SpawnedVegetation"), { CollectionServiceTags.NON_DRAGGABLE, CollectionServiceTags.WELDABLE })
-- ... repeat for the other folders

F) Cached live-tag tracking
•  For tags you query frequently (e.g., protected geometry or interactables):

local TagCache = {}

local function ensureTagCache(tag)
    local cache = TagCache[tag]
    if cache then return cache end

    cache = { set = {}, list = {} }
    TagCache[tag] = cache

    local function onLiveChanged(inst)
        local isLive = inst:IsDescendantOf(workspace)
        local set = cache.set
        if isLive and not set[inst] then
            set[inst] = true
            table.insert(cache.list, inst)
        elseif not isLive and set[inst] then
            set[inst] = nil
            -- remove from list (swap remove)
            local list = cache.list
            for i = #list, 1, -1 do
                if list[i] == inst then
                    list[i] = list[#list]
                    list[#list] = nil
                    break
                end
            end
        end
    end

    for _, inst in ipairs(CollectionService:GetTagged(tag)) do
        onLiveChanged(inst)
        inst.AncestryChanged:Connect(function()
            onLiveChanged(inst)
        end)
    end

    CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
        inst.AncestryChanged:Connect(function()
            onLiveChanged(inst)
        end)
        onLiveChanged(inst)
    end)

    CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
        onLiveChanged(inst) -- will drop it
    end)

    return cache
end

function CollectionServiceTags.getLiveTagged(tag)
    local cache = ensureTagCache(tag)
    -- Return the array; copy if callers may mutate it
    return cache.list
end

G) Batch large operations
•  When tagging many instances at once:

local function batchApply(instances, fn, batchSize)
    batchSize = batchSize or 1024
    for i = 1, #instances do
        fn(instances[i])
        if (i % batchSize) == 0 then
            task.defer(function() end)
        end
    end
end

-- Example use:
local descendants = folder:GetDescendants()
batchApply(descendants, function(inst)
    if inst:IsA("BasePart") then
        CollectionService:AddTag(inst, CollectionServiceTags.NON_DRAGGABLE)
        CollectionService:AddTag(inst, CollectionServiceTags.WELDABLE)
    end
end)

Smaller wins and hygiene
•  Use ipairs instead of pairs where the table is array-like.
•  Consider using table.create(n) when you know array sizes (e.g., prealloc in batch loops) to reduce reallocations.
•  Avoid double HasTag calls for the same (object, tag) in the same function; store result in a local.
•  Keep this module server-authoritative for tagging; let tags replicate to clients (CollectionService does replicate tags). If you must run client-side checks, ensure the heavy lifting (tagging) is server-only.
•  Use Luau type annotations for the public API for maintainability and potential future perf benefits from specialization.

Potential simplified isWeldable
•  You already give WELDABLE to most non-draggable/static content.
•  You can simplify isWeldable to tag checks only for determinism:

function CollectionServiceTags.isWeldable(object)
    if not object then return false end
    if CollectionServiceTags.hasTag(object, CollectionServiceTags.NON_WELDABLE) then
        return false
    end
    return CollectionServiceTags.hasTag(object, CollectionServiceTags.WELDABLE)
end

If you still want the fallback on CanCollide, keep it — just be aware it adds property checks in hot paths.

Summary of priorities
1) Switch to tag-only checks in hot paths (isDraggable, isWeldable) and ensure tags are assigned up front.
2) Move to event-driven tagging for dynamic content (DescendantAdded + GetInstanceAddedSignal).
3) Add a live-per-tag cache maintained by signals to make getLiveTagged O(1).
4) Batch heavy tagging operations to avoid frame hitches.
5) Cleanups: ipairs over pairs, fewer prints, precomputed sets.

If you want, I can draft a patch that implements: simplified isDraggable/isWeldable, event-driven auto-tagging helpers, the live-tag cache, and batch utilities, behind minimal changes to your current API.

  print(workspace.EgyptianSkeleton2.Torso.Neck.C0)
  -- Optional: also inspect its Euler angles:
  local rx, ry, rz = workspace.EgyptianSkeleton2.Torso.Neck.C0:ToEulerAnglesXYZ()
  print("C0 Euler XYZ (deg):", math.deg(rx), math.deg(ry), math.deg(rz))