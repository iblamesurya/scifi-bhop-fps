--!strict
-- Post-processing effects configuration: DepthOfField, SunRays, Atmosphere

export type PostProcessingType = {
	DepthOfField: {
		Enabled: boolean,
		FarIntensity: number,
		FocusDistance: number,
		InFocusRadius: number,
		NearIntensity: number,
	},
	SunRays: {
		Enabled: boolean,
		Intensity: number,
		Spread: number,
	},
	Atmosphere: {
		Density: number,
		Offset: number,
		Color: Color3,
		Decay: Color3,
		Glare: number,
		Haze: number,
	},
}

local PostProcessing: PostProcessingType = table.freeze({
	DepthOfField = table.freeze({
		Enabled = false,
		FarIntensity = 0.1,
		FocusDistance = 50,
		InFocusRadius = 30,
		NearIntensity = 0,
	}),
	SunRays = table.freeze({
		Enabled = true,
		Intensity = 0.08,
		Spread = 0.6,
	}),
	Atmosphere = table.freeze({
		Density = 0.3,
		Offset = 0.25,
		Color = Color3.fromRGB(180, 195, 220),
		Decay = Color3.fromRGB(92, 100, 120),
		Glare = 0.2,
		Haze = 1.5,
	}),
})

return PostProcessing
