--!strict
--[[
	MovementConfig.luau
	Read-only movement, bunny-hop, air-strafe, slide, and camera physics constants.
]]

export type MovementConfigType = {
	-- Ground Movement
	GroundWalkSpeed: number,
	GroundSprintSpeed: number,
	GroundAcceleration: number,
	GroundFriction: number,
	StopSpeed: number,

	-- Air Movement & Bunny-Hop
	AirWishSpeed: number,
	AirAcceleration: number,
	MaxPlanarSpeed: number,
	JumpVelocity: number,
	Gravity: number,
	AutoBhopEnabled: boolean,
	JumpBufferWindow: number,
	CoyoteTimeWindow: number,

	-- Sliding
	SlideMinEntrySpeed: number,
	SlideImpulseBoost: number,
	SlideFriction: number,
	SlideSteerAcceleration: number,
	SlideDuration: number,
	SlideCooldown: number,
	SlideCameraDropStuds: number,
	SlideColliderHeightScale: number,

	-- Ground Raycast & Collider
	StandingHipHeight: number,
	SlideHipHeight: number,
	GroundRayDistance: number,
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
	GroundSprintSpeed = 30,
	GroundAcceleration = 14,
	GroundFriction = 6,
	StopSpeed = 10,

	-- Air Movement & Bunny-Hop
	AirWishSpeed = 16,
	AirAcceleration = 120,
	MaxPlanarSpeed = 95,
	JumpVelocity = 52,
	Gravity = 150,
	AutoBhopEnabled = true,
	JumpBufferWindow = 0.12,
	CoyoteTimeWindow = 0.08,

	-- Sliding
	SlideMinEntrySpeed = 22,
	SlideImpulseBoost = 18,
	SlideFriction = 1.6,
	SlideSteerAcceleration = 35,
	SlideDuration = 1.15,
	SlideCooldown = 0.45,
	SlideCameraDropStuds = 2.2,
	SlideColliderHeightScale = 0.5,

	-- Ground Raycast & Collider
	StandingHipHeight = 2.0,
	SlideHipHeight = 0.8,
	GroundRayDistance = 3.4,
	MaxSlopeAngle = 50,

	-- Camera & Dynamic FOV
	BaseFOV = 90,
	MaxSpeedFOV = 112,
	FOVSpeedThreshold = 28,
	FOVMaxSpeedReference = 85,
	FOVLerpSpeed = 12,
	StrafeTiltMaxDegrees = 3.5,
	SlideTiltDegrees = 6.0,
}

return table.freeze(MovementConfig)
