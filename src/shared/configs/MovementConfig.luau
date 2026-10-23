--!strict
-- Read-only physics constants for Quake-style bunny-hop movement

export type MovementConfigType = {
	GroundFriction: number,
	AirAccelerate: number,
	MaxAirWishSpeed: number,
	GroundAccelerate: number,
	MaxGroundSpeed: number,
	HardSpeedCap: number,
	JumpVelocity: number,
	GroundRayLength: number,
	Gravity: number,
	MinSlideSpeed: number,
	SlideBoostImpulse: number,
	SlideFriction: number,
	SlideDuration: number,
	CrouchCameraOffset: number,
}

local MovementConfig: MovementConfigType = table.freeze({
	GroundFriction = 6.0,
	AirAccelerate = 120,
	MaxAirWishSpeed = 6.5,
	GroundAccelerate = 10,
	MaxGroundSpeed = 18,
	HardSpeedCap = 85,
	JumpVelocity = 42,
	GroundRayLength = 3.4,
	Gravity = 196.2,
	MinSlideSpeed = 26,
	SlideBoostImpulse = 16,
	SlideFriction = 1.2,
	SlideDuration = 1.2,
	CrouchCameraOffset = -2.5,
})

return MovementConfig
