--!strict
-- PhantomMidway_ClientController.luau
-- Dynamic Graphics Quality Scaler, Ambient Coastal Audio, Pre-Allocated Material Bullet Impact Pool,
-- and Interactive Vehicle Car Alarm Trigger.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetRegistry = require(Shared:WaitForChild("configs"):WaitForChild("AssetRegistry"))

local PhantomMidway_ClientController = {}

--------------------------------------------------------------------------------
-- 1. DYNAMIC GRAPHICS QUALITY SCALER (MOBILE & LOW-END OPTIMIZATION)
--------------------------------------------------------------------------------
local function updatePostEffectsForQuality()
	local qLevel = UserGameSettings.SavedQualityLevel
	local isLowEnd = (qLevel ~= Enum.SavedQualitySetting.Automatic and qLevel.Value <= 4)

	Lighting.GlobalShadows = not isLowEnd
	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
			effect.Enabled = not isLowEnd
		end
	end
end

--------------------------------------------------------------------------------
-- 2. PRE-ALLOCATED MATERIAL BULLET IMPACT POOL (ZERO GC IN FIRING LOOP)
--------------------------------------------------------------------------------
type ImpactPoolSlot = {
	attachment: Attachment,
	sound: Sound,
	emitter: ParticleEmitter,
}

local IMPACT_POOL_SIZE = 20
local impactPool: { ImpactPoolSlot } = table.create(IMPACT_POOL_SIZE)
local impactPoolIndex = 1
local poolInitialized = false

local envAudio = (AssetRegistry.Audio :: any).Environment or {}
local fallbackImpact = AssetRegistry.Audio.Movement.FootstepMetal
local IMPACT_SOUNDS: { [Enum.Material]: string } = {
	[Enum.Material.Concrete] = envAudio.ImpactConcrete or fallbackImpact,
	[Enum.Material.Asphalt] = envAudio.ImpactAsphalt or fallbackImpact,
	[Enum.Material.Metal] = envAudio.ImpactMetal or fallbackImpact,
	[Enum.Material.Glass] = envAudio.ImpactGlass or fallbackImpact,
	[Enum.Material.WoodPlanks] = envAudio.ImpactWoodPlanks or fallbackImpact,
}

local function initImpactPool()
	if poolInitialized then
		return
	end
	poolInitialized = true

	local terrain = Workspace.Terrain
	for i = 1, IMPACT_POOL_SIZE do
		local attachment = Instance.new("Attachment")
		attachment.Name = "PooledImpactAttachment_" .. tostring(i)
		attachment.Parent = terrain

		local sfx = Instance.new("Sound")
		sfx.Name = "ImpactSFX"
		sfx.SoundId = envAudio.ImpactConcrete or fallbackImpact
		sfx.Volume = 0.55
		sfx.RollOffMaxDistance = 65
		sfx.Parent = attachment

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "ImpactEmitter"
		emitter.Enabled = false
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.2, 0.45)
		emitter.Speed = NumberRange.new(6, 14)
		emitter.SpreadAngle = Vector2.new(35, 35)
		emitter.Parent = attachment

		impactPool[i] = {
			attachment = attachment,
			sound = sfx,
			emitter = emitter,
		}
	end
end

--------------------------------------------------------------------------------
-- 3. INTERACTIVE CAR ALARM TRIGGER
--------------------------------------------------------------------------------
local function triggerVehicleAlarm(vehicleModel: Model)
	if vehicleModel:GetAttribute("AlarmTriggered") then
		return
	end
	vehicleModel:SetAttribute("AlarmTriggered", true)

	local hull = vehicleModel.PrimaryPart
	local alarmSound = hull and hull:FindFirstChild("CarAlarmSound")
	if alarmSound and alarmSound:IsA("Sound") then
		alarmSound:Play()
	end

	-- Flash vehicle headlights/taillights for 12 seconds without using permanent Neon
	task.spawn(function()
		local lights: { BasePart } = {}
		for _, p in ipairs(vehicleModel:GetChildren()) do
			if p:IsA("BasePart") and (string.sub(p.Name, 1, 9) == "Headlight" or string.sub(p.Name, 1, 9) == "Taillight") then
				table.insert(lights, p)
			end
		end
		for i = 1, 24 do
			local on = (i % 2 == 1)
			for _, lp in ipairs(lights) do
				lp.Material = if on then Enum.Material.Neon else Enum.Material.Glass
			end
			task.wait(0.5)
		end
		for _, lp in ipairs(lights) do
			lp.Material = Enum.Material.Glass
		end
		if alarmSound and alarmSound:IsA("Sound") then
			alarmSound:Stop()
		end
		vehicleModel:SetAttribute("AlarmTriggered", false)
	end)
end

--------------------------------------------------------------------------------
-- 4. MATERIAL-BASED BULLET IMPACT DISPATCHER
--------------------------------------------------------------------------------
function PhantomMidway_ClientController.OnWeaponRaycastHit(hitPart: BasePart, hitPosition: Vector3, hitNormal: Vector3)
	if not poolInitialized then
		initImpactPool()
	end

	local slot = impactPool[impactPoolIndex]
	impactPoolIndex = (impactPoolIndex % IMPACT_POOL_SIZE) + 1

	if slot then
		slot.attachment.WorldPosition = hitPosition
		slot.attachment.WorldAxis = hitNormal

		slot.sound.SoundId = IMPACT_SOUNDS[hitPart.Material] or IMPACT_SOUNDS[Enum.Material.Concrete]
		slot.sound:Play()

		if hitPart.Material == Enum.Material.Metal then
			slot.emitter.Color = ColorSequence.new(Color3.fromRGB(255, 210, 110))
			slot.emitter.Size = NumberSequence.new(0.18, 0)
			slot.emitter.Transparency = NumberSequence.new(0, 1)
		elseif CollectionService:HasTag(hitPart, "WindowGlass") then
			slot.emitter.Color = ColorSequence.new(Color3.fromRGB(210, 230, 245))
			slot.emitter.Size = NumberSequence.new(0.25, 0)
			slot.emitter.Transparency = NumberSequence.new(0.1, 1)
		else
			slot.emitter.Color = ColorSequence.new(hitPart.Color)
			slot.emitter.Size = NumberSequence.new(0.45, 0.85)
			slot.emitter.Transparency = NumberSequence.new(0.35, 1)
		end

		slot.emitter:Emit(8)
	end

	-- Check if hit part belongs to an InteractiveVehicle to trigger car alarm
	local ancestorModel = hitPart:FindFirstAncestorOfClass("Model")
	if ancestorModel and CollectionService:HasTag(ancestorModel, "InteractiveVehicle") then
		triggerVehicleAlarm(ancestorModel)
	end
end

function PhantomMidway_ClientController.Init()
	initImpactPool()

	UserGameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(updatePostEffectsForQuality)
	updatePostEffectsForQuality()

	local ambientSound = SoundService:FindFirstChild("MidwayCoastalAmbience")
	if not ambientSound then
		local newSound = Instance.new("Sound")
		newSound.Name = "MidwayCoastalAmbience"
		newSound.SoundId = envAudio.MidwayCoastalAmbience or AssetRegistry.Audio.Movement.WindRushLoop
		newSound.Volume = 0.25
		newSound.Looped = true
		newSound.Parent = SoundService
		newSound:Play()
	end

	(_G :: any).OnPhantomMidwayRaycastHit = PhantomMidway_ClientController.OnWeaponRaycastHit
end

return PhantomMidway_ClientController
