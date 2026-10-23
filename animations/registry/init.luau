--!strict

local ViewmodelAnims = require(script:WaitForChild("ViewmodelAnims"))
local CharacterAnims = require(script:WaitForChild("CharacterAnims"))

export type AnimEntry = ViewmodelAnims.AnimEntry
export type WeaponAnimSet = ViewmodelAnims.WeaponAnimSet
export type ViewmodelAnimRegistry = ViewmodelAnims.ViewmodelAnimRegistry
export type CharacterAnimRegistry = CharacterAnims.CharacterAnimRegistry

local AnimationRegistry = table.freeze({
	ViewmodelAnims = ViewmodelAnims,
	CharacterAnims = CharacterAnims,
})

return AnimationRegistry
