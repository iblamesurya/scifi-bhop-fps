--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AnimatorBridge = require(script.Parent.AnimatorBridge)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local MathFolder = Shared:WaitForChild("math")

local AssetRegistry = require(Configs:WaitForChild("AssetRegistry")) :: any
local WeaponData = require(Configs:WaitForChild("WeaponData")) :: any
local SpringModule = require(MathFolder:WaitForChild("Spring")) :: any

local ClientRoot = script.Parent.Parent
local MovementFolder = ClientRoot:WaitForChild("movement")
local MovementController = require(MovementFolder:WaitForChild("MovementController")) :: any
local SlideController = require(MovementFolder:WaitForChild("SlideController")) :: any

type SpringAdapter = {
	Position: Vector3,
	Velocity: Vector3,
	Target: Vector3,
	Impulse: (self: SpringAdapter, impulse: Vector3) -> (),
	Update: (self: SpringAdapter, dt: number) -> Vector3,
}

local function createSpring(stiffness: number, damping: number, mass: number?): SpringAdapter
	local rawSpring: any = nil
	if type(SpringModule) == "table" and type(SpringModule.new) == "function" then
		local ok, instance = pcall(function()
			return SpringModule.new(mass or 1, stiffness, damping, 1)
		end)
		if ok and type(instance) == "table" then
			rawSpring = instance
		end
	end

	local adapter: SpringAdapter = {
		Position = Vector3.zero,
		Velocity = Vector3.zero,
		Target = Vector3.zero,

		Impulse = function(self: SpringAdapter, impulse: Vector3)
			self.Velocity += impulse
			if rawSpring then
				if type(rawSpring.Impulse) == "function" then
					pcall(rawSpring.Impulse, rawSpring, impulse)
				elseif type(rawSpring.Shove) == "function" then
					pcall(rawSpring.Shove, rawSpring, impulse)
				elseif type(rawSpring.shove) == "function" then
					pcall(rawSpring.shove, rawSpring, impulse)
				end
			end
		end,

		Update = function(self: SpringAdapter, dt: number): Vector3
			local clampedDt = math.min(dt, 1 / 15)
			if rawSpring then
				if rawSpring.Target ~= nil then
					rawSpring.Target = self.Target
				elseif rawSpring.target ~= nil then
					rawSpring.target = self.Target
				end

				local updateFn = rawSpring.Update or rawSpring.update or rawSpring.Step or rawSpring.step
				if type(updateFn) == "function" then
					local ok, res = pcall(updateFn, rawSpring, clampedDt)
					if ok and typeof(res) == "Vector3" then
						self.Position = res
						return res
					end
					local pos = rawSpring.Position or rawSpring.position
					if typeof(pos) == "Vector3" then
						self.Position = pos
						return pos
					end
				end
			end

			local displacement = self.Position - self.Target
			local accel = (-stiffness * displacement) - (damping * self.Velocity)
			self.Velocity += accel * clampedDt
			self.Position += self.Velocity * clampedDt
			return self.Position
		end,
	}

	return adapter
end

local RENDER_STEP_NAME = "SciFiViewmodelRender"
local HIP_OFFSET = CFrame.new(0.48, -0.42, -0.78)
local ADS_EYE_RELIEF = CFrame.new(0, 0, -0.55)
local STRAFE_ROLL_DEG = 4.5
local SLIDE_ROLL_DEG = -8.0
local RELOAD_DIP_Y = -0.22
local RELOAD_TILT_Z_RAD = math.rad(28)

local ViewmodelController = {}

local isInitialized = false
local isADSState = false
local adsAlpha = 0
local currentRollRad = 0
local bobPhase = 0

local isProceduralReloading = false
local reloadElapsed = 0
local reloadDuration = 0
local currentReloadAlpha = 0

local currentWeaponId: string = "VORTEX_SMG"
local activeViewmodel: Model? = nil
local rootPart: BasePart? = nil
local aimPart: BasePart? = nil
local weaponMesh: BasePart? = nil
local muzzleAttachment: Attachment? = nil

