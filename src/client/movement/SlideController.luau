--!strict
-- Slide impulse, low-friction decay, camera crouch offset

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local MovementConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").configs.MovementConfig)
local QuakeMath = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").math.QuakeMath)

local SlideController = {}

local localPlayer: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera

local isSliding: boolean = false
local slideTimer: number = 0
local cameraOffsetAlpha: number = 0

-- Public state
SlideController.IsSliding = false
SlideController.OnSlideStart = {} :: { () -> () }
SlideController.OnSlideEnd = {} :: { () -> () }

function SlideController.init(getIsGrounded: () -> boolean, getPlanarSpeed: () -> number): ()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean): ()
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
			if getIsGrounded() and getPlanarSpeed() > MovementConfig.MinSlideSpeed and not isSliding then
				SlideController.beginSlide()
			end
		end
	end)
end

function SlideController.beginSlide(): ()
	isSliding = true
	slideTimer = MovementConfig.SlideDuration
	SlideController.IsSliding = true

	-- Apply slide boost impulse
	local character: Model? = localPlayer.Character
	if character then
		local hrp: BasePart? = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local lookDir: Vector3 = camera.CFrame.LookVector
			local flatDir: Vector3 = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
			hrp.AssemblyLinearVelocity += flatDir * MovementConfig.SlideBoostImpulse
		end
	end

	for _, callback in SlideController.OnSlideStart do
		task.spawn(callback)
	end
end

function SlideController.endSlide(): ()
	isSliding = false
	SlideController.IsSliding = false

	for _, callback in SlideController.OnSlideEnd do
		task.spawn(callback)
	end
end

function SlideController.update(dt: number, getIsGrounded: () -> boolean, getPlanarSpeed: () -> number): number
	if isSliding then
		slideTimer -= dt

		-- Apply slide friction (lower than ground)
		local character: Model? = localPlayer.Character
		if character then
			local hrp: BasePart? = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local vel: Vector3 = hrp.AssemblyLinearVelocity
				vel = QuakeMath.applyFriction(vel, MovementConfig.SlideFriction, dt)
				hrp.AssemblyLinearVelocity = Vector3.new(vel.X, hrp.AssemblyLinearVelocity.Y, vel.Z)
			end
		end

		-- End conditions
		if slideTimer <= 0 or not getIsGrounded() or getPlanarSpeed() < 8 then
			SlideController.endSlide()
		end
	end

	-- Lerp camera crouch offset
	local targetAlpha: number = if isSliding then 1 else 0
	cameraOffsetAlpha += (targetAlpha - cameraOffsetAlpha) * math.min(dt * 12, 1)

	return MovementConfig.CrouchCameraOffset * cameraOffsetAlpha
end

return SlideController
