--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.configs.MovementConfig)
local QuakeMath = require(ReplicatedStorage.Shared.math.QuakeMath)
local SlideController = require(script.Parent.SlideController)

local GROUND_RAY_LENGTH: number = MovementConfig.GroundRayLength or 3.4
local JUMP_VELOCITY: number = MovementConfig.JumpVelocity or 42
local GRAVITY: number = MovementConfig.Gravity or Workspace.Gravity
local GROUND_ACCELERATE: number = MovementConfig.GroundAccelerate or MovementConfig.Accelerate or 14
local AIR_ACCELERATE: number = MovementConfig.AirAccelerate or 120
local MAX_GROUND_SPEED: number = MovementConfig.MaxGroundSpeed or MovementConfig.WalkSpeed or 24
local MAX_AIR_WISH_SPEED: number = MovementConfig.MaxAirWishSpeed or 6.5
local GROUND_FRICTION: number = MovementConfig.GroundFriction or MovementConfig.Friction or 6
local SLIDE_FRICTION: number = MovementConfig.SlideFriction or 1.25
local STOP_SPEED: number = MovementConfig.StopSpeed or 10
local HARD_SPEED_CAP: number = MovementConfig.HardSpeedCap or 85

local localPlayer = Players.LocalPlayer

local MovementController = {
	CurrentPlanarSpeed = 0,
	IsGrounded = false,
	IsSliding = false,
	Velocity = Vector3.zero,
	OnLandedCallbacks = {} :: { (impactVelocityY: number) -> () },
}

local jumpQueued = false
local slideQueued = false
local wasGrounded = false
local planarVelocity = Vector3.zero
local verticalVelocity = 0
local initialized = false

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local frictionArity = select(1, debug.info(QuakeMath.ApplyFriction, "a"))

local function applyFriction(velocity: Vector3, friction: number, dt: number): Vector3
	if frictionArity >= 4 then
		return (QuakeMath.ApplyFriction :: any)(velocity, friction, STOP_SPEED, dt)
	elseif frictionArity == 3 then
		return (QuakeMath.ApplyFriction :: any)(velocity, friction, dt)
	else
		return (QuakeMath.ApplyFriction :: any)(velocity, dt)
	end
end

local function getWishDirection(): Vector3
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.zero
	end

	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)

	if forward.Magnitude > 1e-4 then
		forward = forward.Unit
	end
	if right.Magnitude > 1e-4 then
		right = right.Unit
	end

	local moveInput = Vector3.zero
	if UserInputService:GetFocusedTextBox() == nil then
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			moveInput += forward
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			moveInput -= forward
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moveInput += right
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			moveInput -= right
		end
	end

	if moveInput.Magnitude > 1e-4 then
		return moveInput.Unit
	end

	return Vector3.zero
end

local function isSlideKey(keyCode: Enum.KeyCode): boolean
	return keyCode == Enum.KeyCode.LeftControl or keyCode == Enum.KeyCode.C
end

function MovementController.Init()
	if initialized then
		return
	end
	initialized = true

	SlideController.Init()

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.Space then
			jumpQueued = true
		elseif isSlideKey(input.KeyCode) then
			slideQueued = true
			if MovementController.IsGrounded and not SlideController.IsSliding then
				planarVelocity = SlideController.TryStartSlide(planarVelocity, true)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Space then
			jumpQueued = false
		elseif isSlideKey(input.KeyCode) then
			slideQueued = false
			SlideController.StopSlide()
		end
	end)

	localPlayer.CharacterAdded:Connect(function()
		planarVelocity = Vector3.zero
		verticalVelocity = 0
		wasGrounded = false
		MovementController.CurrentPlanarSpeed = 0
		MovementController.IsGrounded = false
		MovementController.IsSliding = false
		MovementController.Velocity = Vector3.zero
		SlideController.StopSlide()
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local character = localPlayer.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not rootPart or humanoid.Health <= 0 then
			return
		end

		humanoid.EvaluateStateMachine = false

		if UserInputService:GetFocusedTextBox() == nil then
			jumpQueued = UserInputService:IsKeyDown(Enum.KeyCode.Space)
		end

		raycastParams.FilterDescendantsInstances = { character }
		local groundHit = Workspace:Raycast(
			rootPart.Position,
			Vector3.new(0, -GROUND_RAY_LENGTH, 0),
			raycastParams
		)

		local isGrounded = groundHit ~= nil and groundHit.Normal.Y >= 0.5 and verticalVelocity <= 0.01
		local landedThisFrame = isGrounded and not wasGrounded

		if landedThisFrame then
			local impactVelocityY = math.abs(verticalVelocity)
			for _, callback in MovementController.OnLandedCallbacks do
				task.spawn(callback, impactVelocityY)
			end

			if slideQueued and not SlideController.IsSliding then
				planarVelocity = SlideController.TryStartSlide(planarVelocity, true)
			end
		end

		-- Auto-Bhop: on landing frame (or while grounded), if jumpQueued is true,
		-- immediately apply JumpVelocity and mark airborne so ApplyFriction is bypassed.
		if isGrounded and jumpQueued then
			verticalVelocity = JUMP_VELOCITY
			isGrounded = false
		elseif isGrounded then
			verticalVelocity = 0
		end

		local wishDir = getWishDirection()

		if isGrounded then
			local activeFriction = if SlideController.IsSliding then SLIDE_FRICTION else GROUND_FRICTION
			planarVelocity = applyFriction(planarVelocity, activeFriction, dt)

			if not SlideController.IsSliding then
				planarVelocity = QuakeMath.Accelerate(
					planarVelocity,
					wishDir,
					MAX_GROUND_SPEED,
					GROUND_ACCELERATE,
					dt
				)
			end
		else
			planarVelocity = QuakeMath.Accelerate(
				planarVelocity,
				wishDir,
				MAX_AIR_WISH_SPEED,
				AIR_ACCELERATE,
				dt
			)
			verticalVelocity -= GRAVITY * dt
		end

		local currentSpeed = planarVelocity.Magnitude
		if currentSpeed > HARD_SPEED_CAP then
			planarVelocity = planarVelocity.Unit * HARD_SPEED_CAP
			currentSpeed = HARD_SPEED_CAP
		end

		SlideController.Step(dt, isGrounded, currentSpeed)
		humanoid.CameraOffset = Vector3.new(0, SlideController.CurrentCameraOffsetY, 0)

		local finalVelocity = Vector3.new(planarVelocity.X, verticalVelocity, planarVelocity.Z)
		rootPart.AssemblyLinearVelocity = finalVelocity

		wasGrounded = isGrounded
		MovementController.CurrentPlanarSpeed = currentSpeed
		MovementController.IsGrounded = isGrounded
		MovementController.IsSliding = SlideController.IsSliding
		MovementController.Velocity = finalVelocity
	end)
end

return MovementController
