--!strict
--[[
	GraphicsController.luau
	Applies declarative cold sci-fi lighting presets, toggles Competitive (Low) vs Ultra (High)
	rendering tiers, and interpolates Camera.FieldOfView between 85 and 103 based on B-hop
	planar velocity (or compresses down to WeaponData.ADSFov when aiming down sights).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PresetsFolder = ReplicatedStorage:WaitForChild("Graphics"):WaitForChild("Presets")
local GraphicsQualityTiers = require(PresetsFolder:WaitForChild("GraphicsQualityTiers"))
local LightingProfile = require(PresetsFolder:WaitForChild("LightingProfile"))
local PostProcessing = require(PresetsFolder:WaitForChild("PostProcessing"))

local SharedConfigs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("configs")
local WeaponData = require(SharedConfigs:WaitForChild("WeaponData"))

local MovementController = require(script.Parent.Parent:WaitForChild("movement"):WaitForChild("MovementController"))

local WeaponController: any = nil
task.defer(function()
	local combatFolder = script.Parent.Parent:FindFirstChild("combat")
	local weaponModule = if combatFolder then combatFolder:FindFirstChild("WeaponController") else nil
	if weaponModule and weaponModule:IsA("ModuleScript") then
		local ok, result = pcall(require, weaponModule)
		if ok then
			WeaponController = result
		end
	end
end)

local BASE_FOV = PostProcessing.BaseFOV -- 85
local MAX_SPEED_FOV_BOOST = PostProcessing.MaxSpeedFOVBoost -- 18
local MAX_FOV = BASE_FOV + MAX_SPEED_FOV_BOOST -- 103
local FOV_SPEED_THRESHOLD = PostProcessing.FOVSpeedThreshold
local FOV_MAX_SPEED_REF = PostProcessing.FOVMaxSpeedReference
local FOV_LERP_SPEED = PostProcessing.FOVLerpSpeed

local initialized = false
local isCompetitiveLow = false
local currentTier = GraphicsQualityTiers.High

local atmosphereInstance: Atmosphere? = nil
local bloomInstance: BloomEffect? = nil
local colorCorrectionInstance: ColorCorrectionEffect? = nil
local depthOfFieldInstance: DepthOfFieldEffect? = nil
local sunRaysInstance: SunRaysEffect? = nil
local fovConnection: RBXScriptConnection? = nil

local GraphicsController = {}

local function getOrCreateEffect<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return (existing :: any) :: T
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return (created :: any) :: T
end

local function applyBaseLightingProfile(): ()
	Lighting.Ambient = LightingProfile.Ambient
	Lighting.OutdoorAmbient = LightingProfile.OutdoorAmbient
	Lighting.ColorShift_Top = LightingProfile.ColorShift_Top
	Lighting.ColorShift_Bottom = LightingProfile.ColorShift_Bottom
	Lighting.Brightness = LightingProfile.Brightness
	Lighting.ClockTime = LightingProfile.ClockTime
	Lighting.GeographicLatitude = LightingProfile.GeographicLatitude
	Lighting.EnvironmentDiffuseScale = LightingProfile.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = LightingProfile.EnvironmentSpecularScale
	Lighting.ExposureCompensation = LightingProfile.ExposureCompensation
	Lighting.GlobalShadows = LightingProfile.GlobalShadows
	Lighting.ShadowSoftness = LightingProfile.ShadowSoftness
	Lighting.FogColor = LightingProfile.FogColor
	Lighting.FogStart = LightingProfile.FogStart
	Lighting.FogEnd = LightingProfile.FogEnd

	local atmo = getOrCreateEffect("Atmosphere", "SciFiAtmosphere") :: Atmosphere
	atmo.Density = LightingProfile.Atmosphere.Density
	atmo.Offset = LightingProfile.Atmosphere.Offset
	atmo.Color = LightingProfile.Atmosphere.Color
	atmo.Decay = LightingProfile.Atmosphere.Decay
	atmo.Glare = LightingProfile.Atmosphere.Glare
	atmo.Haze = LightingProfile.Atmosphere.Haze
	atmosphereInstance = atmo

	local bloom = getOrCreateEffect("BloomEffect", "SciFiBloom") :: BloomEffect
	bloom.Enabled = PostProcessing.Bloom.Enabled
	bloom.Intensity = PostProcessing.Bloom.Intensity
	bloom.Size = PostProcessing.Bloom.Size
	bloom.Threshold = PostProcessing.Bloom.Threshold
	bloomInstance = bloom

	local cc = getOrCreateEffect("ColorCorrectionEffect", "SciFiColorCorrection") :: ColorCorrectionEffect
	cc.Enabled = PostProcessing.ColorCorrection.Enabled
	cc.Brightness = PostProcessing.ColorCorrection.Brightness
	cc.Contrast = PostProcessing.ColorCorrection.Contrast
	cc.Saturation = PostProcessing.ColorCorrection.Saturation
	cc.TintColor = PostProcessing.ColorCorrection.TintColor
	colorCorrectionInstance = cc

	local dof = getOrCreateEffect("DepthOfFieldEffect", "SciFiDepthOfField") :: DepthOfFieldEffect
	dof.Enabled = PostProcessing.DepthOfField.Enabled
	dof.FarIntensity = PostProcessing.DepthOfField.FarIntensity
	dof.FocusDistance = PostProcessing.DepthOfField.FocusDistance
	dof.InFocusRadius = PostProcessing.DepthOfField.InFocusRadius
	dof.NearIntensity = PostProcessing.DepthOfField.NearIntensity
	depthOfFieldInstance = dof

	local sunRays = getOrCreateEffect("SunRaysEffect", "SciFiSunRays") :: SunRaysEffect
	sunRays.Enabled = PostProcessing.SunRays.Enabled
	sunRays.Intensity = PostProcessing.SunRays.Intensity
	sunRays.Spread = PostProcessing.SunRays.Spread
	sunRaysInstance = sunRays
end

local function isPlayerAimingDownSights(): boolean
	if WeaponController ~= nil then
		if WeaponController.IsADS == true or WeaponController.IsAiming == true then
			return true
		end
		if type(WeaponController.IsAimingDownSights) == "function" then
			local ok, aiming = pcall(WeaponController.IsAimingDownSights, WeaponController)
			if ok and aiming == true then
				return true
			end
		end
	end
	return false
end

local function resolveADSFov(): number
	local weaponDataAny = WeaponData :: any
	if WeaponController ~= nil and type(WeaponController.CurrentWeaponId) == "string" then
		local stats = WeaponData.GetWeapon(WeaponController.CurrentWeaponId) :: any
		if stats and type(stats.ADSFov) == "number" then
			return stats.ADSFov
		end
	end
	if type(weaponDataAny.ADSFov) == "number" then
		return weaponDataAny.ADSFov
	end
	return PostProcessing.ADSFov
end

local function getPlanarSpeed(): number
	local movementAny = MovementController :: any
	if type(movementAny.CurrentPlanarSpeed) == "number" then
		return movementAny.CurrentPlanarSpeed
	end
	if type(movementAny.GetPlanarSpeed) == "function" then
		local ok, speed = pcall(movementAny.GetPlanarSpeed, movementAny)
		if ok and type(speed) == "number" then
			return speed
		end
	end
	return 0
end

local function updateCameraFOV(dt: number): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local targetFOV = BASE_FOV
	if isPlayerAimingDownSights() then
		targetFOV = resolveADSFov()
	else
		local planarSpeed = getPlanarSpeed()
		local speedRange = math.max(FOV_MAX_SPEED_REF - FOV_SPEED_THRESHOLD, 1)
		local speedAlpha = math.clamp((planarSpeed - FOV_SPEED_THRESHOLD) / speedRange, 0, 1)
		targetFOV = math.clamp(BASE_FOV + (MAX_SPEED_FOV_BOOST * speedAlpha), BASE_FOV, MAX_FOV)
	end

	local lerpAlpha = 1 - math.exp(-FOV_LERP_SPEED * math.min(dt, 0.1))
	camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * lerpAlpha
end

function GraphicsController.SetCompetitiveMode(isLow: boolean): ()
	isCompetitiveLow = isLow == true
	local tier = if isCompetitiveLow then GraphicsQualityTiers.Low else GraphicsQualityTiers.High
	currentTier = tier

	Lighting.GlobalShadows = tier.GlobalShadows
	Lighting.ShadowSoftness = tier.ShadowSoftness
	Lighting.EnvironmentDiffuseScale = tier.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = tier.EnvironmentSpecularScale

	if atmosphereInstance then
		atmosphereInstance.Density = tier.AtmosphereDensity
		atmosphereInstance.Glare = tier.AtmosphereGlare
		atmosphereInstance.Haze = tier.AtmosphereHaze
	end

	if bloomInstance then
		bloomInstance.Enabled = tier.BloomEnabled
	end

	if colorCorrectionInstance then
		colorCorrectionInstance.Enabled = tier.ColorCorrectionEnabled
	end

	if depthOfFieldInstance then
		depthOfFieldInstance.Enabled = tier.DepthOfFieldEnabled
	end

	if sunRaysInstance then
		sunRaysInstance.Enabled = tier.SunRaysEnabled
	end
end

function GraphicsController.IsCompetitiveMode(): boolean
	return isCompetitiveLow
end

function GraphicsController.GetCurrentTier(): GraphicsQualityTiers.QualityTierSpec
	return currentTier
end

function GraphicsController.Init(): ()
	if initialized then
		return
	end
	initialized = true

	applyBaseLightingProfile()
	GraphicsController.SetCompetitiveMode(false)

	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = BASE_FOV
	end

	if fovConnection then
		fovConnection:Disconnect()
	end
	fovConnection = RunService.RenderStepped:Connect(updateCameraFOV)
end

return table.freeze(GraphicsController)