local swaySpring = createSpring(140, 16, 1)
local recoilPosSpring = createSpring(180, 18, 1)
local recoilRotSpring = createSpring(200, 16, 1)
local landingSpring = createSpring(150, 14, 1)

local inputConnections: { RBXScriptConnection } = {}

local function getWeaponConfig(weaponId: string): any
	if type(WeaponData) == "table" then
		if type(WeaponData[weaponId]) == "table" then
			return WeaponData[weaponId]
		end
		if type(WeaponData.Weapons) == "table" and type(WeaponData.Weapons[weaponId]) == "table" then
			return WeaponData.Weapons[weaponId]
		end
		if type(WeaponData.GetWeapon) == "function" then
			local ok, config = pcall(WeaponData.GetWeapon, weaponId)
			if ok and type(config) == "table" then
				return config
			end
		end
	end
	return nil
end

local function isSlidingActive(): boolean
	if type(SlideController) == "table" then
		if type(SlideController.IsSliding) == "function" then
			local ok, result = pcall(SlideController.IsSliding)
			if ok and type(result) == "boolean" then
				return result
			end
		elseif type(SlideController.IsSliding) == "boolean" then
			return SlideController.IsSliding
		end
	end

	if type(MovementController) == "table" then
		if type(MovementController.IsSliding) == "function" then
			local ok, result = pcall(MovementController.IsSliding)
			if ok and type(result) == "boolean" then
				return result
			end
		elseif type(MovementController.IsSliding) == "boolean" then
			return MovementController.IsSliding
		end
	end

	return false
end

local function getHorizontalSpeed(): number
	local localPlayer = Players.LocalPlayer
	local character = if localPlayer then localPlayer.Character else nil
	local charRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if charRoot and charRoot:IsA("BasePart") then
		local vel = charRoot.AssemblyLinearVelocity
		return Vector3.new(vel.X, 0, vel.Z).Magnitude
	end
	return 0
end

local function tryLoadModelFromRegistry(weaponId: string): Model?
	if type(AssetRegistry) ~= "table" then
		return nil
	end

	if type(AssetRegistry.GetViewmodel) == "function" then
		local ok, model = pcall(AssetRegistry.GetViewmodel, weaponId)
		if ok and typeof(model) == "Instance" and model:IsA("Model") then
			return model:Clone()
		end
	end

	local viewmodelsTable = AssetRegistry.Viewmodels
		or (if type(AssetRegistry.Models) == "table" then AssetRegistry.Models.Viewmodels else nil)
	if type(viewmodelsTable) == "table" then
		local entry = viewmodelsTable[weaponId]
		if typeof(entry) == "Instance" and entry:IsA("Model") then
			return entry:Clone()
		end
	end

	return nil
end

local function constructProceduralViewmodel(weaponId: string): Model
	local isRailgun = (weaponId == "HELIOS_RAIL")

	local model = Instance.new("Model")
	model.Name = `Viewmodel_{weaponId}`

	local root = Instance.new("Part")
	root.Name = "RootPart"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root

	local meshPart = Instance.new("Part")
	meshPart.Name = "WeaponMesh"
	meshPart.Size = if isRailgun then Vector3.new(0.22, 0.28, 1.95) else Vector3.new(0.24, 0.26, 1.25)
	meshPart.Color = if isRailgun then Color3.fromRGB(255, 150, 45) else Color3.fromRGB(45, 220, 255)
	meshPart.Material = Enum.Material.SmoothPlastic
	meshPart.Reflectance = 0.15
	meshPart.Anchored = false
	meshPart.CanCollide = false
	meshPart.CanQuery = false
	meshPart.CanTouch = false
	meshPart.Massless = true
	meshPart.CFrame = root.CFrame
	meshPart.Parent = model

	local rootToMesh = Instance.new("Motor6D")
	rootToMesh.Name = "WeaponMotor"
	rootToMesh.Part0 = root
	rootToMesh.Part1 = meshPart
	rootToMesh.C0 = CFrame.identity
	rootToMesh.C1 = CFrame.identity
	rootToMesh.Parent = root

	local aim = Instance.new("Part")
	aim.Name = "AimPart"
	aim.Size = Vector3.new(0.1, 0.1, 0.1)
	aim.Transparency = 1
	aim.Anchored = false
	aim.CanCollide = false
	aim.CanQuery = false
	aim.CanTouch = false
	aim.Massless = true
	local sightHeight = if isRailgun then 0.22 else 0.19
	aim.CFrame = root.CFrame * CFrame.new(0, sightHeight, 0.15)
	aim.Parent = model

	local rootToAim = Instance.new("Motor6D")
	rootToAim.Name = "AimMotor"
	rootToAim.Part0 = root
	rootToAim.Part1 = aim
	rootToAim.C0 = CFrame.new(0, sightHeight, 0.15)
	rootToAim.C1 = CFrame.identity
	rootToAim.Parent = root

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "MuzzleAttachment"
	muzzle.Position = Vector3.new(0, 0.04, -meshPart.Size.Z * 0.5)
	muzzle.Parent = meshPart

	return model
