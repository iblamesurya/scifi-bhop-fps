--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local POOL_SIZE = 50
local TRACER_LIFETIME = 0.08
local DEFAULT_WIDTH_0 = 0.14
local DEFAULT_WIDTH_1 = 0.24
local OVERDRIVE_WIDTH_MULTIPLIER = 1.65

local STANDARD_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 250, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 225, 255)),
})

local OVERDRIVE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 210, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 55, 215)),
})

type PooledTracer = {
	attachment0: Attachment,
	attachment1: Attachment,
	beam: Beam,
	active: boolean,
	elapsed: number,
	initialWidth0: number,
	initialWidth1: number,
}

local TracerPool = {}

local pool: { PooledTracer } = table.create(POOL_SIZE)
local nextPoolIndex = 1
local isInitialized = false
local renderConnection: RBXScriptConnection? = nil

local function resolveBeamTemplate(): Beam?
	local graphicsFolder = ReplicatedStorage:FindFirstChild("Graphics")
	if not graphicsFolder then
		return nil
	end

	local vfxFolder = graphicsFolder:FindFirstChild("VFX")
	if not vfxFolder then
		return nil
	end

	local candidate = vfxFolder:FindFirstChild("PlasmaTracerBeam")
	if candidate and candidate:IsA("Beam") then
		return candidate
	end

	return nil
end

local function createProceduralBeam(index: number, template: Beam?): Beam
	if template then
		local cloned = template:Clone()
		cloned.Name = string.format("PlasmaTracerBeam_%d", index)
		cloned.Enabled = false
		return cloned
	end

	local beam = Instance.new("Beam")
	beam.Name = string.format("PlasmaTracerBeam_%d", index)
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 4
	beam.Segments = 1
	beam.Color = STANDARD_COLOR
	beam.Width0 = DEFAULT_WIDTH_0
	beam.Width1 = DEFAULT_WIDTH_1
	beam.Transparency = NumberSequence.new(0)
	beam.Enabled = false
	return beam
end

local function stepTracers(dt: number)
	for i = 1, #pool do
		local entry = pool[i]
		if entry.active then
			local elapsed = entry.elapsed + dt
			entry.elapsed = elapsed

			if elapsed >= TRACER_LIFETIME then
				entry.active = false
				entry.beam.Enabled = false
			else
				local alpha = math.clamp(elapsed / TRACER_LIFETIME, 0, 1)
				local invAlpha = 1 - alpha
				entry.beam.Width0 = entry.initialWidth0 * invAlpha
				entry.beam.Width1 = entry.initialWidth1 * invAlpha
				entry.beam.Transparency = NumberSequence.new(alpha)
			end
		end
	end
end

function TracerPool.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	local terrain = workspace.Terrain
	local beamTemplate = resolveBeamTemplate()

	for i = 1, POOL_SIZE do
		local attachment0 = Instance.new("Attachment")
		attachment0.Name = string.format("A0_%d", i)
		attachment0.Parent = terrain

		local attachment1 = Instance.new("Attachment")
		attachment1.Name = string.format("A1_%d", i)
		attachment1.Parent = terrain

		local beam = createProceduralBeam(i, beamTemplate)
		beam.Attachment0 = attachment0
		beam.Attachment1 = attachment1
		beam.Parent = terrain

		pool[i] = {
			attachment0 = attachment0,
			attachment1 = attachment1,
			beam = beam,
			active = false,
			elapsed = 0,
			initialWidth0 = beam.Width0 > 0 and beam.Width0 or DEFAULT_WIDTH_0,
			initialWidth1 = beam.Width1 > 0 and beam.Width1 or DEFAULT_WIDTH_1,
		}
	end

	renderConnection = RunService.RenderStepped:Connect(stepTracers)
end

function TracerPool.SpawnTracer(startPos: Vector3, endPos: Vector3, isOverdrive: boolean)
	if not isInitialized then
		TracerPool.Init()
	end

	local entry = pool[nextPoolIndex]
	nextPoolIndex = (nextPoolIndex % POOL_SIZE) + 1

	if not entry then
		return
	end

	local widthScale = if isOverdrive then OVERDRIVE_WIDTH_MULTIPLIER else 1.0
	local width0 = DEFAULT_WIDTH_0 * widthScale
	local width1 = DEFAULT_WIDTH_1 * widthScale

	entry.attachment0.WorldPosition = startPos
	entry.attachment1.WorldPosition = endPos

	entry.initialWidth0 = width0
	entry.initialWidth1 = width1
	entry.elapsed = 0
	entry.active = true

	local beam = entry.beam
	beam.Color = if isOverdrive then OVERDRIVE_COLOR else STANDARD_COLOR
	beam.Width0 = width0
	beam.Width1 = width1
	beam.Transparency = NumberSequence.new(0)
	beam.Enabled = true
end

return TracerPool