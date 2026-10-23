--!strict
-- Competitive Low (240+ FPS) vs Ultra Sci-Fi quality tier presets

export type QualityTier = {
	ParticleQuality: number,
	ShadowMap: boolean,
	GlobalShadows: boolean,
	MeshDetail: number,
	EffectDetail: number,
	WaterQuality: string,
	TargetFPS: number,
}

export type GraphicsQualityTiersType = { [string]: QualityTier }

local GraphicsQualityTiers: GraphicsQualityTiersType = table.freeze({
	Competitive = table.freeze({
		ParticleQuality = 0.3,
		ShadowMap = false,
		GlobalShadows = false,
		MeshDetail = 0.5,
		EffectDetail = 0.4,
		WaterQuality = "Low",
		TargetFPS = 240,
	}),
	Ultra = table.freeze({
		ParticleQuality = 1.0,
		ShadowMap = true,
		GlobalShadows = true,
		MeshDetail = 1.0,
		EffectDetail = 1.0,
		WaterQuality = "High",
		TargetFPS = 60,
	}),
})

return GraphicsQualityTiers
