--!strict

export type PadData = {
	Position: Vector3,
	Size: Vector3,
	TrimColor: Color3,
}

export type StrafeWallData = {
	CFrame: CFrame,
	Size: Vector3,
	TrimColor: Color3,
}

export type SlideTunnelData = {
	Name: string,
	FloorCenter: Vector3,
	Width: number,
	Length: number,
	Clearance: number,
	RoofThickness: number,
	WallThickness: number,
	RotationY: number,
	TrimColor: Color3,
}

export type DeckData = {
	Name: string,
	Center: Vector3,
	Size: Vector3,
	RampStart: Vector3,
	RampEnd: Vector3,
	RampWidth: number,
	TrimColor: Color3,
}

export type JumpPadSpec = {
	Position: Vector3,
	Size: Vector3,
	LaunchVelocity: Vector3,
}

local CYAN_NEON = Color3.fromHex("#00F0FF")
local ORANGE_NEON = Color3.fromHex("#FF6E00")

local BhopPads: { PadData } = {
	{ Position = Vector3.new(0, 0.75, -116), Size = Vector3.new(14, 1.5, 16), TrimColor = CYAN_NEON },
	{ Position = Vector3.new(-9, 1.0, -88), Size = Vector3.new(13, 2.0, 15), TrimColor = CYAN_NEON },
	{ Position = Vector3.new(9, 1.25, -60), Size = Vector3.new(13, 2.5, 15), TrimColor = CYAN_NEON },
	{ Position = Vector3.new(-10, 1.5, -30), Size = Vector3.new(13, 3.0, 15), TrimColor = ORANGE_NEON },
	{ Position = Vector3.new(0, 1.75, 0), Size = Vector3.new(18, 3.5, 18), TrimColor = ORANGE_NEON },
	{ Position = Vector3.new(10, 1.5, 30), Size = Vector3.new(13, 3.0, 15), TrimColor = ORANGE_NEON },
	{ Position = Vector3.new(-9, 1.25, 60), Size = Vector3.new(13, 2.5, 15), TrimColor = CYAN_NEON },
	{ Position = Vector3.new(9, 1.0, 88), Size = Vector3.new(13, 2.0, 15), TrimColor = CYAN_NEON },
	{ Position = Vector3.new(0, 0.75, 116), Size = Vector3.new(14, 1.5, 16), TrimColor = CYAN_NEON },

	-- Lateral Momentum Stepping Stones
	{ Position = Vector3.new(-52, 1.0, -84), Size = Vector3.new(12, 2, 14), TrimColor = CYAN_NEON },
	{ Position = Vector3.new(-58, 1.5, -42), Size = Vector3.new(12, 3, 14), TrimColor = ORANGE_NEON },
	{ Position = Vector3.new(-58, 1.5, 42), Size = Vector3.new(12, 3, 14), TrimColor = ORANGE_NEON },
	{ Position = Vector3.new(-52, 1.0, 84), Size = Vector3.new(12, 2, 14), TrimColor = CYAN_NEON },

	{ Position = Vector3.new(52, 1.0, -84), Size = Vector3.new(12, 2, 14), TrimColor = CYAN_NEON },
	{ Position = Vector3.new(58, 1.5, -42), Size = Vector3.new(12, 3, 14), TrimColor = ORANGE_NEON },
	{ Position = Vector3.new(58, 1.5, 42), Size = Vector3.new(12, 3, 14), TrimColor = ORANGE_NEON },
	{ Position = Vector3.new(52, 1.0, 84), Size = Vector3.new(12, 2, 14), TrimColor = CYAN_NEON },
}