end

local function bindViewmodelParts(model: Model)
	local foundRoot = model:FindFirstChild("RootPart") or model.PrimaryPart
	if not foundRoot or not foundRoot:IsA("BasePart") then
		local fallbackRoot = Instance.new("Part")
		fallbackRoot.Name = "RootPart"
		fallbackRoot.Size = Vector3.new(0.2, 0.2, 0.2)
		fallbackRoot.Transparency = 1
		fallbackRoot.Anchored = true
		fallbackRoot.CanCollide = false
		fallbackRoot.CanQuery = false
		fallbackRoot.CanTouch = false
		fallbackRoot.Massless = true
		fallbackRoot.Parent = model
		model.PrimaryPart = fallbackRoot
		foundRoot = fallbackRoot
	else
		model.PrimaryPart = foundRoot
	end

	local foundMesh = model:FindFirstChild("WeaponMesh", true)
	if not foundMesh or not foundMesh:IsA("BasePart") then
		foundMesh = foundRoot
	end

	local foundAim = model:FindFirstChild("AimPart", true)
	if not foundAim or not foundAim:IsA("BasePart") then
		local createdAim = Instance.new("Part")
		createdAim.Name = "AimPart"
		createdAim.Size = Vector3.new(0.1, 0.1, 0.1)
		createdAim.Transparency = 1
		createdAim.Anchored = false
		createdAim.CanCollide = false
		createdAim.CanQuery = false
		createdAim.CanTouch = false
		createdAim.Massless = true
		createdAim.CFrame = foundRoot.CFrame * CFrame.new(0, 0.2, 0.15)
		createdAim.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = foundRoot
		weld.Part1 = createdAim
		weld.Parent = foundRoot
		foundAim = createdAim
	end

	local foundMuzzle = model:FindFirstChild("MuzzleAttachment", true)
	if not foundMuzzle or not foundMuzzle:IsA("Attachment") then
		local createdMuzzle = Instance.new("Attachment")
		createdMuzzle.Name = "MuzzleAttachment"
		createdMuzzle.Position = Vector3.new(0, 0.04, -(foundMesh :: BasePart).Size.Z * 0.5)
		createdMuzzle.Parent = foundMesh
		foundMuzzle = createdMuzzle
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
			desc.Massless = true
			desc.CastShadow = false
		end
	end

	rootPart = foundRoot :: BasePart
	weaponMesh = foundMesh :: BasePart
	aimPart = foundAim :: BasePart
	muzzleAttachment = foundMuzzle :: Attachment
end

