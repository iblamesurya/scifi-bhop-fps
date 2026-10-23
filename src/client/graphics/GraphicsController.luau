--!strict
-- Applies LightingProfile + B-hop velocity FOV scaling

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightingProfile = require(ReplicatedStorage:WaitForChild("Graphics"):WaitForChild("Presets").LightingProfile)
local GraphicsQualityTiers = require(ReplicatedStorage:WaitForChild("Graphics"):WaitForChild("Presets").GraphicsQualityTiers)
local MovementConfig = require(ReplicatedStorage:WaitForChild("Shared").configs.MovementConfig)

local GraphicsController = {}

local camera: Camera = workspace.CurrentCamera
local currentFOV: number = LightingProfile.FOV.BaseFOV

function GraphicsController.init(): ()
	-- Apply lighting profile
	local lp = LightingProfile.Lighting
	Lighting.Technology = lp.Technology
	Lighting.Ambient = lp.Ambient
	Lighting.OutdoorAmbient = lp.OutdoorAmbient
	Lighting.ClockTime = lp.ClockTime
	Lighting.GeographicLatitude = lp.GeographicLatitude
	Lighting.Brightness = lp.Brightness
	Lighting.EnvironmentDiffuseScale = lp.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = lp.EnvironmentSpecularScale

	-- Apply bloom
	local bloom: BloomEffect? = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = LightingProfile.Bloom.Intensity
	bloom.Size = LightingProfile.Bloom.Size
	bloom.Threshold = LightingProfile.Bloom.Threshold

	-- Apply color correction
	local cc: ColorCorrectionEffect? = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Parent = Lighting
	end
	cc.Brightness = LightingProfile.ColorCorrection.Brightness
	cc.Contrast = LightingProfile.ColorCorrection.Contrast
	cc.Saturation = LightingProfile.ColorCorrection.Saturation
	cc.TintColor = LightingProfile.ColorCorrection.TintColor

	-- Set initial FOV
	camera.FieldOfView = LightingProfile.FOV.BaseFOV
end

function GraphicsController.updateFOV(planarSpeed: number, dt: number): ()
	local fovConfig = LightingProfile.FOV
	local speedRatio: number = math.clamp(planarSpeed / MovementConfig.HardSpeedCap, 0, 1)
	local targetFOV: number = fovConfig.BaseFOV + (fovConfig.MaxBhopFOV - fovConfig.BaseFOV) * speedRatio
	currentFOV += (targetFOV - currentFOV) * math.min(dt * fovConfig.FOVLerpSpeed, 1)
	camera.FieldOfView = currentFOV
end

function GraphicsController.setQualityTier(tierName: string): ()
	local tier = GraphicsQualityTiers[tierName]
	if not tier then
		warn(`GraphicsController: unknown tier "{tierName}"`)
		return
	end
	Lighting.GlobalShadows = tier.GlobalShadows
end

return GraphicsController
