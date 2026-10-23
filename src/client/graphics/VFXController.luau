--!strict
--[[
	VFXController.luau
	Zero-allocation particle VFX dispatcher for weapon muzzle flashes and surface impact sparks.
	Uses pre-allocated attachment ring-buffer pools parented to Workspace.Terrain so zero
	instances are created or garbage-collected per shot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PresetsFolder = ReplicatedStorage:WaitForChild("Graphics"):WaitForChild("Presets")
local GraphicsQualityTiers = require(PresetsFolder:WaitForChild("GraphicsQualityTiers"))
local GraphicsController = require(script.Parent:WaitForChild("GraphicsController"))

type PooledImpactNode = {
	Attachment: Attachment,
	SparkEmitter: ParticleEmitter,
	CoreFlashEmitter: ParticleEmitter,
}

type PooledMuzzleNode = {
	Attachment: Attachment,
	FlashEmitter: ParticleEmitter,
	SparkEmitter: ParticleEmitter,
	FlashLight: PointLight,
}

local IMPACT_POOL_SIZE = 24
local MUZZLE_POOL_SIZE = 8

local initialized = false
local impactPool: { PooledImpactNode } = table.create(IMPACT_POOL_SIZE)
local impactPoolCursor = 0

local muzzlePool: { PooledMuzzleNode } = table.create(MUZZLE_POOL_SIZE)
local muzzlePoolCursor = 0
local boundMuzzleMap: { [Attachment]: PooledMuzzleNode } = setmetatable({}, { __mode = "k" }) :: any

local VFXController = {}

local function createImpactNode(index: number): PooledImpactNode
	local attachment = Instance.new("Attachment")
	attachment.Name = string.format("PooledImpactVFX_%02d", index)
	attachment.Parent = Workspace.Terrain

	local sparkEmitter = Instance.new("ParticleEmitter")
	sparkEmitter.Name = "ImpactSparks"
	sparkEmitter.Enabled = false
	sparkEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 245, 255)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(0, 210, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 40)),
	})
	sparkEmitter.LightEmission = 1
	sparkEmitter.LightInfluence = 0
	sparkEmitter.Brightness = 3
	sparkEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkEmitter.Squash = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.8),
		NumberSequenceKeypoint.new(1, 2.5),
	})
	sparkEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkEmitter.Lifetime = NumberRange.new(0.14, 0.28)
	sparkEmitter.Speed = NumberRange.new(18, 38)
	sparkEmitter.SpreadAngle = Vector2.new(42, 42)
	sparkEmitter.Drag = 4.5
	sparkEmitter.Acceleration = Vector3.new(0, -65, 0)
	sparkEmitter.EmissionDirection = Enum.NormalId.Front
	sparkEmitter.Parent = attachment

	local coreFlash = Instance.new("ParticleEmitter")
	coreFlash.Name = "ImpactCoreFlash"
	coreFlash.Enabled = false
	coreFlash.Color = ColorSequence.new(Color3.fromRGB(190, 248, 255), Color3.fromRGB(0, 195, 255))
	coreFlash.LightEmission = 1
	coreFlash.LightInfluence = 0
	coreFlash.Brightness = 4
	coreFlash.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(1, 0),
	})
	coreFlash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	coreFlash.Lifetime = NumberRange.new(0.05, 0.08)
	coreFlash.Speed = NumberRange.new(0, 0)
	coreFlash.Parent = attachment

	return {
		Attachment = attachment,
		SparkEmitter = sparkEmitter,
		CoreFlashEmitter = coreFlash,
	}
end

