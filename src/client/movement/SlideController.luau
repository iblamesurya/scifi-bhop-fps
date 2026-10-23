--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.configs.MovementConfig)

local MIN_SLIDE_SPEED: number = MovementConfig.MinSlideSpeed or 22
local SLIDE_BOOST_IMPULSE: number = MovementConfig.SlideBoostImpulse or 14
local SLIDE_CAMERA_OFFSET_Y: number = MovementConfig.SlideCameraOffsetY or -2.2
local CAMERA_LERP_SPEED: number = MovementConfig.SlideCameraLerpSpeed or 14
local HARD_SPEED_CAP: number = MovementConfig.HardSpeedCap or 85

local SlideController = {
	IsSliding = false,
	CurrentCameraOffsetY = 0,
}

function SlideController.Init()
	SlideController.IsSliding = false
	SlideController.CurrentCameraOffsetY = 0
end

function SlideController.TryStartSlide(planarVelocity: Vector3, isGrounded: boolean): Vector3
	local flatVelocity = Vector3.new(planarVelocity.X, 0, planarVelocity.Z)
	local speed = flatVelocity.Magnitude

	if not isGrounded or speed < MIN_SLIDE_SPEED then
		return flatVelocity
	end

	SlideController.IsSliding = true

	local boostDir = if speed > 1e-4 then flatVelocity.Unit else Vector3.zero
	local boostedVelocity = flatVelocity + (boostDir * SLIDE_BOOST_IMPULSE)

	if boostedVelocity.Magnitude > HARD_SPEED_CAP then
		boostedVelocity = boostedVelocity.Unit * HARD_SPEED_CAP
	end

	return boostedVelocity
end

function SlideController.StopSlide()
	SlideController.IsSliding = false
end

function SlideController.Step(dt: number, isGrounded: boolean, planarSpeed: number)
	if SlideController.IsSliding then
		if planarSpeed < (MIN_SLIDE_SPEED * 0.6) then
			SlideController.IsSliding = false
		end
	end

	local targetOffsetY = if SlideController.IsSliding and isGrounded
			or SlideController.IsSliding
		then SLIDE_CAMERA_OFFSET_Y
		else 0

	local alpha = math.clamp(1 - math.exp(-CAMERA_LERP_SPEED * dt), 0, 1)
	SlideController.CurrentCameraOffsetY += (targetOffsetY - SlideController.CurrentCameraOffsetY) * alpha
end

return SlideController
