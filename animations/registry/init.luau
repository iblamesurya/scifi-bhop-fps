--!strict

local ViewmodelAnims = require(script:WaitForChild("ViewmodelAnims"))
local CharacterAnims = require(script:WaitForChild("CharacterAnims"))

export type AnimEntry = ViewmodelAnims.AnimEntry
export type WeaponAnimSet = ViewmodelAnims.WeaponAnimSet
export type ViewmodelAnimRegistry = ViewmodelAnims.ViewmodelAnimRegistry
export type CharacterAnimRegistry = CharacterAnims.CharacterAnimRegistry

export type KeyframePoseSpec = {
	Time: number,
	RootCFrame: CFrame,
	LeftArmCFrame: CFrame?,
	RightArmCFrame: CFrame?,
}

local PROMPT_POSE_LIBRARY: { [string]: { Loop: boolean, Priority: Enum.AnimationPriority, Keyframes: { KeyframePoseSpec } } } = {
	Idle = {
		Loop = true,
		Priority = Enum.AnimationPriority.Idle,
		Keyframes = {
			{ Time = 0.0, RootCFrame = CFrame.new(0, 0, 0) },
			{ Time = 1.2, RootCFrame = CFrame.new(0, 0.025, 0) * CFrame.Angles(math.rad(0.6), 0, math.rad(-0.4)) },
			{ Time = 2.4, RootCFrame = CFrame.new(0, 0, 0) },
		},
	},
	Equip = {
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		Keyframes = {
			{ Time = 0.0, RootCFrame = CFrame.new(0, -0.45, 0.25) * CFrame.Angles(math.rad(-28), math.rad(14), math.rad(-12)) },
			{ Time = 0.16, RootCFrame = CFrame.new(0, 0.04, -0.03) * CFrame.Angles(math.rad(4), math.rad(-2), math.rad(2)) },
			{ Time = 0.28, RootCFrame = CFrame.new(0, 0, 0) },
		},
	},
	Reload = {
		Loop = false,
		Priority = Enum.AnimationPriority.Action2,
		Keyframes = {
			{ Time = 0.0, RootCFrame = CFrame.new(0, 0, 0) },
			{
				Time = 0.35,
				RootCFrame = CFrame.new(0.08, -0.12, 0.06) * CFrame.Angles(math.rad(16), math.rad(18), math.rad(-22)),
				LeftArmCFrame = CFrame.new(-0.15, -0.55, 0.20) * CFrame.Angles(math.rad(-35), 0, 0),
			},
			{
				Time = 0.85,
				RootCFrame = CFrame.new(0.06, -0.06, 0.04) * CFrame.Angles(math.rad(12), math.rad(14), math.rad(-16)),
				LeftArmCFrame = CFrame.new(0.02, -0.05, -0.12) * CFrame.Angles(math.rad(15), 0, 0),
			},
			{
				Time = 1.25,
				RootCFrame = CFrame.new(-0.04, 0.03, 0.10) * CFrame.Angles(math.rad(-6), math.rad(-8), math.rad(8)),
			},
			{ Time = 1.55, RootCFrame = CFrame.new(0, 0, 0) },
		},
	},
	Inspect = {
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		Keyframes = {
			{ Time = 0.0, RootCFrame = CFrame.new(0, 0, 0) },
			{ Time = 0.65, RootCFrame = CFrame.new(-0.12, 0.08, -0.08) * CFrame.Angles(math.rad(10), math.rad(34), math.rad(-28)) },
			{ Time = 1.55, RootCFrame = CFrame.new(0.10, 0.06, -0.06) * CFrame.Angles(math.rad(-8), math.rad(-26), math.rad(24)) },
			{ Time = 2.20, RootCFrame = CFrame.new(0, 0, 0) },
		},
	},
	Slide = {
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		Keyframes = {
			{ Time = 0.0, RootCFrame = CFrame.new(0, -1.35, 0) * CFrame.Angles(math.rad(38), 0, math.rad(-8)) },
			{ Time = 0.4, RootCFrame = CFrame.new(0, -1.38, 0) * CFrame.Angles(math.rad(40), 0, math.rad(-8)) },
		},
	},
	AirStrafe = {
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		Keyframes = {
			{ Time = 0.0, RootCFrame = CFrame.new(0, 0.15, 0) * CFrame.Angles(math.rad(-8), 0, math.rad(6)) },
			{ Time = 0.5, RootCFrame = CFrame.new(0, 0.18, 0) * CFrame.Angles(math.rad(-10), 0, math.rad(-6)) },
		},
	},
}

local function buildProceduralKeyframeSequence(animName: string): KeyframeSequence
	local spec = PROMPT_POSE_LIBRARY[animName] or PROMPT_POSE_LIBRARY.Idle
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = "PromptAnim_" .. animName
	kfs.Loop = spec.Loop
	kfs.Priority = spec.Priority

	for _, kfSpec in ipairs(spec.Keyframes) do
		local kf = Instance.new("Keyframe")
		kf.Name = string.format("KF_%.2fs", kfSpec.Time)
		kf.Time = kfSpec.Time

		local rootPose = Instance.new("Pose")
		rootPose.Name = "RootPart"
		rootPose.Weight = 1

		local weaponPose = Instance.new("Pose")
		weaponPose.Name = "WeaponMesh"
		weaponPose.CFrame = kfSpec.RootCFrame
		weaponPose.Weight = 1
		weaponPose.Parent = rootPose

		if kfSpec.LeftArmCFrame then
			local leftPose = Instance.new("Pose")
			leftPose.Name = "LeftArm"
			leftPose.CFrame = kfSpec.LeftArmCFrame
			leftPose.Weight = 1
			leftPose.Parent = rootPose
		end

		if kfSpec.RightArmCFrame then
			local rightPose = Instance.new("Pose")
			rightPose.Name = "RightArm"
			rightPose.CFrame = kfSpec.RightArmCFrame
			rightPose.Weight = 1
			rightPose.Parent = rootPose
		end

		rootPose.Parent = kf
		kf.Parent = kfs
	end

	return kfs
end

local AnimationRegistry = table.freeze({
	ViewmodelAnims = ViewmodelAnims,
	CharacterAnims = CharacterAnims,
	BuildProceduralKeyframeSequence = buildProceduralKeyframeSequence,
})

return AnimationRegistry
