--!strict
-- 3P R6 character animation data: locomotion, air-strafe, slide tracks

local ViewmodelAnims = require(script.Parent.ViewmodelAnims)
type AnimData = ViewmodelAnims.AnimData

export type CharacterAnimsType = { [string]: AnimData }

local CharacterAnims: CharacterAnimsType = table.freeze({
	Idle = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Core,
		FadeTime = 0.2,
		Looped = true,
	}),
	Walk = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Movement,
		FadeTime = 0.15,
		Looped = true,
	}),
	Sprint = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Movement,
		FadeTime = 0.15,
		Looped = true,
	}),
	Jump = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.1,
		Looped = false,
	}),
	Fall = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.2,
		Looped = true,
	}),
	Land = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.05,
		Looped = false,
	}),
	SlideStart = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Action2,
		FadeTime = 0.1,
		Looped = false,
	}),
	SlideLoop = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Action2,
		FadeTime = 0.1,
		Looped = true,
	}),
	SlideEnd = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Action2,
		FadeTime = 0.15,
		Looped = false,
	}),
	AirStrafeLeft = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.15,
		Looped = true,
	}),
	AirStrafeRight = table.freeze({
		Id = "rbxassetid://0",
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.15,
		Looped = true,
	}),
})

return CharacterAnims
