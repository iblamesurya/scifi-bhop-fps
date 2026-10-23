--!strict
-- Quake air-strafe, auto-bhop, and ground friction math

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local MovementConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").configs.MovementConfig)
local QuakeMath = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").math.QuakeMath)

local MovementController = {}

local localPlayer: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera

local isGrounded: boolean = false
local jumpQueued: boolean = false
local currentPlanarSpeed: number = 0
local wasGrounded: boolean = false

-- Public state
MovementController.IsGrounded = false
MovementController.CurrentPlanarSpeed = 0
MovementController.OnLandedCallbacks = {} :: { (verticalSpeed: number) -> () }

local rayParams: RaycastParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getWishDir(): Vector3
	local moveDir: Vector3 = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveDir += Vector3.new(0, 0, -1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveDir += Vector3.new(0, 0, 1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveDir += Vector3.new(-1, 0, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveDir += Vector3.new(1, 0, 0)
	end
	if moveDir.Magnitude < 0.01 then
		return Vector3.zero
	end
	-- Transform to camera-relative world space (XZ only)
	local camCF: CFrame = camera.CFrame
	local flat: CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit)
	return (flat * CFrame.new(moveDir.Unit)).Position.Unit
end

function MovementController.init(): ()
	-- Track jump input
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean): ()
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			jumpQueued = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, _processed: boolean): ()
		if input.KeyCode == Enum.KeyCode.Space then
			jumpQueued = false
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number): ()
		MovementController.update(dt)
	end)
end

function MovementController.update(dt: number): ()
	local character: Model? = localPlayer.Character
	if not character then
		return
	end

	local hrp: BasePart? = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid: Humanoid? = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return
	end

	-- Disable default state machine every frame
	humanoid.EvaluateStateMachine = false

	-- Update raycast filter
	rayParams.FilterDescendantsInstances = { character }

	-- Ground detection
	local rayOrigin: Vector3 = hrp.Position
	local rayDir: Vector3 = Vector3.new(0, -MovementConfig.GroundRayLength, 0)
	local rayResult: RaycastResult? = workspace:Raycast(rayOrigin, rayDir, rayParams)

	wasGrounded = isGrounded
	isGrounded = rayResult ~= nil

	local velocity: Vector3 = hrp.AssemblyLinearVelocity
	local wishDir: Vector3 = getWishDir()

	-- Frame-perfect auto-bhop: on landing frame with jump queued, instantly jump
	if isGrounded and jumpQueued then
		velocity = Vector3.new(velocity.X, MovementConfig.JumpVelocity, velocity.Z)
		isGrounded = false
		-- Skip friction on landing frame
	elseif isGrounded then
		-- Ground movement with friction
		velocity = QuakeMath.applyFriction(velocity, MovementConfig.GroundFriction, dt)
		if wishDir.Magnitude > 0.01 then
			velocity = QuakeMath.accelerate(velocity, wishDir, MovementConfig.MaxGroundSpeed, MovementConfig.GroundAccelerate, dt)
		end
	else
		-- Air movement: Quake air-strafe acceleration
		if wishDir.Magnitude > 0.01 then
			velocity = QuakeMath.accelerate(velocity, wishDir, MovementConfig.MaxAirWishSpeed, MovementConfig.AirAccelerate, dt)
		end
	end

	-- Hard speed cap
	velocity = QuakeMath.clampHorizontalSpeed(velocity, MovementConfig.HardSpeedCap)

	-- Apply velocity
	hrp.AssemblyLinearVelocity = velocity

	-- Face camera direction on XZ plane
	local lookDir: Vector3 = camera.CFrame.LookVector
	local flatLook: Vector3 = Vector3.new(lookDir.X, 0, lookDir.Z)
	if flatLook.Magnitude > 0.01 then
		hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatLook)
	end

	-- Update public state
	currentPlanarSpeed = QuakeMath.getHorizontalSpeed(velocity)
	MovementController.IsGrounded = isGrounded
	MovementController.CurrentPlanarSpeed = currentPlanarSpeed

	-- Fire landed callbacks
	if isGrounded and not wasGrounded then
		local verticalSpeed: number = math.abs(velocity.Y)
		for _, callback in MovementController.OnLandedCallbacks do
			task.spawn(callback, verticalSpeed)
		end
	end
end

return MovementController
