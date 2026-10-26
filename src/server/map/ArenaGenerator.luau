--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.configs.MapConfig)

local ArenaGenerator = {}

local rng = Random.new()

local function createPart(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	CastShadow: boolean?,
	Parent: Instance,
}): Part
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
	part.CastShadow = if props.CastShadow ~= nil then props.CastShadow else true
	part.Parent = props.Parent
	return part
end

local function createTrimmedPlatform(
	name: string,
	center: Vector3,
	size: Vector3,
	baseColor: Color3,
	trimColor: Color3,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = name

	createPart({
		Name = "Base",
		Size = size,
		CFrame = CFrame.new(center),
		Color = baseColor,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})

	local trimThickness = 0.35
	local topY = center.Y + (size.Y * 0.5) - (trimThickness * 0.5)

	-- North/South Neon Strips
	for _, zDir in { -1, 1 } do
		createPart({
			Name = "NeonTrimZ",
			Size = Vector3.new(size.X, trimThickness, trimThickness),
			CFrame = CFrame.new(center.X, topY, center.Z + zDir * ((size.Z - trimThickness) * 0.5)),
			Color = trimColor,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
	end

	-- East/West Neon Strips
	for _, xDir in { -1, 1 } do
		createPart({
			Name = "NeonTrimX",
			Size = Vector3.new(trimThickness, trimThickness, size.Z),
			CFrame = CFrame.new(center.X + xDir * ((size.X - trimThickness) * 0.5), topY, center.Z),
			Color = trimColor,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
	end

	model.Parent = parent
	return model
end

local function createRampBetween(
	name: string,
	startPos: Vector3,
	endPos: Vector3,
	width: number,
	thickness: number,
	baseColor: Color3,
	trimColor: Color3,
	parent: Instance
)
	local delta = endPos - startPos
	local length = delta.Magnitude
	if length < 1e-3 then
		return
	end

	local midPoint = (startPos + endPos) * 0.5
	local rampCFrame = CFrame.lookAt(midPoint, endPos) * CFrame.new(0, -thickness * 0.5, 0)

	createPart({
		Name = name,
		Size = Vector3.new(width, thickness, length),
		CFrame = rampCFrame,
		Color = baseColor,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	for _, side in { -1, 1 } do
		createPart({
			Name = name .. "_NeonRail",
			Size = Vector3.new(0.35, 0.35, length),
			CFrame = rampCFrame * CFrame.new(side * ((width * 0.5) - 0.2), (thickness * 0.5) + 0.1, 0),
			Color = trimColor,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = parent,
		})
	end
end

local function buildFloorAndPerimeter(arenaRoot: Folder)
	local dims = MapConfig.Dimensions
	local colors = MapConfig.Colors

	local floorFolder = Instance.new("Folder")
	floorFolder.Name = "FloorAndWalls"
	floorFolder.Parent = arenaRoot

	-- Main Dark-Grid Metallic Floor
	createPart({
		Name = "ArenaFloor",
		Size = Vector3.new(dims.ArenaWidth, dims.FloorThickness, dims.ArenaLength),
		CFrame = CFrame.new(0, -dims.FloorThickness * 0.5, 0),
		Color = colors.BaseFloor,
		Material = Enum.Material.SmoothPlastic,
		Parent = floorFolder,
	})

	-- Embedded Floor Grid Lines & Central B-Hop Speedway Guide Rails
	local gridStep = 40
	for x = -dims.ArenaWidth * 0.5 + gridStep, dims.ArenaWidth * 0.5 - gridStep, gridStep do
		local isSpeedwayEdge = math.abs(x) == 40
		createPart({
			Name = "FloorGridLineZ",
			Size = Vector3.new(if isSpeedwayEdge then 0.5 else 0.2, 0.08, dims.ArenaLength),
			CFrame = CFrame.new(x, 0.02, 0),
			Color = if isSpeedwayEdge then colors.CyanNeon else colors.SecondaryStructure,
			Material = if isSpeedwayEdge then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
			Parent = floorFolder,
		})
	end

	for z = -dims.ArenaLength * 0.5 + gridStep, dims.ArenaLength * 0.5 - gridStep, gridStep do
		local isCenterLine = z == 0
		createPart({
			Name = "FloorGridLineX",
			Size = Vector3.new(dims.ArenaWidth, 0.08, if isCenterLine then 0.6 else 0.2),
			CFrame = CFrame.new(0, 0.02, z),
			Color = if isCenterLine then colors.OrangeNeon else colors.SecondaryStructure,
			Material = if isCenterLine then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
			Parent = floorFolder,
		})
	end

	-- Perimeter Enclosure Walls
	local halfW = dims.ArenaWidth * 0.5
	local halfL = dims.ArenaLength * 0.5
	local wallH = dims.ArenaWallHeight
	local wallT = dims.WallThickness

	local walls = {
		{
			Name = "NorthWall",
			Size = Vector3.new(dims.ArenaWidth + wallT * 2, wallH, wallT),
			CFrame = CFrame.new(0, wallH * 0.5, -halfL - wallT * 0.5),
			TrimColor = colors.CyanNeon,
		},
		{
			Name = "SouthWall",
			Size = Vector3.new(dims.ArenaWidth + wallT * 2, wallH, wallT),
			CFrame = CFrame.new(0, wallH * 0.5, halfL + wallT * 0.5),
			TrimColor = colors.OrangeNeon,
		},
		{
			Name = "WestWall",
			Size = Vector3.new(wallT, wallH, dims.ArenaLength),
			CFrame = CFrame.new(-halfW - wallT * 0.5, wallH * 0.5, 0),
			TrimColor = colors.CyanNeon,
		},
		{
			Name = "EastWall",
			Size = Vector3.new(wallT, wallH, dims.ArenaLength),
			CFrame = CFrame.new(halfW + wallT * 0.5, wallH * 0.5, 0),
			TrimColor = colors.OrangeNeon,
		},
	}

	for _, wall in walls do
		createPart({
			Name = wall.Name,
			Size = wall.Size,
			CFrame = wall.CFrame,
			Color = colors.PrimaryStructure,
			Material = Enum.Material.SmoothPlastic,
			Parent = floorFolder,
		})

		createPart({
			Name = wall.Name .. "_HorizonNeon",
			Size = Vector3.new(
				if wall.Size.X > wall.Size.Z then wall.Size.X - 2 else wall.Size.X + 0.3,
				0.6,
				if wall.Size.Z > wall.Size.X then wall.Size.Z - 2 else wall.Size.Z + 0.3
			),
			CFrame = wall.CFrame * CFrame.new(0, -wallH * 0.25, 0),
			Color = wall.TrimColor,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = floorFolder,
		})
	end
end

local function buildLobbyBox(arenaRoot: Folder)
	local lobbyCfg = MapConfig.Lobby
	local colors = MapConfig.Colors

	local lobbyModel = Instance.new("Model")
	lobbyModel.Name = "GlassmorphicLobbyBox"
	lobbyModel.Parent = arenaRoot

	local center = lobbyCfg.Center
	local size = lobbyCfg.Size
	local wallThickness = 1.5

	-- Floor & Ceiling
	createPart({
		Name = "LobbyFloor",
		Size = Vector3.new(size.X, wallThickness, size.Z),
		CFrame = CFrame.new(center.X, center.Y - size.Y * 0.5, center.Z),
		Color = colors.PrimaryStructure,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		Parent = lobbyModel,
	})

	createPart({
		Name = "LobbyCeiling",
		Size = Vector3.new(size.X, wallThickness, size.Z),
		CFrame = CFrame.new(center.X, center.Y + size.Y * 0.5, center.Z),
		Color = colors.LobbyGlass,
		Material = Enum.Material.Glass,
		Transparency = lobbyCfg.GlassTransparency,
		Parent = lobbyModel,
	})

	-- Glass Walls
	local glassWalls = {
		{
			Name = "NorthGlass",
			Size = Vector3.new(size.X, size.Y, wallThickness),
			Pos = Vector3.new(center.X, center.Y, center.Z - size.Z * 0.5),
		},
		{
			Name = "SouthGlass",
			Size = Vector3.new(size.X, size.Y, wallThickness),
			Pos = Vector3.new(center.X, center.Y, center.Z + size.Z * 0.5),
		},
		{
			Name = "WestGlass",
			Size = Vector3.new(wallThickness, size.Y, size.Z),
			Pos = Vector3.new(center.X - size.X * 0.5, center.Y, center.Z),
		},
		{
			Name = "EastGlass",
			Size = Vector3.new(wallThickness, size.Y, size.Z),
			Pos = Vector3.new(center.X + size.X * 0.5, center.Y, center.Z),
		},
	}

	for _, gw in glassWalls do
		createPart({
			Name = gw.Name,
			Size = gw.Size,
			CFrame = CFrame.new(gw.Pos),
			Color = colors.LobbyGlass,
			Material = Enum.Material.Glass,
			Transparency = lobbyCfg.GlassTransparency,
			Parent = lobbyModel,
		})
	end

	-- Neon Frame Accents
	for _, ySign in { -1, 1 } do
		local frameY = center.Y + ySign * (size.Y * 0.5)
		createPart({
			Name = "LobbyNeonFrame",
			Size = Vector3.new(size.X + 0.5, 0.5, size.Z + 0.5),
			CFrame = CFrame.new(center.X, frameY, center.Z),
			Color = if ySign == 1 then colors.OrangeNeon else colors.CyanNeon,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
			CanCollide = false,
			CastShadow = false,
			Parent = lobbyModel,
		})
	end

	-- LobbySpawn Marker
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.Transparency = 1
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.CFrame = lobbyCfg.SpawnCFrame
	spawnLocation.Parent = lobbyModel
end

local function buildBhopSpeedway(arenaRoot: Folder)
	local speedwayFolder = Instance.new("Folder")
	speedwayFolder.Name = "BHopSpeedway"
	speedwayFolder.Parent = arenaRoot

	local colors = MapConfig.Colors

	for index, pad in MapConfig.BhopPads do
		createTrimmedPlatform(
			string.format("BHopPad_%02d", index),
			pad.Position,
			pad.Size,
			colors.SecondaryStructure,
			pad.TrimColor,
			speedwayFolder
		)
	end
end

local function buildDecksAndSightlines(arenaRoot: Folder)
	local decksFolder = Instance.new("Folder")
	decksFolder.Name = "DecksAndRamps"
	decksFolder.Parent = arenaRoot

	local colors = MapConfig.Colors

	-- Symmetrical Team/FFA Spawn Decks
	for _, deck in MapConfig.SpawnDecks do
		createTrimmedPlatform(
			deck.Name,
			deck.Center,
			deck.Size,
			colors.PrimaryStructure,
			deck.TrimColor,
			decksFolder
		)

		createRampBetween(
			deck.Name .. "_Ramp",
			deck.RampStart,
			deck.RampEnd,
			deck.RampWidth,
			1.5,
			colors.SecondaryStructure,
			deck.TrimColor,
			decksFolder
		)
	end

	-- High-Ground Sniper Decks with unobstructed HELIOS_RAIL sightlines
	for _, sniperDeck in MapConfig.SniperDecks do
		createTrimmedPlatform(
			sniperDeck.Name,
			sniperDeck.Center,
			sniperDeck.Size,
			colors.SniperDeckSurface,
			sniperDeck.TrimColor,
			decksFolder
		)

		createRampBetween(
			sniperDeck.Name .. "_AccessRamp",
			sniperDeck.RampStart,
			sniperDeck.RampEnd,
			sniperDeck.RampWidth,
			1.2,
			colors.SecondaryStructure,
			sniperDeck.TrimColor,
			decksFolder
		)
	end
end

local function buildStrafeWalls(arenaRoot: Folder)
	local strafeFolder = Instance.new("Folder")
	strafeFolder.Name = "AirStrafeAndSurfWalls"
	strafeFolder.Parent = arenaRoot

	local colors = MapConfig.Colors

	for index, wall in MapConfig.StrafeWalls do
		createPart({
			Name = string.format("StrafeWall_%02d", index),
			Size = wall.Size,
			CFrame = wall.CFrame,
			Color = colors.SecondaryStructure,
			Material = Enum.Material.SmoothPlastic,
			Parent = strafeFolder,
		})

		createPart({
			Name = string.format("StrafeWall_%02d_NeonTrim", index),
			Size = Vector3.new(wall.Size.X + 0.25, 0.45, wall.Size.Z),
			CFrame = wall.CFrame * CFrame.new(0, wall.Size.Y * 0.5 - 0.5, 0),
			Color = wall.TrimColor,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = strafeFolder,
		})
	end
end

local function buildSlideTunnels(arenaRoot: Folder)
	local tunnelsFolder = Instance.new("Folder")
	tunnelsFolder.Name = "SlideTunnelsAndBarriers"
	tunnelsFolder.Parent = arenaRoot

	local colors = MapConfig.Colors

	for _, tunnel in MapConfig.SlideTunnels do
		local tunnelModel = Instance.new("Model")
		tunnelModel.Name = tunnel.Name

		-- Enforce clearance strictly under 3.5 studs
		local clearance = math.min(tunnel.Clearance, 3.4)
		local baseCF = CFrame.new(tunnel.FloorCenter) * CFrame.Angles(0, math.rad(tunnel.RotationY), 0)
		local totalHeight = clearance + tunnel.RoofThickness

		-- Overhead Low Barrier / Tunnel Roof (bottom surface sits at `clearance` studs above floor)
		createPart({
			Name = "SlideOverheadBarrier",
			Size = Vector3.new(tunnel.Width, tunnel.RoofThickness, tunnel.Length),
			CFrame = baseCF * CFrame.new(0, clearance + (tunnel.RoofThickness * 0.5), 0),
			Color = colors.PrimaryStructure,
			Material = Enum.Material.SmoothPlastic,
			Parent = tunnelModel,
		})

		-- Side Support Pillars
		for _, side in { -1, 1 } do
			createPart({
				Name = "TunnelSupportPillar",
				Size = Vector3.new(tunnel.WallThickness, totalHeight, tunnel.Length),
				CFrame = baseCF * CFrame.new(
					side * ((tunnel.Width * 0.5) + (tunnel.WallThickness * 0.5)),
					totalHeight * 0.5,
					0
				),
				Color = colors.SecondaryStructure,
				Material = Enum.Material.SmoothPlastic,
				Parent = tunnelModel,
			})
		end

		-- Front & Back Neon Clearance Indicator Bars
		for _, zSide in { -1, 1 } do
			createPart({
				Name = "SlideClearanceNeonBar",
				Size = Vector3.new(tunnel.Width, 0.35, 0.35),
				CFrame = baseCF * CFrame.new(0, clearance + 0.18, zSide * (tunnel.Length * 0.5)),
				Color = tunnel.TrimColor,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CastShadow = false,
				Parent = tunnelModel,
			})
		end

		tunnelModel.Parent = tunnelsFolder
	end
end

local function createTargetDummy(name: string, position: Vector3, parent: Instance): Model
	local dummy = Instance.new("Model")
	dummy.Name = name

	local rootPart = createPart({
		Name = "HumanoidRootPart",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(50, 60, 80),
		Transparency = 1,
		CanCollide = false,
		Parent = dummy,
	})

	local torso = createPart({
		Name = "Torso",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(35, 45, 60),
		Material = Enum.Material.SmoothPlastic,
		Parent = dummy,
	})

	local head = createPart({
		Name = "Head",
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0)),
		Color = Color3.fromRGB(255, 110, 0),
		Material = Enum.Material.Neon,
		Parent = dummy,
	})

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.DisplayName = string.upper(name)
	humanoid.Parent = dummy

	dummy.PrimaryPart = rootPart

	humanoid.Died:Connect(function()
		head.Color = Color3.fromRGB(60, 20, 20)
		torso.Color = Color3.fromRGB(40, 20, 20)
		task.delay(2.0, function()
			if dummy.Parent then
				humanoid.Health = humanoid.MaxHealth
				head.Color = Color3.fromRGB(255, 110, 0)
				torso.Color = Color3.fromRGB(35, 45, 60)
			end
		end)
	end)

	dummy.Parent = parent
	return dummy
end

local function buildFiringRangeAndDummies(arenaRoot: Folder, isPhantomMidway: boolean)
	local targetFolder = Instance.new("Folder")
	targetFolder.Name = "FiringRangeTargets"
	targetFolder.Parent = arenaRoot

	local dummyPositions = if isPhantomMidway
		then {
			{ Name = "Alpha_Lane_Target", Pos = Vector3.new(-110, 4, -8) },
			{ Name = "Mid_Carousel_West", Pos = Vector3.new(-55, 4, 12) },
			{ Name = "North_Arcade_Target", Pos = Vector3.new(0, 4, -52) },
			{ Name = "South_Boardwalk_Target", Pos = Vector3.new(0, 4, 52) },
			{ Name = "Mid_Carousel_East", Pos = Vector3.new(55, 4, -12) },
			{ Name = "Bravo_Lane_Target", Pos = Vector3.new(110, 4, 8) },
		}
		else {
			{ Name = "Close_Target_CQC", Pos = Vector3.new(0, 3, -40) },
			{ Name = "Mid_Target_Rifle_West", Pos = Vector3.new(-32, 6, -90) },
			{ Name = "Mid_Target_Rifle_East", Pos = Vector3.new(32, 6, -90) },
			{ Name = "Far_Target_Sniper_NorthDeck", Pos = Vector3.new(0, 24, -196) },
			{ Name = "Speed_Target_SouthBhop", Pos = Vector3.new(0, 3, 50) },
		}

	for _, d in ipairs(dummyPositions) do
		createTargetDummy(d.Name, d.Pos, targetFolder)
	end
end

function ArenaGenerator.GetRandomArenaSpawn(): CFrame
	local spawns = MapConfig.ArenaSpawns
	if #spawns == 0 then
		return CFrame.new(0, 8, 0)
	end
	return spawns[rng:NextInteger(1, #spawns)]
end

function ArenaGenerator.GetLobbySpawn(): CFrame
	return MapConfig.Lobby.SpawnCFrame
end

function ArenaGenerator.Init()
	if Workspace:FindFirstChild(MapConfig.ArenaName) then
		return
	end

	local arenaRoot = Instance.new("Folder")
	arenaRoot.Name = MapConfig.ArenaName

	local hasPhantomMidway = Workspace:FindFirstChild("PhantomMidway_5v5_Map") ~= nil
	if hasPhantomMidway then
		buildLobbyBox(arenaRoot)
		buildFiringRangeAndDummies(arenaRoot, true)
	else
		buildFloorAndPerimeter(arenaRoot)
		buildLobbyBox(arenaRoot)
		buildBhopSpeedway(arenaRoot)
		buildDecksAndSightlines(arenaRoot)
		buildStrafeWalls(arenaRoot)
		buildSlideTunnels(arenaRoot)
		buildFiringRangeAndDummies(arenaRoot, false)
	end

	arenaRoot.Parent = Workspace
end

return ArenaGenerator
