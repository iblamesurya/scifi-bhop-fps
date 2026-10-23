--!strict

export type AnimEntry = {
	Id: string,
	Priority: Enum.AnimationPriority,
	FadeTime: number,
	Speed: number,
}

export type WeaponAnimSet = {
	Idle: AnimEntry,
	Equip: AnimEntry,
	Reload: AnimEntry,
	Fire: AnimEntry,
}

export type ViewmodelAnimRegistry = {
	VORTEX_SMG: WeaponAnimSet,
	HELIOS_RAIL: WeaponAnimSet,
	[string]: WeaponAnimSet,
}

local ViewmodelAnims: ViewmodelAnimRegistry = table.freeze({
	VORTEX_SMG = table.freeze({
		Idle = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Idle,
			FadeTime = 0.15,
			Speed = 1.0,
		}),
		Equip = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.08,
			Speed = 1.25,
		}),
		Reload = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action2,
			FadeTime = 0.12,
			Speed = 1.0,
		}),
		Fire = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action3,
			FadeTime = 0.03,
			Speed = 1.35,
		}),
	}),

	HELIOS_RAIL = table.freeze({
		Idle = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Idle,
			FadeTime = 0.18,
			Speed = 0.9,
		}),
		Equip = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.12,
			Speed = 0.95,
		}),
		Reload = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action2,
			FadeTime = 0.15,
			Speed = 0.85,
		}),
		Fire = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action3,
			FadeTime = 0.04,
			Speed = 1.0,
		}),
	}),
})

return ViewmodelAnims
