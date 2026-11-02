---
tags: [system, movement]
---
# Movement
Code: `src/client/movement/MovementController.luau`, `SlideController.luau`; math in `src/shared/math/QuakeMath.luau`; constants in `src/shared/configs/MovementConfig.luau`.

- **State machine bypass**: `Humanoid.EvaluateStateMachine = false`; velocity driven directly on `HumanoidRootPart.AssemblyLinearVelocity`. Server side, `CharacterService` zeroes WalkSpeed/JumpPower and disables AutoRotate.
- **Ground detection**: downward ray, `GroundRayLength` = 3.4 studs.
- **Auto-bhop**: hold Space → `jumpQueued`; on landing frame set vertical velocity to `JumpVelocity` (42) and skip `applyFriction()`.
- **Air accel**: `MaxAirWishSpeed` 6.5, `AirAccelerate` 120, `HardSpeedCap` 85 studs/s.
- **Slide**: LeftCtrl / C above `MinSlideSpeed` 26 → `SlideBoostImpulse` 16, friction 6.0 → 1.2.
- Speed feeds HUD telemetry & FOV warp (85 → 103) — see [[Viewmodel]] and `GraphicsController`.
- Overdrive threshold: 45 studs/s (cyan → orange).

Related: [[Combat & Networking]] (origin tolerance of 14 studs exists because of this speed).
