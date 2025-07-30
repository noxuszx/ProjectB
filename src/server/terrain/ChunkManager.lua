--[[
	ChunkManager.lua
	Handles chunk-based terrain generation and management
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ChunkConfig = require(game.ReplicatedStorage.Shared.config.ChunkConfig)
local terrain = require(game.ReplicatedStorage.Shared.utilities.Terrain)

local ChunkManager = {}
local chunks = {}

local chunkFolder = Instance.new("Folder")
chunkFolder.Name = "Chunks"
chunkFolder.Parent = Workspace

local function createChunkPart(x, z, width, depth, height)
	local part = Instance.new("Part")
	part.Size = Vector3.new(width, height, depth)
	part.Position = Vector3.new(x, height / 2, z)
	part.Material = ChunkConfig.TERRAIN_MATERIAL
	part.Color = ChunkConfig.TERRAIN_COLOR
	part.Anchored = true
	part.CanCollide = true
	part.Parent = chunkFolder
	return part
end

function ChunkManager.generateChunk(cx, cz)
	local chunkSize = ChunkConfig.CHUNK_SIZE
	local baseX, baseZ = cx * chunkSize, cz * chunkSize

for x = 0, chunkSize - 1, chunkSize / ChunkConfig.SUBDIVISIONS do
		for z = 0, chunkSize - 1, chunkSize / ChunkConfig.SUBDIVISIONS do
			local worldX, worldZ = baseX + x, baseZ + z
			local height = terrain.getTerrainHeight(worldX, worldZ)
					
			local subdivisionSize = chunkSize / ChunkConfig.SUBDIVISIONS
			createChunkPart(worldX, worldZ, subdivisionSize, subdivisionSize, height)
		end
	end

	local chunkKey = cx .. "," .. cz
	chunks[chunkKey] = true
end

function ChunkManager.clearChunks()
	for _, child in ipairs(chunkFolder:GetChildren()) do
		child:Destroy()
	end
	chunks = {}
end

function ChunkManager.init()
	ChunkManager.clearChunks()

	local renderDistance = ChunkConfig.RENDER_DISTANCE
	
	for cx = -renderDistance, renderDistance do
		for cz = -renderDistance, renderDistance do
			ChunkManager.generateChunk(cx, cz)
		end
	end
end

return ChunkManager