local function updateRenderStep(dt: number)
	local camera = Workspace.CurrentCamera
	local currentRoot = rootPart
	local currentAim = aimPart
	if not camera or not activeViewmodel or not currentRoot or not currentAim then
		return
	end

	if activeViewmodel.Parent ~= camera then
		activeViewmodel.Parent = camera
	end

	-- 1. Mouse delta sway & springs
	local mouseDelta = UserInputService:GetMouseDelta()
	local swayScale = if isADSState then 0.0012 else 0.0032
	swaySpring.Target = Vector3.new(
		math.clamp(-mouseDelta.X * swayScale, -0.14, 0.14),
		math.clamp(mouseDelta.Y * swayScale, -0.14, 0.14),
		0
	)
	local swayPos = swaySpring:Update(dt)
	local recoilPos = recoilPosSpring:Update(dt)
	local recoilRot = recoilRotSpring:Update(dt)
	local landingOffset = landingSpring:Update(dt)

	-- 2. Air-strafe roll tilt (±4.5° on A/D, -8° on slide)
	local strafeInput = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		strafeInput += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		strafeInput -= 1
	end

	local targetRollDeg = if isSlidingActive() then SLIDE_ROLL_DEG else (strafeInput * STRAFE_ROLL_DEG)
	local targetRollRad = math.rad(targetRollDeg)
	local rollLerpAlpha = 1 - math.exp(-14 * dt)
	currentRollRad = currentRollRad + (targetRollRad - currentRollRad) * rollLerpAlpha

	-- 3. Subtle movement velocity bob
	local speed = getHorizontalSpeed()
	local bobAmplitude = math.clamp(speed / 28, 0, 1.2) * (if isADSState then 0.006 else 0.025)
	bobPhase += dt * math.clamp(speed * 0.45, 2.5, 14)
	local bobX = math.cos(bobPhase) * bobAmplitude
	local bobY = math.abs(math.sin(bobPhase)) * -bobAmplitude

	-- 4. Procedural reload envelope (tilting 28° on Z and dipping -0.22 studs on Y over duration)
	local targetReloadAlpha = 0
	if isProceduralReloading then
		reloadElapsed += dt
		if reloadElapsed >= reloadDuration then
			isProceduralReloading = false
			reloadElapsed = 0
			targetReloadAlpha = 0
		else
			local progress = math.clamp(reloadElapsed / reloadDuration, 0, 1)
			if progress < 0.2 then
				targetReloadAlpha = math.sin((progress / 0.2) * (math.pi * 0.5))
			elseif progress > 0.8 then
				targetReloadAlpha = math.sin(((1 - progress) / 0.2) * (math.pi * 0.5))
			else
				targetReloadAlpha = 1
			end
		end
	end
	currentReloadAlpha += (targetReloadAlpha - currentReloadAlpha) * (1 - math.exp(-18 * dt))

	local reloadOffsetY = RELOAD_DIP_Y * currentReloadAlpha
	local reloadTiltZ = RELOAD_TILT_Z_RAD * currentReloadAlpha

	-- 5. Dynamic AimPart:ToObjectSpace ADS interpolation
	local targetAds = if isADSState and not isProceduralReloading then 1 else 0
	local adsSpeed = 16
	local wConfig = getWeaponConfig(currentWeaponId)
	if type(wConfig) == "table" and type(wConfig.AimSpeed) == "number" then
		adsSpeed = wConfig.AimSpeed
	end
	adsAlpha = adsAlpha + (targetAds - adsAlpha) * (1 - math.exp(-adsSpeed * dt))

	local aimToRoot = currentAim.CFrame:ToObjectSpace(currentRoot.CFrame)
	local adsTargetCFrame = ADS_EYE_RELIEF * aimToRoot
	local baseOffset = HIP_OFFSET:Lerp(adsTargetCFrame, adsAlpha)

	-- 6. Combine procedural springs, 3D positional + rotational recoil, reload offset, and roll
	local proceduralTranslation = Vector3.new(
		swayPos.X + bobX + recoilPos.X,
		swayPos.Y + bobY + landingOffset.Y + recoilPos.Y + reloadOffsetY,
		recoilPos.Z
	)

	local proceduralRotation = CFrame.Angles(
		recoilRot.X + (landingOffset.Y * 0.35) - (swayPos.Y * 0.8),
		recoilRot.Y - (swayPos.X * 1.1),
		currentRollRad + recoilRot.Z + reloadTiltZ - (swayPos.X * 1.4)
	)

	currentRoot.CFrame = camera.CFrame * baseOffset * CFrame.new(proceduralTranslation) * proceduralRotation
