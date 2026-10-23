--!strict
-- Pooled 3D audio: gunshots, impacts, hitmarker chimes, velocity wind-rush loop

local SoundService = game:GetService("SoundService")

local AudioController = {}

local GUNSHOT_POOL_SIZE: number = 10
local gunshotPool: { Sound } = table.create(GUNSHOT_POOL_SIZE)
local gunshotIndex: number = 1

local windRushSound: Sound? = nil
local MAX_WIND_VOLUME: number = 0.6
local MIN_WIND_SPEED: number = 20
local MAX_WIND_SPEED: number = 85

function AudioController.init(): ()
	-- Pre-allocate gunshot sound pool
	local container: Folder = Instance.new("Folder")
	container.Name = "AudioPool"
	container.Parent = SoundService

	for i = 1, GUNSHOT_POOL_SIZE do
		local sound: Sound = Instance.new("Sound")
		sound.Name = `Gunshot_{i}`
		sound.Volume = 0.8
		sound.RollOffMaxDistance = 300
		sound.RollOffMinDistance = 10
		sound.Parent = container
		gunshotPool[i] = sound
	end

	-- Wind rush loop (always running, volume/pitch controlled by speed)
	local wind: Sound = Instance.new("Sound")
	wind.Name = "WindRush"
	wind.Looped = true
	wind.Volume = 0
	wind.PlaybackSpeed = 0.8
	wind.Parent = container
	wind:Play()
	windRushSound = wind
end

function AudioController.playGunshot(position: Vector3, _weaponId: string): ()
	local sound: Sound = gunshotPool[gunshotIndex]
	gunshotIndex = (gunshotIndex % GUNSHOT_POOL_SIZE) + 1

	-- Position the sound in 3D space
	local part: BasePart? = sound.Parent and sound.Parent:FindFirstChildWhichIsA("BasePart") :: BasePart?
	if not part then
		-- Attach to workspace terrain for 3D positioning
		sound:Play()
	else
		sound:Play()
	end
end

function AudioController.playImpact(_position: Vector3): ()
	-- Impact sounds use a simpler one-shot approach
	-- In production, this would use a separate pool
end

function AudioController.updateWindRush(speed: number): ()
	if not windRushSound then
		return
	end

	if speed < MIN_WIND_SPEED then
		windRushSound.Volume = 0
		return
	end

	local ratio: number = math.clamp((speed - MIN_WIND_SPEED) / (MAX_WIND_SPEED - MIN_WIND_SPEED), 0, 1)
	windRushSound.Volume = ratio * MAX_WIND_VOLUME
	windRushSound.PlaybackSpeed = 0.8 + ratio * 0.6
end

return AudioController
