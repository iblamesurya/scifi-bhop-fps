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
local OVERHEAD_CLEARANCE_RAY_LENGTH: number = 3.6
local JUMP_VELOCITY: number = MovementConfig.JumpVelocity or 42
local JUMP_GRACE_DURATION: number = 0.05
local GRAVITY: number = MovementConfig.Gravity or Workspace.Gravity
local GROUND_ACCELERATE: number = MovementConfig.GroundAccelerate or MovementConfig.Accelerate or 14
local AIR_ACCELERATE: number = MovementConfig.AirAccelerate or 120
local MAX_GROUND_SPEED: number = MovementConfig.MaxGroundSpeed or MovementConfig.WalkSpeed or 24
local MAX_AIR_WISH_SPEED: number = MovementConfig.MaxAirWishSpeed or 6.5
local GROUND_FRICTION: number = MovementConfig.GroundFriction or MovementConfig.Friction or 6
local SLIDE_FRICTION: number = MovementConfig.SlideFriction or 1.25
local STOP_SPEED: number = MovementConfig.StopSpeed or 10
local HARD_SPEED_CAP: number = MovementConfig.HardSpeedCap or 85

local STANCE_SYNC_INTERVAL: number = 0.05
local STANCE_STANDING: number = 0
local STANCE_AIRBORNE: number = 1
local STANCE_SLIDING: number = 2

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
local jumpGraceTimer = 0
local planarVelocity = Vector3.zero
local verticalVelocity = 0
local initialized = false

local stanceBuf = buffer.create(5)
local stanceSyncAccumulator = 0
local stanceRemote: UnreliableRemoteEvent? = nil

