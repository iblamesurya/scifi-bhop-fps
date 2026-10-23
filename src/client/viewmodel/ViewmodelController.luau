--!strict
-- RenderStepped camera bind, AimPart ADS lerp, 3D Springs

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Spring = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").math.Spring)

local ViewmodelController = {}

local camera: Camera = workspace.CurrentCamera
local activeViewmodel: Model? = nil
local aimPart: BasePart? = nil

-- 3D Springs
local swaySpring = Spring.new(120, 14)
local recoilSpring = Spring.new(200, 18)
local movementSpring = Spring.new(80, 10)

local adsAlpha: number = 0
local strafeTilt: number = 0

local ADS_LERP_SPEED: number = 12
local SWAY_SCALE: number = 0.08
local STRAFE_TILT_ANGLE: number = math.rad(4.5)
local SLIDE_TILT_ANGLE: number = math.rad(-8)
local RENDER_PRIORITY: number = Enum.RenderPriority.Camera.Value + 1

function ViewmodelController.init(): ()
	RunService:BindToRenderStep("ViewmodelUpdate", RENDER_PRIORITY, function(dt: number): ()
		ViewmodelController.update(dt)
	end)
end

function ViewmodelController.setViewmodel(viewmodel: Model): ()
	activeViewmodel = viewmodel
	aimPart = viewmodel:FindFirstChild("AimPart", true) :: BasePart?
	viewmodel.Parent = camera
end

function ViewmodelController.clearViewmodel(): ()
	if activeViewmodel then
		activeViewmodel:Destroy()
		activeViewmodel = nil
		aimPart = nil
	end
end

function ViewmodelController.applyRecoilKick(kick: Vector3): ()
	recoilSpring:Impulse(kick)
end

function ViewmodelController.onLanded(verticalSpeed: number): ()
	local landImpulse: number = math.clamp(verticalSpeed / 60, 0, 1.5)
	movementSpring:Impulse(Vector3.new(0, -landImpulse, 0))
end

function ViewmodelController.update(dt: number): ()
	if not activeViewmodel or not activeViewmodel.PrimaryPart then
		return
	end

	-- Update springs
	local mouseDelta: Vector2 = UserInputService:GetMouseDelta()
	swaySpring:Impulse(Vector3.new(-mouseDelta.X * SWAY_SCALE, mouseDelta.Y * SWAY_SCALE, 0))

	swaySpring:Update(dt)
	recoilSpring:Update(dt)
	movementSpring:Update(dt)

	-- Base viewmodel CFrame: attached to camera
	local baseCFrame: CFrame = camera.CFrame

	-- Spring offsets
	local swayOffset: CFrame = CFrame.Angles(swaySpring.Position.Y, swaySpring.Position.X, 0)
	local recoilOffset: CFrame = CFrame.Angles(recoilSpring.Position.X, recoilSpring.Position.Y, recoilSpring.Position.Z)
		* CFrame.new(0, 0, recoilSpring.Position.Z * 0.5)
	local moveOffset: CFrame = CFrame.new(0, movementSpring.Position.Y, 0)

	-- Strafe tilt
	local tiltCFrame: CFrame = CFrame.Angles(0, 0, strafeTilt)

	-- Combine
	local finalCFrame: CFrame = baseCFrame * swayOffset * recoilOffset * moveOffset * tiltCFrame

	-- ADS interpolation
	local isADS: boolean = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	local targetADS: number = if isADS then 1 else 0
	adsAlpha += (targetADS - adsAlpha) * math.min(dt * ADS_LERP_SPEED, 1)

	if adsAlpha > 0.01 and aimPart then
		local aimOffset: CFrame = aimPart.CFrame:ToObjectSpace(activeViewmodel.PrimaryPart.CFrame)
		finalCFrame = finalCFrame:Lerp(camera.CFrame * aimOffset, adsAlpha)
	end

	activeViewmodel:PivotTo(finalCFrame)
end

function ViewmodelController.setStrafeTilt(strafeInput: number, isSliding: boolean): ()
	local targetTilt: number
	if isSliding then
		targetTilt = SLIDE_TILT_ANGLE
	else
		targetTilt = -strafeInput * STRAFE_TILT_ANGLE
	end
	strafeTilt += (targetTilt - strafeTilt) * 0.15
end

return ViewmodelController