local function createMuzzleNode(index: number): PooledMuzzleNode
	local attachment = Instance.new("Attachment")
	attachment.Name = string.format("PooledMuzzleVFX_%02d", index)
	attachment.Parent = Workspace.Terrain

	local flashEmitter = Instance.new("ParticleEmitter")
	flashEmitter.Name = "MuzzleCoreFlash"
	flashEmitter.Enabled = false
	flashEmitter.LockedToPart = true
	flashEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 252, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 120, 255)),
	})
	flashEmitter.LightEmission = 1
	flashEmitter.LightInfluence = 0
	flashEmitter.Brightness = 4
	flashEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	flashEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	flashEmitter.Lifetime = NumberRange.new(0.035, 0.055)
	flashEmitter.Speed = NumberRange.new(0, 2)
	flashEmitter.RotSpeed = NumberRange.new(-360, 360)
	flashEmitter.Rotation = NumberRange.new(0, 360)
	flashEmitter.EmissionDirection = Enum.NormalId.Front
	flashEmitter.Parent = attachment

	local sparkEmitter = Instance.new("ParticleEmitter")
	sparkEmitter.Name = "MuzzleSparks"
	sparkEmitter.Enabled = false
	sparkEmitter.LockedToPart = true
	sparkEmitter.Color = ColorSequence.new(Color3.fromRGB(165, 245, 255), Color3.fromRGB(0, 185, 255))
	sparkEmitter.LightEmission = 1
	sparkEmitter.LightInfluence = 0
	sparkEmitter.Brightness = 3
	sparkEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkEmitter.Squash = NumberSequence.new(1.5, 2.2)
	sparkEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkEmitter.Lifetime = NumberRange.new(0.04, 0.08)
	sparkEmitter.Speed = NumberRange.new(14, 28)
	sparkEmitter.SpreadAngle = Vector2.new(22, 22)
	sparkEmitter.EmissionDirection = Enum.NormalId.Front
	sparkEmitter.Parent = attachment

	local flashLight = Instance.new("PointLight")
	flashLight.Name = "MuzzleLight"
	flashLight.Enabled = false
	flashLight.Color = Color3.fromRGB(70, 225, 255)
	flashLight.Brightness = 2.4
	flashLight.Range = 9
	flashLight.Shadows = false
	flashLight.Parent = attachment

	return {
		Attachment = attachment,
		FlashEmitter = flashEmitter,
		SparkEmitter = sparkEmitter,
		FlashLight = flashLight,
	}
end

local function ensurePoolsAllocated(): ()
	if #impactPool == 0 then
		for i = 1, IMPACT_POOL_SIZE do
			impactPool[i] = createImpactNode(i)
		end
	end
	if #muzzlePool == 0 then
		for i = 1, MUZZLE_POOL_SIZE do
			muzzlePool[i] = createMuzzleNode(i)
		end
	end
end

function VFXController.Init(): ()
	if initialized then
		return
	end
	initialized = true
	ensurePoolsAllocated()
end

function VFXController.EmitMuzzleFlash(attachment: Attachment): ()
	if typeof(attachment) ~= "Instance" or not attachment:IsA("Attachment") then
		return
	end

	ensurePoolsAllocated()

	local node = boundMuzzleMap[attachment]
	if not node then
		muzzlePoolCursor = (muzzlePoolCursor % MUZZLE_POOL_SIZE) + 1
		node = muzzlePool[muzzlePoolCursor]
		boundMuzzleMap[attachment] = node
		node.FlashEmitter.Parent = attachment
		node.SparkEmitter.Parent = attachment
		node.FlashLight.Parent = attachment
	end

	local tier = if GraphicsController.IsCompetitiveMode()
		then GraphicsQualityTiers.Low
		else GraphicsQualityTiers.High

	node.FlashEmitter:Emit(2)
	node.SparkEmitter:Emit(tier.MuzzleSparkCount)
end

function VFXController.SpawnImpactSparks(position: Vector3, normal: Vector3): ()
	ensurePoolsAllocated()

	impactPoolCursor = (impactPoolCursor % IMPACT_POOL_SIZE) + 1
	local node = impactPool[impactPoolCursor]

	local safeNormal = if normal.Magnitude > 1e-4 then normal.Unit else Vector3.yAxis
	node.Attachment.WorldCFrame = CFrame.lookAt(position, position + safeNormal)

	local tier = if GraphicsController.IsCompetitiveMode()
		then GraphicsQualityTiers.Low
		else GraphicsQualityTiers.High

	node.CoreFlashEmitter:Emit(1)
	node.SparkEmitter:Emit(tier.ImpactSparkCount)
end

return table.freeze(VFXController)
