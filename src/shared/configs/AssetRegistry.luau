--!strict
-- Single source of truth for all asset paths in the DataModel

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type AssetRegistryType = {
	Models: {
		Viewmodels: Instance,
		Worldmodels: Instance,
		Characters: Instance,
	},
	Audio: {
		Weapons: Instance,
		Movement: Instance,
		UI: Instance,
	},
	Sprites: {
		Crosshairs: Instance,
		WeaponIcons: Instance,
	},
	VFX: {
		PlasmaTracerBeam: Instance,
		MuzzleFlash: Instance,
		ImpactSparks: Instance,
	},
}

local Assets: Instance = ReplicatedStorage:WaitForChild("Assets")
local Models: Instance = Assets:WaitForChild("Models")
local Graphics: Instance = ReplicatedStorage:WaitForChild("Graphics")
local VFXFolder: Instance = Graphics:WaitForChild("VFX")

local AssetRegistry: AssetRegistryType = table.freeze({
	Models = table.freeze({
		Viewmodels = Models:WaitForChild("viewmodels"),
		Worldmodels = Models:WaitForChild("worldmodels"),
		Characters = Models:WaitForChild("characters"),
	}),
	Audio = table.freeze({
		Weapons = Assets:WaitForChild("Audio"):WaitForChild("weapons"),
		Movement = Assets:WaitForChild("Audio"):WaitForChild("movement"),
		UI = Assets:WaitForChild("Audio"):WaitForChild("ui"),
	}),
	Sprites = table.freeze({
		Crosshairs = Assets:WaitForChild("Sprites"):WaitForChild("crosshairs"),
		WeaponIcons = Assets:WaitForChild("Sprites"):WaitForChild("weapon_icons"),
	}),
	VFX = table.freeze({
		PlasmaTracerBeam = VFXFolder:WaitForChild("PlasmaTracerBeam"),
		MuzzleFlash = VFXFolder:WaitForChild("MuzzleFlashSciFi"),
		ImpactSparks = VFXFolder:WaitForChild("ImpactSparks"),
	}),
})

return AssetRegistry