local ArenaSpawns: { CFrame } = {
	-- North Spawn Deck (Team Alpha / FFA)
	CFrame.lookAt(Vector3.new(0, 13, -184), Vector3.new(0, 13, 0)),
	CFrame.lookAt(Vector3.new(-22, 13, -180), Vector3.new(0, 13, 0)),
	CFrame.lookAt(Vector3.new(22, 13, -180), Vector3.new(0, 13, 0)),
	CFrame.lookAt(Vector3.new(-42, 5, -150), Vector3.new(0, 5, 0)),
	CFrame.lookAt(Vector3.new(42, 5, -150), Vector3.new(0, 5, 0)),

	-- South Spawn Deck (Team Omega / FFA)
	CFrame.lookAt(Vector3.new(0, 13, 184), Vector3.new(0, 13, 0)),
	CFrame.lookAt(Vector3.new(-22, 13, 180), Vector3.new(0, 13, 0)),
	CFrame.lookAt(Vector3.new(22, 13, 180), Vector3.new(0, 13, 0)),
	CFrame.lookAt(Vector3.new(-42, 5, 150), Vector3.new(0, 5, 0)),
	CFrame.lookAt(Vector3.new(42, 5, 150), Vector3.new(0, 5, 0)),

	-- Mid Wing FFA Spawns
	CFrame.lookAt(Vector3.new(-102, 5, 0), Vector3.new(0, 5, 0)),
	CFrame.lookAt(Vector3.new(102, 5, 0), Vector3.new(0, 5, 0)),
}

local JumpPads: { JumpPadSpec } = {
	{
		Position = Vector3.new(-48, 1.5, 0),
		Size = Vector3.new(10, 1, 10),
		LaunchVelocity = Vector3.new(38, 68, 0),
	},
	{
		Position = Vector3.new(48, 1.5, 0),
		Size = Vector3.new(10, 1, 10),
		LaunchVelocity = Vector3.new(-38, 68, 0),
	},
}

