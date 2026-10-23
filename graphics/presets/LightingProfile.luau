--!strict
--[[
	LightingProfile.luau
	Frozen declarative configuration for cold sci-fi arena lighting and atmosphere.
]]

export type AtmosphereProfile = {
	Density: number,
	Offset: number,
	Color: Color3,
	Decay: Color3,
	Glare: number,
	Haze: number,
}

export type LightingProfileConfig = {
	BaseFOV: number,
	MaxSpeedFOVBoost: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ColorShift_Top: Color3,
	ColorShift_Bottom: Color3,
	Brightness: number,
	ClockTime: number,
	GeographicLatitude: number,
	EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number,
	ExposureCompensation: number,
	GlobalShadows: boolean,
	ShadowSoftness: number,
	FogColor: Color3,
	FogStart: number,
	FogEnd: number,
	Atmosphere: AtmosphereProfile,
}

local Atmosphere: AtmosphereProfile = table.freeze({
	Density = 0.24,
	Offset = 0.1,
	Color = Color3.fromRGB(85, 135, 195),
	Decay = Color3.fromRGB(18, 28, 48),
	Glare = 0.15,
	Haze = 1.2,
})

local LightingProfile: LightingProfileConfig = {
	BaseFOV = 85,
	MaxSpeedFOVBoost = 18,
	Ambient = Color3.fromRGB(26, 34, 50),
	OutdoorAmbient = Color3.fromRGB(44, 58, 82),
	ColorShift_Top = Color3.fromRGB(115, 190, 255),
	ColorShift_Bottom = Color3.fromRGB(16, 22, 36),
	Brightness = 2.25,
	ClockTime = 14.5,
	GeographicLatitude = 35,
	EnvironmentDiffuseScale = 0.85,
	EnvironmentSpecularScale = 1.0,
	ExposureCompensation = 0.1,
	GlobalShadows = true,
	ShadowSoftness = 0.15,
	FogColor = Color3.fromRGB(14, 20, 32),
	FogStart = 180,
	FogEnd = 950,
	Atmosphere = Atmosphere,
}

return table.freeze(LightingProfile)
