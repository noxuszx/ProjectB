--[[
	NoiseGenerator.lua
	Utilities for generating noise for terrain height variation
]]--

local NoiseGenerator = {}

local function hash(x, y)
	local n = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
	return n - math.floor(n)
end

local function smoothstep(t)
	return t * t * (3 - 2 * t)
end

-- Linear interpolation
local function lerp(a, b, t)
	return a + (b - a) * t
end

function NoiseGenerator.noise(x, y)
	local xi = math.floor(x)
	local yi = math.floor(y)
	local xf = x - xi
	local yf = y - yi

	local a = hash(xi, yi)
	local b = hash(xi + 1, yi)
	local c = hash(xi, yi + 1)
	local d = hash(xi + 1, yi + 1)

	local u = smoothstep(xf)
	local v = smoothstep(yf)

	local x1 = lerp(a, b, u)
	local x2 = lerp(c, d, u)

	return lerp(x1, x2, v)
end

function NoiseGenerator.fractalNoise(x, y, octaves, persistence, scale)
	local value = 0
	local amplitude = 1
	local frequency = scale
	local maxValue = 0
	
	for i = 1, octaves do
		value = value + NoiseGenerator.noise(x * frequency, y * frequency) * amplitude
		maxValue = maxValue + amplitude
		amplitude = amplitude * persistence
		frequency = frequency * 2
	end
	
	return value / maxValue
end

function NoiseGenerator.getTerrainHeight(x, z, config)
	local noiseValue = NoiseGenerator.fractalNoise(
		x, z,
		config.NOISE_OCTAVES,
		config.NOISE_PERSISTENCE,
		config.NOISE_SCALE
	)
	
	local heightRange = config.HEIGHT_RANGE.MAX - config.HEIGHT_RANGE.MIN
	local height = config.BASE_HEIGHT + config.HEIGHT_RANGE.MIN + (noiseValue * heightRange)
	
	return height
end

return NoiseGenerator
