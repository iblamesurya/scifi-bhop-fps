--!strict
-- 1P weapon animation data: idle, equip, fire, reload, inspect tracks per weapon

export type AnimData = {
	Id: string,
	Priority: Enum.AnimationPriority,
	FadeTime: number,
	Looped: boolean,
}

export type WeaponAnims = { [string]: AnimData }
export type ViewmodelAnimsType = { [string]: WeaponAnims }

local ViewmodelAnims: ViewmodelAnimsType = table.freeze({
	pulse_rifle = table.freeze({
		Idle = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Core,
			FadeTime = 0.2,
			Looped = true,
		}),
		Equip = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.15,
			Looped = false,
		}),
		Fire = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.05,
			Looped = false,
		}),
		Reload = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action4,
			FadeTime = 0.1,
			Looped = false,
		}),
		Inspect = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action2,
			FadeTime = 0.2,
			Looped = false,
		}),
	}),
	scatter_blaster = table.freeze({
		Idle = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Core,
			FadeTime = 0.2,
			Looped = true,
		}),
		Equip = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.15,
			Looped = false,
		}),
		Fire = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.05,
			Looped = false,
		}),
		Reload = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action4,
			FadeTime = 0.1,
			Looped = false,
		}),
		Inspect = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action2,
			FadeTime = 0.2,
			Looped = false,
		}),
	}),
})

return ViewmodelAnims
