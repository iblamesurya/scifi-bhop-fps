--!strict
-- Client bootstrapper: initializes all client-side systems

local RunService = game:GetService("RunService")

local MovementController = require(script.movement.MovementController)
local SlideController = require(script.movement.SlideController)
local WeaponController = require(script.combat.WeaponController)
local TracerPool = require(script.combat.TracerPool)
local ViewmodelController = require(script.viewmodel.ViewmodelController)
local AnimatorBridge = require(script.viewmodel.AnimatorBridge)
local GraphicsController = require(script.graphics.GraphicsController)
local VFXController = require(script.graphics.VFXController)
local AudioController = require(script.audio.AudioController)
local HudApp = require(script.ui.HudApp)
local CrosshairModule = require(script.ui.CrosshairModule)

-- Initialize all systems
GraphicsController.init()
MovementController.init()
SlideController.init(
	function(): boolean return MovementController.IsGrounded end,
	function(): number return MovementController.CurrentPlanarSpeed end
)
WeaponController.init()
TracerPool.init()
ViewmodelController.init()
VFXController.init()
AudioController.init()
HudApp.init()
CrosshairModule.init()

-- Wire viewmodel landing spring to movement system
table.insert(MovementController.OnLandedCallbacks, function(verticalSpeed: number): ()
	ViewmodelController.onLanded(verticalSpeed)
end)

-- Wire weapon fire callbacks to VFX, tracer, and audio
table.insert(WeaponController.OnFired, function(origin: Vector3, direction: Vector3, hitResult: RaycastResult?): ()
	local target: Vector3 = if hitResult then hitResult.Position else origin + direction
	TracerPool.fire(origin, target, 800)
	AudioController.playGunshot(origin, "pulse_rifle")

	if hitResult then
		VFXController.playImpactSparks(hitResult.Position, hitResult.Normal)
		AudioController.playImpact(hitResult.Position)
	end
end)

-- Per-frame update loop
RunService.Heartbeat:Connect(function(dt: number): ()
	local speed: number = MovementController.CurrentPlanarSpeed
	local slideOffset: number = SlideController.update(
		dt,
		function(): boolean return MovementController.IsGrounded end,
		function(): number return speed end
	)

	WeaponController.update(dt)
	GraphicsController.updateFOV(speed, dt)
	AudioController.updateWindRush(speed)
	HudApp.update(speed, WeaponController.CurrentAmmo, 100, 100)
	CrosshairModule.update(speed, WeaponController.IsFiring, WeaponController.IsADS)
end)

print("[Client] SciFi B-Hop FPS client initialized")