local cachedCharacter: Model? = nil
local defaultRootJointC0: CFrame? = nil
local defaultLeftHipC0: CFrame? = nil
local defaultRightHipC0: CFrame? = nil
local defaultRootCanCollide: boolean? = nil
local defaultLeftLegCanCollide: boolean? = nil
local defaultRightLegCanCollide: boolean? = nil

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function cacheCharacterRig(character: Model, rootPart: BasePart)
	if cachedCharacter == character then
		return
	end
	cachedCharacter = character

	local torso = (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")) :: BasePart?
	local rootJoint = (
		rootPart:FindFirstChild("RootJoint") or (torso and torso:FindFirstChild("RootJoint"))
	) :: Motor6D?
	local leftHip = (torso and torso:FindFirstChild("Left Hip")) :: Motor6D?
	local rightHip = (torso and torso:FindFirstChild("Right Hip")) :: Motor6D?
	local leftLeg = character:FindFirstChild("Left Leg") :: BasePart?
	local rightLeg = character:FindFirstChild("Right Leg") :: BasePart?

	defaultRootJointC0 = if rootJoint then rootJoint.C0 else nil
	defaultLeftHipC0 = if leftHip then leftHip.C0 else nil
	defaultRightHipC0 = if rightHip then rightHip.C0 else nil
	defaultRootCanCollide = rootPart.CanCollide
	defaultLeftLegCanCollide = if leftLeg then leftLeg.CanCollide else nil
	defaultRightLegCanCollide = if rightLeg then rightLeg.CanCollide else nil
end

local function updateSlideColliderAndRig(
	character: Model,
	rootPart: BasePart,
	isCrouched: boolean,
	cameraOffsetY: number
)
	cacheCharacterRig(character, rootPart)

	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")) :: BasePart?
	local leftLeg = character:FindFirstChild("Left Leg") :: BasePart?
	local rightLeg = character:FindFirstChild("Right Leg") :: BasePart?
	local rootJoint = (
		rootPart:FindFirstChild("RootJoint") or (torso and torso:FindFirstChild("RootJoint"))
	) :: Motor6D?
	local leftHip = (torso and torso:FindFirstChild("Left Hip")) :: Motor6D?
	local rightHip = (torso and torso:FindFirstChild("Right Hip")) :: Motor6D?

	if isCrouched then
		if head then
			head.CanCollide = false
		end
		if torso then
			torso.CanCollide = false
		end
		if leftLeg and rightLeg then
			rootPart.CanCollide = false
			leftLeg.CanCollide = true
			rightLeg.CanCollide = true
		end
	else
		if head then
			head.CanCollide = true
		end
		if torso then
			torso.CanCollide = true
		end
		if defaultRootCanCollide ~= nil then
			rootPart.CanCollide = defaultRootCanCollide
		end
		if leftLeg and defaultLeftLegCanCollide ~= nil then
			leftLeg.CanCollide = defaultLeftLegCanCollide
		end
		if rightLeg and defaultRightLegCanCollide ~= nil then
			rightLeg.CanCollide = defaultRightLegCanCollide
		end
	end

	if rootJoint and defaultRootJointC0 then
		rootJoint.C0 = CFrame.new(0, cameraOffsetY, 0) * defaultRootJointC0
	end
	if leftHip and defaultLeftHipC0 then
		leftHip.C0 = CFrame.new(0, -cameraOffsetY, 0) * defaultLeftHipC0
	end
	if rightHip and defaultRightHipC0 then
		rightHip.C0 = CFrame.new(0, -cameraOffsetY, 0) * defaultRightHipC0
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

	local existingRemote = ReplicatedStorage:FindFirstChild("StanceSyncBuffer")
	if existingRemote and existingRemote:IsA("UnreliableRemoteEvent") then
		stanceRemote = existingRemote
	else
		task.spawn(function()
			local waited = ReplicatedStorage:WaitForChild("StanceSyncBuffer")
			if waited and waited:IsA("UnreliableRemoteEvent") then
				stanceRemote = waited
			end
		end)
	end

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
		jumpGraceTimer = 0
		cachedCharacter = nil
		MovementController.CurrentPlanarSpeed = 0
		MovementController.IsGrounded = false
		MovementController.IsSliding = false
		MovementController.Velocity = Vector3.zero
		SlideController.Init()
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

		if jumpGraceTimer > 0 then
			jumpGraceTimer = math.max(0, jumpGraceTimer - dt)
		end

		raycastParams.FilterDescendantsInstances = { character }
		local groundHit = Workspace:Raycast(
			rootPart.Position,
			Vector3.new(0, -GROUND_RAY_LENGTH, 0),
			raycastParams
		)

		local isGrounded = false
		if jumpGraceTimer <= 0 then
			isGrounded = groundHit ~= nil and groundHit.Normal.Y >= 0.5 and verticalVelocity <= 0.01
		end

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
		-- immediately apply JumpVelocity, start the 0.05s grace window, and mark airborne
		-- so QuakeMath.ApplyFriction is bypassed.
		if isGrounded and jumpQueued then
			verticalVelocity = JUMP_VELOCITY
			jumpGraceTimer = JUMP_GRACE_DURATION
			isGrounded = false
		elseif isGrounded then
			verticalVelocity = 0
		end

		local wishDir = getWishDirection()

		if isGrounded then
			local activeFriction = if SlideController.IsSliding then SLIDE_FRICTION else GROUND_FRICTION
			planarVelocity = QuakeMath.ApplyFriction(planarVelocity, activeFriction, dt, STOP_SPEED)

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

		-- Check 3.6-stud upward clearance before allowing the character to uncrouch
		local overheadHit = Workspace:Raycast(
			rootPart.Position,
			Vector3.new(0, OVERHEAD_CLEARANCE_RAY_LENGTH, 0),
			raycastParams
		)
		local hasOverheadClearance = overheadHit == nil

		SlideController.Step(dt, isGrounded, currentSpeed, hasOverheadClearance)
		humanoid.CameraOffset = Vector3.new(0, SlideController.CurrentCameraOffsetY, 0)
		updateSlideColliderAndRig(
			character,
			rootPart,
			SlideController.IsCrouched,
			SlideController.CurrentCameraOffsetY
		)

		local finalVelocity = Vector3.new(planarVelocity.X, verticalVelocity, planarVelocity.Z)
		rootPart.AssemblyLinearVelocity = finalVelocity

		wasGrounded = isGrounded
		MovementController.CurrentPlanarSpeed = currentSpeed
		MovementController.IsGrounded = isGrounded
		MovementController.IsSliding = SlideController.IsSliding
		MovementController.Velocity = finalVelocity

		-- Replicate stance & camera look pitch at 20Hz (0.05s accumulator) using pre-allocated 5-byte buffer
		stanceSyncAccumulator += dt
		if stanceSyncAccumulator >= STANCE_SYNC_INTERVAL then
			stanceSyncAccumulator %= STANCE_SYNC_INTERVAL
			if stanceRemote then
				local camera = Workspace.CurrentCamera
				local pitch = if camera
					then math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
					else 0
				local stanceCode = if SlideController.IsSliding or SlideController.IsCrouched
					then STANCE_SLIDING
					elseif not isGrounded then STANCE_AIRBORNE
					else STANCE_STANDING

				buffer.writef32(stanceBuf, 0, pitch)
				buffer.writeu8(stanceBuf, 4, stanceCode)
				stanceRemote:FireServer(stanceBuf)
			end
		end
	end)
end

return MovementController
