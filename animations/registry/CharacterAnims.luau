--!strict

export type AnimEntry = {
	Id: string,
	Priority: Enum.AnimationPriority,
	FadeTime: number,
	Speed: number,
}

export type CharacterAnimRegistry = {
	SlideLoop: AnimEntry,
	AirStrafeTuck: AnimEntry,
	[string]: AnimEntry,
}

local CharacterAnims: CharacterAnimRegistry = table.freeze({
	SlideLoop = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Movement,
		FadeTime = 0.12,
		Speed = 1.0,
	}),
	AirStrafeTuck = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Movement,
		FadeTime = 0.15,
		Speed = 1.0,
	}),
})

return CharacterAnims
