--!strict
--[[
	GraphicsQualityTiers.luau
	Frozen quality presets for Low (Competitive 240FPS) vs High (Ultra Sci-Fi) rendering modes.
]]

export type QualityTierName = "Low" | "High"

export type QualityTierSpec = {
	Name: QualityTierName,
	DisplayName: string,
	GlobalShadows: boolean,
	ShadowSoftness: number,
	EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number,
	AtmosphereDensity: number,
	AtmosphereGlare: number,
	AtmosphereHaze: number,
	BloomEnabled: boolean,
	ColorCorrectionEnabled: boolean,
	DepthOfFieldEnabled: boolean,
	SunRaysEnabled: boolean,
	MuzzleLightEnabled: boolean,
	MuzzleSparkCount: number,
	ImpactSparkCount: number,
}

export type GraphicsQualityTiersConfig = {
	BaseFOV: number,
	MaxSpeedFOVBoost: number,
	Low: QualityTierSpec,
	High: QualityTierSpec,
	Tiers: {
		Low: QualityTierSpec,
		High: QualityTierSpec,
	},
}

local LowTier: QualityTierSpec = table.freeze({
	Name = "Low",
	DisplayName = "Competitive 240FPS",
	GlobalShadows = false,
	ShadowSoftness = 0,
	EnvironmentDiffuseScale = 0.45,
	EnvironmentSpecularScale = 0.2,
	AtmosphereDensity = 0.08,
	AtmosphereGlare = 0,
	AtmosphereHaze = 0.3,
	BloomEnabled = false,
	ColorCorrectionEnabled = true,
	DepthOfFieldEnabled = false,
	SunRaysEnabled = false,
	MuzzleLightEnabled = false,
	MuzzleSparkCount = 3,
	ImpactSparkCount = 5,
})

local HighTier: QualityTierSpec = table.freeze({
	Name = "High",
	DisplayName = "Ultra Sci-Fi",
	GlobalShadows = true,
	ShadowSoftness = 0.15,
	EnvironmentDiffuseScale = 0.85,
	EnvironmentSpecularScale = 1.0,
	AtmosphereDensity = 0.24,
	AtmosphereGlare = 0.15,
	AtmosphereHaze = 1.2,
	BloomEnabled = true,
	ColorCorrectionEnabled = true,
	DepthOfFieldEnabled = false,
	SunRaysEnabled = true,
	MuzzleLightEnabled = true,
	MuzzleSparkCount = 8,
	ImpactSparkCount = 14,
})

local Tiers = table.freeze({
	Low = LowTier,
	High = HighTier,
})

local GraphicsQualityTiers: GraphicsQualityTiersConfig = {
	BaseFOV = 85,
	MaxSpeedFOVBoost = 18,
	Low = LowTier,
	High = HighTier,
	Tiers = Tiers,
}

return table.freeze(GraphicsQualityTiers)
