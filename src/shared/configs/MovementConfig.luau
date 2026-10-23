--!strict
--[[
	MovementConfig.luau
	Read-only movement, bunny-hop, air-strafe, slide, and camera physics constants.
	Includes strict alias keys for MovementController and SlideController compatibility.
]]

export type MovementConfigType = {
	-- Ground Movement
	GroundWalkSpeed: number,
	MaxGroundSpeed: number,
	WalkSpeed: number,
	GroundSprintSpeed: number,
	GroundAcceleration: number,
	GroundAccelerate: number,
	Accelerate: number,
	GroundFriction: number,
	StopSpeed: number,

	-- Air Movement & Bunny-Hop
	AirWishSpeed: number,
	MaxAirWishSpeed: number,
	AirAcceleration: number,
	AirAccelerate: number,
	MaxPlanarSpeed: number,
	HardSpeedCap: number,
	JumpVelocity: number,
	Gravity: number,
	AutoBhopEnabled: boolean,
	JumpBufferWindow: number,
	CoyoteTimeWindow: number,

	-- Sliding
	SlideMinEntrySpeed: number,
	MinSlideSpeed: number,
	SlideImpulseBoost: number,
	SlideBoostImpulse: number,
	SlideFriction: number,
	SlideSteerAcceleration: number,
	SlideDuration: number,
	SlideCooldown: number,
	SlideCameraDropStuds: number,
	SlideCameraOffsetY: number,
	SlideCameraLerpSpeed: number,
	SlideColliderHeightScale: number,

	-- Ground Raycast & Collider
	StandingHipHeight: number,
	SlideHipHeight: number,
	GroundRayDistance: number,
	GroundRayLength: number,
	MaxSlopeAngle: number,

	-- Camera & Dynamic FOV
	BaseFOV: number,
	MaxSpeedFOV: number,
	FOVSpeedThreshold: number,
	FOVMaxSpeedReference: number,
	FOVLerpSpeed: number,
	StrafeTiltMaxDegrees: number,
	SlideTiltDegrees: number,
}

local MovementConfig: MovementConfigType = {
	-- Ground Movement
	GroundWalkSpeed = 24,
	MaxGroundSpeed = 24,
	WalkSpeed = 24,
	GroundSprintSpeed = 30,
	GroundAcceleration = 14,
	GroundAccelerate = 14,
	Accelerate = 14,
	GroundFriction = 6,
	StopSpeed = 10,

	-- Air Movement & Bunny-Hop
	AirWishSpeed = 6.5,
	MaxAirWishSpeed = 6.5,
	AirAcceleration = 120,
	AirAccelerate = 120,
	MaxPlanarSpeed = 85,
	HardSpeedCap = 85,
	JumpVelocity = 42,
	Gravity = 150,
	AutoBhopEnabled = true,
	JumpBufferWindow = 0.12,
	CoyoteTimeWindow = 0.08,

	-- Sliding
	SlideMinEntrySpeed = 26,
	MinSlideSpeed = 26,
	SlideImpulseBoost = 16,
	SlideBoostImpulse = 16,
	SlideFriction = 1.2,
	SlideSteerAcceleration = 35,
	SlideDuration = 1.15,
	SlideCooldown = 0.45,
	SlideCameraDropStuds = 2.2,
	SlideCameraOffsetY = -2.2,
	SlideCameraLerpSpeed = 14,
	SlideColliderHeightScale = 0.5,

	-- Ground Raycast & Collider
	StandingHipHeight = 2.0,
	SlideHipHeight = 0.8,
	GroundRayDistance = 3.4,
	GroundRayLength = 3.4,
	MaxSlopeAngle = 50,

	-- Camera & Dynamic FOV
	BaseFOV = 85,
	MaxSpeedFOV = 103,
	FOVSpeedThreshold = 28,
	FOVMaxSpeedReference = 85,
	FOVLerpSpeed = 12,
	StrafeTiltMaxDegrees = 3.5,
	SlideTiltDegrees = 6.0,
}

return table.freeze(MovementConfig)
