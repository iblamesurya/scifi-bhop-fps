--!strict
-- Future lighting, Bloom, ColorCorrection, FOV warp presets

export type LightingProfileType = {
	Lighting: {
		Technology: Enum.Technology,
		Ambient: Color3,
		OutdoorAmbient: Color3,
		ClockTime: number,
		GeographicLatitude: number,
		Brightness: number,
		EnvironmentDiffuseScale: number,
		EnvironmentSpecularScale: number,
	},
	Bloom: {
		Intensity: number,
		Size: number,
		Threshold: number,
	},
	ColorCorrection: {
		Brightness: number,
		Contrast: number,
		Saturation: number,
		TintColor: Color3,
	},
	FOV: {
		BaseFOV: number,
		MaxBhopFOV: number,
		FOVLerpSpeed: number,
	},
}

local LightingProfile: LightingProfileType = table.freeze({
	Lighting = table.freeze({
		Technology = Enum.Technology.Future,
		Ambient = Color3.fromRGB(30, 35, 45),
		OutdoorAmbient = Color3.fromRGB(60, 70, 90),
		ClockTime = 14.5,
		GeographicLatitude = 23.5,
		Brightness = 2.5,
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
	}),
	Bloom = table.freeze({
		Intensity = 0.4,
		Size = 24,
		Threshold = 1.2,
	}),
	ColorCorrection = table.freeze({
		Brightness = 0.02,
		Contrast = 0.15,
		Saturation = 0.1,
		TintColor = Color3.fromRGB(255, 255, 255),
	}),
	FOV = table.freeze({
		BaseFOV = 85,
		MaxBhopFOV = 103,
		FOVLerpSpeed = 8,
	}),
})

return LightingProfile