local MapConfig = {
	MapName = "Orbital_Bhop_Proving_Grounds",
	ArenaName = "SciFiArena",
	KillPlaneY = -120,
	RespawnDelay = 2.5,
	SpawnLocations = ArenaSpawns,
	JumpPads = JumpPads,

	Colors = {
		CyanNeon = CYAN_NEON,
		OrangeNeon = ORANGE_NEON,
		BaseFloor = Color3.fromRGB(14, 17, 24),
		PrimaryStructure = Color3.fromRGB(22, 26, 36),
		SecondaryStructure = Color3.fromRGB(32, 38, 52),
		SniperDeckSurface = Color3.fromRGB(26, 30, 42),
		LobbyGlass = Color3.fromRGB(120, 215, 255),
	},

	Dimensions = {
		ArenaWidth = 260,
		ArenaLength = 420,
		ArenaWallHeight = 64,
		FloorThickness = 4,
		WallThickness = 4,
		SlideClearance = 3.2, -- Strictly under 3.5 studs clearance to reward sliding
	},

	Lobby = {
		Center = Vector3.new(0, 120, 0),
		Size = Vector3.new(64, 22, 64),
		GlassTransparency = 0.65,
		SpawnCFrame = CFrame.lookAt(Vector3.new(0, 113, 20), Vector3.new(0, 113, -20)),
	},

	ArenaSpawns = ArenaSpawns,

	-- Symmetrical Team/FFA Spawn Decks
	SpawnDecks = {
		{
			Name = "NorthSpawnDeck",
			Center = Vector3.new(0, 4, -180),
			Size = Vector3.new(84, 8, 44),
			RampStart = Vector3.new(0, 0, -142),
			RampEnd = Vector3.new(0, 8, -158),
			RampWidth = 28,
			TrimColor = CYAN_NEON,
		},
		{
			Name = "SouthSpawnDeck",
			Center = Vector3.new(0, 4, 180),
			Size = Vector3.new(84, 8, 44),
			RampStart = Vector3.new(0, 0, 142),
			RampEnd = Vector3.new(0, 8, 158),
			RampWidth = 28,
			TrimColor = ORANGE_NEON,
		},
	} :: { DeckData },

	-- Elevated High-Ground Sniper Decks with long HELIOS_RAIL sightlines (370+ studs)
	SniperDecks = {
		{
			Name = "NorthHeliosSniperDeck",
			Center = Vector3.new(0, 22, -196),
			Size = Vector3.new(68, 2, 22),
			RampStart = Vector3.new(-36, 8, -172),
			RampEnd = Vector3.new(-36, 22, -192),
			RampWidth = 10,
			TrimColor = CYAN_NEON,
		},
		{
			Name = "SouthHeliosSniperDeck",
			Center = Vector3.new(0, 22, 196),
			Size = Vector3.new(68, 2, 22),
			RampStart = Vector3.new(36, 8, 172),
			RampEnd = Vector3.new(36, 22, 192),
			RampWidth = 10,
			TrimColor = ORANGE_NEON,
		},
		{
			Name = "WestOverwatchDeck",
			Center = Vector3.new(-112, 18, 0),
			Size = Vector3.new(20, 2, 76),
			RampStart = Vector3.new(-112, 0, -64),
			RampEnd = Vector3.new(-112, 18, -38),
			RampWidth = 10,
			TrimColor = CYAN_NEON,
		},
		{
			Name = "EastOverwatchDeck",
			Center = Vector3.new(112, 18, 0),
			Size = Vector3.new(20, 2, 76),
			RampStart = Vector3.new(112, 0, 64),
			RampEnd = Vector3.new(112, 18, 38),
			RampWidth = 10,
			TrimColor = ORANGE_NEON,
		},
	} :: { DeckData },

	BhopPads = BhopPads,

	-- 45-Degree Air-Strafe Curved Corridors & Angled Surf/Strafe Walls
	StrafeWalls = {
		-- Central Spine 45-Degree Surf Prism Ramps
		{
			CFrame = CFrame.new(-28, 6, 0) * CFrame.Angles(0, 0, math.rad(-45)),
			Size = Vector3.new(4, 22, 64),
			TrimColor = CYAN_NEON,
		},
		{
			CFrame = CFrame.new(28, 6, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Size = Vector3.new(4, 22, 64),
			TrimColor = ORANGE_NEON,
		},

		-- West Wing 45-Degree Air-Strafe Curved Corridor Segments
		{
			CFrame = CFrame.new(-88, 10, -108) * CFrame.Angles(0, math.rad(30), math.rad(-45)),
			Size = Vector3.new(4, 26, 48),
			TrimColor = CYAN_NEON,
		},
		{
			CFrame = CFrame.new(-98, 10, -64) * CFrame.Angles(0, math.rad(12), math.rad(-45)),
			Size = Vector3.new(4, 26, 48),
			TrimColor = CYAN_NEON,
		},
		{
			CFrame = CFrame.new(-98, 10, 64) * CFrame.Angles(0, math.rad(-12), math.rad(-45)),
			Size = Vector3.new(4, 26, 48),
			TrimColor = ORANGE_NEON,
		},
		{
			CFrame = CFrame.new(-88, 10, 108) * CFrame.Angles(0, math.rad(-30), math.rad(-45)),
			Size = Vector3.new(4, 26, 48),
			TrimColor = ORANGE_NEON,
		},

		-- East Wing 45-Degree Air-Strafe Curved Corridor Segments
		{
			CFrame = CFrame.new(88, 10, -108) * CFrame.Angles(0, math.rad(-30), math.rad(45)),
			Size = Vector3.new(4, 26, 48),
			TrimColor = CYAN_NEON,
		},
		{
			CFrame = CFrame.new(98, 10, -64) * CFrame.Angles(0, math.rad(-12), math.rad(45)),
			Size = Vector3.new(4, 26, 48),
			TrimColor = CYAN_NEON,
		},
		{
			CFrame = CFrame.new(98, 10, 64) * CFrame.Angles(0, math.rad(12), math.rad(45)),
			Size = Vector3.new(4, 26, 48),
			TrimColor = ORANGE_NEON,
		},
		{
			CFrame = CFrame.new(88, 10, 108) * CFrame.Angles(0, math.rad(30), math.rad(45)),
			Size = Vector3.new(4, 26, 48),
			TrimColor = ORANGE_NEON,
		},

		-- 45-Degree Corner Redirect Banking Walls
		{
			CFrame = CFrame.new(-96, 12, -162) * CFrame.Angles(0, math.rad(45), 0),
			Size = Vector3.new(4, 24, 56),
			TrimColor = CYAN_NEON,
		},
		{
			CFrame = CFrame.new(96, 12, -162) * CFrame.Angles(0, math.rad(-45), 0),
			Size = Vector3.new(4, 24, 56),
			TrimColor = CYAN_NEON,
		},
		{
			CFrame = CFrame.new(-96, 12, 162) * CFrame.Angles(0, math.rad(-45), 0),
			Size = Vector3.new(4, 24, 56),
			TrimColor = ORANGE_NEON,
		},
		{
			CFrame = CFrame.new(96, 12, 162) * CFrame.Angles(0, math.rad(45), 0),
			Size = Vector3.new(4, 24, 56),
			TrimColor = ORANGE_NEON,
		},
	} :: { StrafeWallData },

	-- Slide-Tunnels & Slide-Hop Low Barriers (3.2 studs vertical clearance < 3.5 studs)
	SlideTunnels = {
		{
			Name = "NorthSpeedwaySlideGate",
			FloorCenter = Vector3.new(0, 0, -102),
			Width = 26,
			Length = 8,
			Clearance = 3.2,
			RoofThickness = 5,
			WallThickness = 2,
			RotationY = 0,
			TrimColor = CYAN_NEON,
		},
		{
			Name = "SouthSpeedwaySlideGate",
			FloorCenter = Vector3.new(0, 0, 102),
			Width = 26,
			Length = 8,
			Clearance = 3.2,
			RoofThickness = 5,
			WallThickness = 2,
			RotationY = 0,
			TrimColor = ORANGE_NEON,
		},
		{
			Name = "WestMidSlideTunnel",
			FloorCenter = Vector3.new(-58, 0, 0),
			Width = 18,
			Length = 28,
			Clearance = 3.2,
			RoofThickness = 6,
			WallThickness = 2,
			RotationY = 0,
			TrimColor = CYAN_NEON,
		},
		{
			Name = "EastMidSlideTunnel",
			FloorCenter = Vector3.new(58, 0, 0),
			Width = 18,
			Length = 28,
			Clearance = 3.2,
			RoofThickness = 6,
			WallThickness = 2,
			RotationY = 0,
			TrimColor = ORANGE_NEON,
		},
		{
			Name = "NorthWestAngledSlideBarrier",
			FloorCenter = Vector3.new(-44, 0, -122),
			Width = 20,
			Length = 6,
			Clearance = 3.2,
			RoofThickness = 5,
			WallThickness = 2,
			RotationY = -35,
			TrimColor = CYAN_NEON,
		},
		{
			Name = "NorthEastAngledSlideBarrier",
			FloorCenter = Vector3.new(44, 0, -122),
			Width = 20,
			Length = 6,
			Clearance = 3.2,
			RoofThickness = 5,
			WallThickness = 2,
			RotationY = 35,
			TrimColor = CYAN_NEON,
		},
		{
			Name = "SouthWestAngledSlideBarrier",
			FloorCenter = Vector3.new(-44, 0, 122),
			Width = 20,
			Length = 6,
			Clearance = 3.2,
			RoofThickness = 5,
			WallThickness = 2,
			RotationY = 35,
			TrimColor = ORANGE_NEON,
		},
		{
			Name = "SouthEastAngledSlideBarrier",
			FloorCenter = Vector3.new(44, 0, 122),
			Width = 20,
			Length = 6,
			Clearance = 3.2,
			RoofThickness = 5,
			WallThickness = 2,
			RotationY = -35,
			TrimColor = ORANGE_NEON,
		},
	} :: { SlideTunnelData },
}

return table.freeze(MapConfig)
