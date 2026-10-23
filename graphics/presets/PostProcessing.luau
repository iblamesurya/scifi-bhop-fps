--!strict
--[[
	PostProcessing.luau
	Frozen post-processing configuration for Bloom, ColorCorrection, SunRays,
	DepthOfField, and B-hop velocity FOV warp parameters.
]]

export type BloomConfig = {
	Enabled: boolean,
	Intensity: number,
	Size: number,
	Threshold: number,
}

export type ColorCorrectionConfig = {
	Enabled: boolean,
	Brightness: number,
	Contrast: number,
	Saturation: number,
	TintColor: Color3,
}

export type DepthOfFieldConfig = {
	Enabled: boolean,
	FarIntensity: number,
	FocusDistance: number,
	InFocusRadius: number,
	NearIntensity: number,
}

export type SunRaysConfig = {
	Enabled: boolean,
	Intensity: number,
	Spread: number,
}

export type PostProcessingConfig = {
	BaseFOV: number,
	MaxSpeedFOVBoost: number,
	MaxSpeedFOV: number,
	ADSFov: number,
	FOVSpeedThreshold: number,
	FOVMaxSpeedReference: number,
	FOVLerpSpeed: number,
	Bloom: BloomConfig,
	ColorCorrection: ColorCorrectionConfig,
	DepthOfField: DepthOfFieldConfig,
	SunRays: SunRaysConfig,
}

local Bloom: BloomConfig = table.freeze({
	Enabled = true,
	Intensity = 0.65,
	Size = 24,
	Threshold = 0.92,
})

local ColorCorrection: ColorCorrectionConfig = table.freeze({
	Enabled = true,
	Brightness = 0.02,
	Contrast = 0.14,
	Saturation = 0.08,
	TintColor = Color3.fromRGB(226, 240, 255),
})

local DepthOfField: DepthOfFieldConfig = table.freeze({
	Enabled = false,
	FarIntensity = 0.12,
	FocusDistance = 45,
	InFocusRadius = 35,
	NearIntensity = 0,
})

local SunRays: SunRaysConfig = table.freeze({
	Enabled = true,
	Intensity = 0.08,
	Spread = 0.6,
})

local PostProcessing: PostProcessingConfig = {
	BaseFOV = 85,
	MaxSpeedFOVBoost = 18,
	MaxSpeedFOV = 103,
	ADSFov = 65,
	FOVSpeedThreshold = 24,
	FOVMaxSpeedReference = 90,
	FOVLerpSpeed = 12,
	Bloom = Bloom,
	ColorCorrection = ColorCorrection,
	DepthOfField = DepthOfField,
	SunRays = SunRays,
}

return table.freeze(PostProcessing)
