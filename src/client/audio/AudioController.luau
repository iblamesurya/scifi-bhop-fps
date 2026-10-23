--!strict
--[[
	AudioController.luau
	Procedural velocity audio controller and pooled weapon/UI sound dispatcher.
	Modulates a continuous wind-rush loop volume and PlaybackSpeed proportional to
	MovementController.CurrentPlanarSpeed when B-hopping above 35 studs/s, and triggers
	landing thuds via MovementController.OnLandedCallbacks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local SharedConfigs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("configs")
local AssetRegistry = require(SharedConfigs:WaitForChild("AssetRegistry"))
local MovementController = require(script.Parent.Parent:WaitForChild("movement"):WaitForChild("MovementController"))

local WEAPON_SOUND_POOL_SIZE = 12
local UI_SOUND_POOL_SIZE = 8
local MOVEMENT_SOUND_POOL_SIZE = 4

local WIND_RUSH_SPEED_THRESHOLD = 35
local WIND_RUSH_MAX_SPEED = 95
local WIND_MAX_VOLUME = 0.65
local WIND_MIN_PLAYBACK_SPEED = 0.85
local WIND_MAX_PLAYBACK_SPEED = 1.45
local WIND_LERP_SPEED = 10

local initialized = false
local weaponSoundPool: { Sound } = table.create(WEAPON_SOUND_POOL_SIZE)
local weaponPoolCursor = 0

local uiSoundPool: { Sound } = table.create(UI_SOUND_POOL_SIZE)
local uiPoolCursor = 0

local movementSoundPool: { Sound } = table.create(MOVEMENT_SOUND_POOL_SIZE)
local movementPoolCursor = 0

local windRushSound: Sound? = nil
local renderConnection: RBXScriptConnection? = nil
local rng = Random.new()

local AudioController = {}

local function getOrCreateSoundGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = 1
	group.Parent = SoundService
	return group
end

local function ensurePoolsInitialized(): ()
	if #weaponSoundPool > 0 then
		return
	end

	local weaponGroup = getOrCreateSoundGroup("WeaponsAudioGroup")
	local uiGroup = getOrCreateSoundGroup("UIAudioGroup")
	local movementGroup = getOrCreateSoundGroup("MovementAudioGroup")

	for i = 1, WEAPON_SOUND_POOL_SIZE do
		local sound = Instance.new("Sound")
		sound.Name = string.format("PooledWeaponSound_%02d", i)
		sound.Volume = 0.55
		sound.SoundGroup = weaponGroup
		sound.Parent = weaponGroup
		weaponSoundPool[i] = sound
	end

	for i = 1, UI_SOUND_POOL_SIZE do
		local sound = Instance.new("Sound")
		sound.Name = string.format("PooledUISound_%02d", i)
		sound.Volume = 0.6
		sound.SoundGroup = uiGroup
		sound.Parent = uiGroup
		uiSoundPool[i] = sound
	end

	for i = 1, MOVEMENT_SOUND_POOL_SIZE do
		local sound = Instance.new("Sound")
		sound.Name = string.format("PooledMovementSound_%02d", i)
		sound.Volume = 0.45
		sound.SoundGroup = movementGroup
		sound.Parent = movementGroup
		movementSoundPool[i] = sound
	end

	local wind = Instance.new("Sound")
	wind.Name = "BhopWindRushLoop"
	wind.SoundId = AssetRegistry.Audio.Movement.WindRushLoop
	wind.Looped = true
	wind.Volume = 0
	wind.PlaybackSpeed = WIND_MIN_PLAYBACK_SPEED
	wind.SoundGroup = movementGroup
	wind.Parent = movementGroup
	wind:Play()
	windRushSound = wind
end

local function resolveWeaponSoundId(soundKey: string): string?
	local weaponsTable = AssetRegistry.Audio.Weapons :: { [string]: string }
	if weaponsTable[soundKey] then
		return weaponsTable[soundKey]
	end
	if string.sub(soundKey, 1, 13) == "rbxassetid://" then
		return soundKey
	end
	return weaponsTable.PulseRifleFire
end

local function resolveUISoundId(soundKey: string): string?
	local uiTable = AssetRegistry.Audio.UI :: { [string]: string }
	if uiTable[soundKey] then
		return uiTable[soundKey]
	end
	if string.sub(soundKey, 1, 13) == "rbxassetid://" then
		return soundKey
	end
	return uiTable.HitmarkerBody
end

local function getCurrentPlanarSpeed(): number
	local movementAny = MovementController :: any
	if type(movementAny.CurrentPlanarSpeed) == "number" then
		return movementAny.CurrentPlanarSpeed
	end
	if type(movementAny.GetPlanarSpeed) == "function" then
		local ok, speed = pcall(movementAny.GetPlanarSpeed, movementAny)
		if ok and type(speed) == "number" then
			return speed
		end
	end
	return 0
end

local function playLandingThud(impactVelocity: number?): ()
	ensurePoolsInitialized()

	movementPoolCursor = (movementPoolCursor % MOVEMENT_SOUND_POOL_SIZE) + 1
	local sound = movementSoundPool[movementPoolCursor]
	sound.SoundId = AssetRegistry.Audio.Movement.BhopLand

	local planarSpeed = getCurrentPlanarSpeed()
	local effectiveSpeed = math.max(planarSpeed, math.abs(impactVelocity or 0))
	local speedFactor = math.clamp(effectiveSpeed / WIND_RUSH_MAX_SPEED, 0, 1)

	sound.Volume = 0.3 + (0.4 * speedFactor)
	sound.PlaybackSpeed = 0.9 + (0.22 * speedFactor) + rng:NextNumber(-0.03, 0.03)
	sound.TimePosition = 0
	sound:Play()
end

local function updateWindRushAudio(dt: number): ()
	local wind = windRushSound
	if not wind then
		return
	end

	local planarSpeed = getCurrentPlanarSpeed()
	local targetVolume = 0
	local targetPitch = WIND_MIN_PLAYBACK_SPEED

	if planarSpeed > WIND_RUSH_SPEED_THRESHOLD then
		local speedSpan = math.max(WIND_RUSH_MAX_SPEED - WIND_RUSH_SPEED_THRESHOLD, 1)
		local alpha = math.clamp((planarSpeed - WIND_RUSH_SPEED_THRESHOLD) / speedSpan, 0, 1)
		targetVolume = WIND_MAX_VOLUME * alpha
		targetPitch = WIND_MIN_PLAYBACK_SPEED + (WIND_MAX_PLAYBACK_SPEED - WIND_MIN_PLAYBACK_SPEED) * alpha
	end

	local step = 1 - math.exp(-WIND_LERP_SPEED * math.min(dt, 0.1))
	wind.Volume = wind.Volume + (targetVolume - wind.Volume) * step
	wind.PlaybackSpeed = wind.PlaybackSpeed + (targetPitch - wind.PlaybackSpeed) * step

	if not wind.IsPlaying then
		wind:Play()
	end
end

function AudioController.PlayWeaponSound(soundKey: string): ()
	ensurePoolsInitialized()

	local soundId = resolveWeaponSoundId(soundKey)
	if not soundId or soundId == "" or soundId == "rbxassetid://0" then
		return
	end

	weaponPoolCursor = (weaponPoolCursor % WEAPON_SOUND_POOL_SIZE) + 1
	local sound = weaponSoundPool[weaponPoolCursor]
	sound.SoundId = soundId
	sound.PlaybackSpeed = rng:NextNumber(0.97, 1.03)
	sound.TimePosition = 0
	sound:Play()
end

function AudioController.PlayUISound(soundKey: string): ()
	ensurePoolsInitialized()

	local soundId = resolveUISoundId(soundKey)
	if not soundId or soundId == "" or soundId == "rbxassetid://0" then
		return
	end

	uiPoolCursor = (uiPoolCursor % UI_SOUND_POOL_SIZE) + 1
	local sound = uiSoundPool[uiPoolCursor]
	sound.SoundId = soundId
	sound.PlaybackSpeed = 1
	sound.TimePosition = 0
	sound:Play()
end

function AudioController.Init(): ()
	if initialized then
		return
	end
	initialized = true

	ensurePoolsInitialized()

	local movementAny = MovementController :: any
	if type(movementAny.OnLandedCallbacks) == "table" then
		table.insert(movementAny.OnLandedCallbacks, playLandingThud)
	elseif type(movementAny.OnLanded) == "table" and type(movementAny.OnLanded.Connect) == "function" then
		movementAny.OnLanded:Connect(playLandingThud)
	end

	if renderConnection then
		renderConnection:Disconnect()
	end
	renderConnection = RunService.RenderStepped:Connect(updateWindRushAudio)
end

return table.freeze(AudioController)