end

function ViewmodelController.EquipWeaponViewmodel(weaponId: string)
	currentWeaponId = weaponId
	isProceduralReloading = false
	reloadElapsed = 0
	currentReloadAlpha = 0

	if activeViewmodel then
		AnimatorBridge.StopAll()
		activeViewmodel:Destroy()
		activeViewmodel = nil
		rootPart = nil
		aimPart = nil
		weaponMesh = nil
		muzzleAttachment = nil
	end

	local model = tryLoadModelFromRegistry(weaponId) or constructProceduralViewmodel(weaponId)
	bindViewmodelParts(model)

	local camera = Workspace.CurrentCamera
	if camera then
		model.Parent = camera
	end

	activeViewmodel = model

	AnimatorBridge.BindRig(model, weaponId)
	AnimatorBridge.PlayTrack("Equip")
	AnimatorBridge.PlayTrack("Idle")
end

ViewmodelController.EquipWeapon = ViewmodelController.EquipWeaponViewmodel
ViewmodelController.SwitchWeapon = ViewmodelController.EquipWeaponViewmodel

function ViewmodelController.ApplyRecoilImpulse(kickPos: Vector3, kickRot: Vector3?)
	local adsMultiplier = if isADSState then 0.65 else 1.0
	local resolvedRot = kickRot
	if not resolvedRot then
		local wConfig = getWeaponConfig(currentWeaponId)
		if type(wConfig) == "table" and typeof(wConfig.RecoilKickRot) == "Vector3" then
			resolvedRot = wConfig.RecoilKickRot
		else
			resolvedRot = Vector3.new(
				math.abs(kickPos.Y) * 1.4 + math.abs(kickPos.Z) * 0.6,
				kickPos.X * 0.5,
				kickPos.X * 0.35
			)
		end
	end

	recoilPosSpring:Impulse(kickPos * adsMultiplier)
	recoilRotSpring:Impulse((resolvedRot :: Vector3) * adsMultiplier)
end

function ViewmodelController.PlayFireAnimation()
	AnimatorBridge.PlayTrack("Fire")
end

function ViewmodelController.PlayReloadAnimation(duration: number)
	local resolvedDuration = if type(duration) == "number" and duration > 0 then duration else 1.5
	local trackPlayed = AnimatorBridge.PlayTrack("Reload")
	if not trackPlayed then
		isProceduralReloading = true
		reloadElapsed = 0
		reloadDuration = resolvedDuration
	end
end

function ViewmodelController.GetMuzzleAttachment(): Attachment?
	return muzzleAttachment
end

function ViewmodelController.GetMuzzleWorldPosition(): Vector3?
	if muzzleAttachment then
		return muzzleAttachment.WorldPosition
	end
	if weaponMesh then
		return (weaponMesh.CFrame * CFrame.new(0, 0, -weaponMesh.Size.Z * 0.5)).Position
	end
	return nil
end

function ViewmodelController.IsADS(): boolean
	return isADSState
end

function ViewmodelController.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	-- Subscribe landing compression spring to MovementController.OnLandedCallbacks
	if type(MovementController) == "table" and type(MovementController.OnLandedCallbacks) == "table" then
		table.insert(MovementController.OnLandedCallbacks, function(impactSpeed: number?)
			local speed = if type(impactSpeed) == "number" then math.abs(impactSpeed) else 28
			local compression = math.clamp(speed / 55, 0.2, 1.35)
			landingSpring:Impulse(Vector3.new(0, -compression * 2.2, 0))
		end)
	end

	-- Track right mouse button ADS state
	table.insert(
		inputConnections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton2 then
				isADSState = true
			end
		end)
	)

	table.insert(
		inputConnections,
		UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				isADSState = false
			end
		end)
	)

	if not activeViewmodel then
		ViewmodelController.EquipWeaponViewmodel(currentWeaponId)
	end

	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, updateRenderStep)
end

return table.freeze(ViewmodelController)
