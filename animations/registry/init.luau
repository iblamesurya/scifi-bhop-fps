--!strict
-- Master AnimationRegistry: queries viewmodel and character animation data

local ViewmodelAnims = require(script.ViewmodelAnims)
local CharacterAnims = require(script.CharacterAnims)

type AnimData = ViewmodelAnims.AnimData

local AnimationRegistry = {}

function AnimationRegistry.getViewmodelAnim(weaponId: string, animName: string): AnimData
	local weaponAnims = ViewmodelAnims[weaponId]
	assert(weaponAnims, `AnimationRegistry: unknown weapon "{weaponId}"`)
	local anim = weaponAnims[animName]
	assert(anim, `AnimationRegistry: unknown anim "{animName}" for weapon "{weaponId}"`)
	return anim
end

function AnimationRegistry.getCharacterAnim(animName: string): AnimData
	local anim = CharacterAnims[animName]
	assert(anim, `AnimationRegistry: unknown character anim "{animName}"`)
	return anim
end

return AnimationRegistry
