--!strict
-- 50-instance zero-GC ring buffer for PlasmaTracerBeam

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetRegistry = require(ReplicatedStorage:WaitForChild("Shared").configs.AssetRegistry)

local TracerPool = {}

local POOL_SIZE: number = 50
local TRACER_LIFETIME: number = 0.15

local pool: { Beam } = table.create(POOL_SIZE)
local attachmentsA: { Attachment } = table.create(POOL_SIZE)
local attachmentsB: { Attachment } = table.create(POOL_SIZE)
local poolIndex: number = 1

function TracerPool.init(): ()
	local template: Instance = AssetRegistry.VFX.PlasmaTracerBeam
	local container: Folder = Instance.new("Folder")
	container.Name = "TracerPoolContainer"
	container.Parent = workspace

	for i = 1, POOL_SIZE do
		local partA: Part = Instance.new("Part")
		partA.Anchored = true
		partA.CanCollide = false
		partA.CanQuery = false
		partA.CanTouch = false
		partA.Transparency = 1
		partA.Size = Vector3.new(0.1, 0.1, 0.1)
		partA.Name = `TracerAnchorA_{i}`
		partA.Parent = container

		local partB: Part = Instance.new("Part")
		partB.Anchored = true
		partB.CanCollide = false
		partB.CanQuery = false
		partB.CanTouch = false
		partB.Transparency = 1
		partB.Size = Vector3.new(0.1, 0.1, 0.1)
		partB.Name = `TracerAnchorB_{i}`
		partB.Parent = container

		local attA: Attachment = Instance.new("Attachment")
		attA.Parent = partA
		local attB: Attachment = Instance.new("Attachment")
		attB.Parent = partB

		local beam: Beam = template:Clone() :: Beam
		beam.Attachment0 = attA
		beam.Attachment1 = attB
		beam.Enabled = false
		beam.Parent = partA

		pool[i] = beam
		attachmentsA[i] = attA
		attachmentsB[i] = attB
	end
end

function TracerPool.fire(origin: Vector3, target: Vector3, _speed: number): ()
	local index: number = poolIndex
	poolIndex = (poolIndex % POOL_SIZE) + 1

	local beam: Beam = pool[index]
	local attA: Attachment = attachmentsA[index]
	local attB: Attachment = attachmentsB[index]

	local partA: BasePart = attA.Parent :: BasePart
	local partB: BasePart = attB.Parent :: BasePart

	partA.CFrame = CFrame.new(origin)
	partB.CFrame = CFrame.new(target)
	beam.Enabled = true

	-- Auto-disable after lifetime
	task.delay(TRACER_LIFETIME, function(): ()
		beam.Enabled = false
	end)
end

return TracerPool
