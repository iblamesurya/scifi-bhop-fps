--!strict
--[[
	MapConfig.luau
	Read-only arena map bounds, spawn points, jump pads, and bhop ramp surface parameters.
]]

export type JumpPadSpec = {
	Position: Vector3,
	Size: Vector3,
	LaunchVelocity: Vector3,
}

export type MapConfigType = {
	MapName: string,
	KillPlaneY: number,
	RespawnDelay: number,
	SpawnLocations: { CFrame },
	JumpPads: { JumpPadSpec },
}

local SpawnLocations: { CFrame } = table.freeze({
	CFrame.new(-80, 6, -80) * CFrame.Angles(0, math.rad(-45), 0),
	CFrame.new(80, 6, -80) * CFrame.Angles(0, math.rad(45), 0),
	CFrame.new(-80, 6, 80) * CFrame.Angles(0, math.rad(-135), 0),
	CFrame.new(80, 6, 80) * CFrame.Angles(0, math.rad(135), 0),
	CFrame.new(0, 18, -110) * CFrame.Angles(0, 0, 0),
	CFrame.new(0, 18, 110) * CFrame.Angles(0, math.rad(180), 0),
})

local JumpPads: { JumpPadSpec } = table.freeze({
	table.freeze({
		Position = Vector3.new(-48, 1.5, 0),
		Size = Vector3.new(10, 1, 10),
		LaunchVelocity = Vector3.new(38, 68, 0),
	}),
	table.freeze({
		Position = Vector3.new(48, 1.5, 0),
		Size = Vector3.new(10, 1, 10),
		LaunchVelocity = Vector3.new(-38, 68, 0),
	}),
})

local MapConfig: MapConfigType = {
	MapName = "Orbital_Bhop_Proving_Grounds",
	KillPlaneY = -120,
	RespawnDelay = 2.5,
	SpawnLocations = SpawnLocations,
	JumpPads = JumpPads,
}

return table.freeze(MapConfig)
