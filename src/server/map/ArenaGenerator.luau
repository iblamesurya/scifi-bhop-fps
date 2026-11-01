--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.configs.MapConfig)
local WeaponData = require(ReplicatedStorage.Shared.configs.WeaponData) :: any
local WeaponBuilder = require(ReplicatedStorage.Shared.weapons.WeaponBuilder) :: any

local ArenaGenerator = {}

local rng = Random.new()
local activeStrafeBots: { { root: BasePart, torso: BasePart, head: BasePart, humanoid: Humanoid, origin: Vector3, phase: number } } = {}

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
	table.insert(activeStrafeBots, {
		root = rootPart,
		torso = torso,
		head = head,
		humanoid = humanoid,
		origin = position,
		phase = rng:NextNumber(0, math.pi * 2),
	})
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

	-- @motionbykrit: Fair Telegraphed Boss / Elite Mecha Target with WeakPointCore, Stagger Bar & 1.0s Ground Telegraph Ring
	local bossPos = if isPhantomMidway then Vector3.new(0, 5.5, 0) else Vector3.new(0, 5.5, -140)
	local bossModel = Instance.new("Model")
	bossModel.Name = "OVERDRIVE_TITAN_BOSS"
	bossModel:SetAttribute("IsTarget", true)

	local bossRoot = createPart({
		Name = "HumanoidRootPart",
		Size = Vector3.new(4.2, 5.5, 2.6),
		CFrame = CFrame.new(bossPos),
		Color = Color3.fromRGB(28, 34, 46),
		Material = Enum.Material.Metal,
		Parent = bossModel,
	})
	local bossHead = createPart({
		Name = "Head",
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = CFrame.new(bossPos + Vector3.new(0, 4.0, 0)),
		Color = Color3.fromRGB(255, 110, 0),
		Material = Enum.Material.Neon,
		Parent = bossModel,
	})
	bossHead:SetAttribute("IsHitbox", true)

	local weakPoint = createPart({
		Name = "WeakPointCore",
		Size = Vector3.new(1.6, 1.6, 0.6),
		CFrame = CFrame.new(bossPos + Vector3.new(0, 0.8, -1.4)),
		Color = Color3.fromRGB(0, 240, 255),
		Material = Enum.Material.Neon,
		Parent = bossModel,
	})
	weakPoint:SetAttribute("IsHitbox", true)

	local telegraphRing = createPart({
		Name = "TelegraphWarningRing",
		Size = Vector3.new(0.3, 18, 18),
		CFrame = CFrame.new(bossPos.X, bossPos.Y - 2.65, bossPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 65, 55),
		Material = Enum.Material.Neon,
		Transparency = 0.65,
		CanCollide = false,
		CastShadow = false,
		Parent = bossModel,
	})
	telegraphRing.Shape = Enum.PartType.Cylinder

	local bossHumanoid = Instance.new("Humanoid")
	bossHumanoid.Name = "Humanoid"
	bossHumanoid.MaxHealth = 1000
	bossHumanoid.Health = 1000
	bossHumanoid.DisplayName = "OVERDRIVE TITAN [PHASE 1 // HIT CORE TO STAGGER]"
	bossHumanoid.Parent = bossModel
	bossModel.PrimaryPart = bossRoot

	local staggerProgress = 0
	local isStaggered = false
	bossHumanoid.HealthChanged:Connect(function(hp: number)
		if hp <= 0 then
			bossHumanoid.DisplayName = "OVERDRIVE TITAN // CORE SHATTERED (+500 CR)"
			bossHead.Color = Color3.fromRGB(45, 20, 20)
			weakPoint.Color = Color3.fromRGB(20, 40, 45)
			telegraphRing.Transparency = 0.2
			task.delay(3.5, function()
				if bossModel.Parent then
					bossHumanoid.Health = bossHumanoid.MaxHealth
					staggerProgress = 0
					isStaggered = false
					bossHead.Color = Color3.fromRGB(255, 110, 0)
					weakPoint.Color = Color3.fromRGB(0, 240, 255)
					telegraphRing.Transparency = 0.65
					bossHumanoid.DisplayName = "OVERDRIVE TITAN [PHASE 1 // HIT CORE TO STAGGER]"
				end
			end)
			return
		end

		staggerProgress = math.min(100, staggerProgress + 18)
		local phaseNum = if hp <= 330 then 3 elseif hp <= 660 then 2 else 1
		if staggerProgress >= 100 and not isStaggered then
			isStaggered = true
			weakPoint.Color = Color3.fromRGB(255, 230, 60)
			bossHumanoid.DisplayName = string.format("OVERDRIVE TITAN [PHASE %d // STAGGERED 2X FREE DAMAGE!]", phaseNum)
			task.delay(3.0, function()
				isStaggered = false
				staggerProgress = 0
				if bossHumanoid.Health > 0 then
					weakPoint.Color = Color3.fromRGB(0, 240, 255)
					bossHumanoid.DisplayName = string.format("OVERDRIVE TITAN [PHASE %d // STAGGER 0%%]", phaseNum)
				end
			end)
		elseif not isStaggered then
			bossHumanoid.DisplayName = string.format("OVERDRIVE TITAN [PHASE %d // STAGGER %d%%]", phaseNum, staggerProgress)
		end
	end)

	bossModel.Parent = targetFolder
end

local lobbySpawns: { CFrame } = {}

local function makeRebuilderPart(
	parent: Instance?,
	name: string,
	cframe: CFrame,
	size: Vector3,
	mat: Enum.Material?,
	color: Color3?,
	trans: number?,
	canCollide: boolean?,
	className: string?
): BasePart?
	if not parent then
		return nil
	end
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		existing:Destroy()
	end
	local p = Instance.new(className or "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	p.CanCollide = if canCollide == nil then true else canCollide
	p.CastShadow = (trans or 0) < 0.5
	p.Transparency = trans or 0
	p.Material = mat or Enum.Material.Concrete
	p.Color = color or Color3.fromRGB(82, 92, 108)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local function translateTree(inst: Instance?, deltaVec: Vector3)
	if not inst then
		return
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + deltaVec
		end
	end
end

local function applyAeroStrikeLobbyRebuilder(lobby: Instance)
	if lobby:GetAttribute("AeroStrikeRebuilderApplied") == true then
		return
	end
	lobby:SetAttribute("AeroStrikeRebuilderApplied", true)

	local fCentral = lobby:FindFirstChild("01_Central_Command_Island")
	local fDeploy = lobby:FindFirstChild("02_Deployment_Matchmaking_Island")
	local fArmory = lobby:FindFirstChild("03_Armory_And_Crate_Island")
	local fRange = lobby:FindFirstChild("04_LiveFire_Range_And_Killhouse_Island")
	local fVIP = lobby:FindFirstChild("05_Hall_Of_Legends_VIP_Island")
	local fParkour = lobby:FindFirstChild("06_Sky_Parkour_And_Airspace")

	-- 1. TURF COLOR, Z-FIGHTING & ISLAND CURB FIXES AT BRIDGE APPROACHES
	local bridgeCurbs: { [string]: { [string]: boolean } } = {
		CentralIsland_Terrain = { CliffCurb_1 = true, CliffCurb_5 = true, CliffCurb_9 = true, CliffCurb_13 = true },
		DeploymentIsland_Terrain = { CliffCurb_1 = true, CliffCurb_9 = true },
		ArmoryIsland_Terrain = { CliffCurb_5 = true },
		RangeIsland_Terrain = { CliffCurb_13 = true },
		VIPIsland_Terrain = { CliffCurb_9 = true },
	}

	for _, d in ipairs(lobby:GetDescendants()) do
		if d:IsA("Model") and string.find(d.Name, "Terrain") then
			local t1 = d:FindFirstChild("TurfTop_OctBar_1") :: BasePart?
			local baseY = if t1 then t1.Position.Y else nil
			for i = 1, 8 do
				local bar = d:FindFirstChild("TurfTop_OctBar_" .. i) :: BasePart?
				if bar and baseY then
					bar.CFrame = CFrame.new(bar.Position.X, baseY - (i - 1) * 0.02, bar.Position.Z) * bar.CFrame.Rotation
					bar.Color = Color3.fromRGB(55, 116, 68)
				end
			end
			local curbMap = bridgeCurbs[d.Name]
			if curbMap then
				for cname, _ in pairs(curbMap) do
					local curb = d:FindFirstChild(cname) :: BasePart?
					if curb then
						curb.CFrame = curb.CFrame - Vector3.new(0, 0.35, 0)
					end
				end
			end
		end
	end

	-- Paved concrete walkways from plazas to bridge mouths
	local concreteCol = Color3.fromRGB(206, 214, 224)
	makeRebuilderPart(fCentral, "NorthBridgeWalkway", CFrame.new(0, 600.15, -96.5), Vector3.new(26, 0.3, 26), Enum.Material.Concrete, concreteCol)
	makeRebuilderPart(fCentral, "SouthBridgeWalkway", CFrame.new(0, 600.15, 93.0), Vector3.new(22, 0.3, 38), Enum.Material.Concrete, concreteCol)
	makeRebuilderPart(fCentral, "WestBridgeWalkway", CFrame.new(-90, 600.15, 0), Vector3.new(44, 0.3, 20), Enum.Material.Concrete, concreteCol)
	makeRebuilderPart(fCentral, "EastBridgeWalkway", CFrame.new(90, 600.15, 0), Vector3.new(44, 0.3, 20), Enum.Material.Concrete, concreteCol)
	makeRebuilderPart(fDeploy, "SouthBridgeApproach", CFrame.new(0, 610.20, -184), Vector3.new(26, 0.4, 28), Enum.Material.Concrete, concreteCol)
	makeRebuilderPart(fArmory, "EastBridgeApproach", CFrame.new(-177, 608.2, 0), Vector3.new(24, 0.4, 20), Enum.Material.DiamondPlate, Color3.fromRGB(82, 92, 108))
	makeRebuilderPart(fRange, "WestBridgeApproach", CFrame.new(175, 608.2, 0), Vector3.new(20, 0.4, 20), Enum.Material.Concrete, concreteCol)
	makeRebuilderPart(fVIP, "NorthBridgeApproach", CFrame.new(0, 622.2, 172), Vector3.new(22, 0.4, 22), Enum.Material.Marble, Color3.fromRGB(235, 235, 240))

	-- 2. SLOPED BRIDGE CURBS & GANTRY PILLAR ALIGNMENT
	for _, m in ipairs(lobby:GetDescendants()) do
		if m:IsA("Model") and string.find(m.Name, "Bridge") then
			local deck = m:FindFirstChild("BridgeRoadDeck") :: BasePart?
			if deck then
				local dCF = deck.CFrame
				local halfW = deck.Size.X * 0.5
				for _, ch in ipairs(m:GetChildren()) do
					if ch:IsA("BasePart") then
						local sign = if string.find(ch.Name, "%-1") then -1 else 1
						if string.find(ch.Name, "BridgeCurb_") then
							ch.CFrame = dCF * CFrame.new(sign * (halfW - 0.9), 1.40, 0)
						elseif string.find(ch.Name, "BridgeNeonTop_") then
							ch.CFrame = dCF * CFrame.new(sign * (halfW - 0.9), 2.45, 0)
						elseif string.find(ch.Name, "BridgeForceWall_") then
							ch.CFrame = dCF * CFrame.new(sign * (halfW - 0.9), 4.00, 0)
						elseif string.find(ch.Name, "GantryPillar_") then
							local localPos = dCF:PointToObjectSpace(ch.Position)
							ch.Size = Vector3.new(ch.Size.X, 11.2, ch.Size.Z)
							ch.CFrame = dCF * CFrame.new(localPos.X, 6.60, localPos.Z)
						elseif string.find(ch.Name, "GantryHeader_") then
							local localPos = dCF:PointToObjectSpace(ch.Position)
							ch.CFrame = dCF * CFrame.new(localPos.X, 12.60, localPos.Z)
						elseif string.find(ch.Name, "GantryLight_") then
							local localPos = dCF:PointToObjectSpace(ch.Position)
							ch.CFrame = dCF * CFrame.new(localPos.X, 11.40, localPos.Z)
						end
					end
				end
			end
		end
	end

	-- 3. WATCHTOWER RELOCATION, EXTERIOR TRUSS LADDER & CABIN DOORWAY
	local towerShifts: { [string]: Vector3 } = {
		Watchtower_NW = Vector3.new(-10, 0, 20),
		Watchtower_NE = Vector3.new(10, 0, 20),
		Watchtower_SW = Vector3.new(4, 0, -4),
		Watchtower_SE = Vector3.new(-4, 0, -4),
	}

	if fCentral then
		for wtName, shift in pairs(towerShifts) do
			local wt = fCentral:FindFirstChild(wtName)
			if wt then
				translateTree(wt, shift)
				local fpad = wt:FindFirstChild("FoundationPad") :: BasePart?
				if fpad then
					local cx, cz = fpad.Position.X, fpad.Position.Z
					local truss = wt:FindFirstChild("ClimbTruss") :: BasePart?
					if truss then
						truss.Size = Vector3.new(2.2, 26.0, 2.0)
						truss.CFrame = CFrame.new(cx, 613.5, cz + 9.15)
					end
					local rim = wt:FindFirstChild("DeckNeonRim")
					if rim then
						for _, seg in ipairs(rim:GetChildren()) do
							if seg:IsA("BasePart") then
								seg.CanCollide = false
							end
						end
					end
					for _, ch in ipairs(wt:GetChildren()) do
						if ch:IsA("BasePart") and (ch.Name == "ParapetLowWall" or ch.Name == "CabinWindow") then
							if math.abs(ch.Position.Z - (cz + 7.60)) < 0.3 and ch.Size.X > 10 then
								local origY, origZ = ch.Position.Y, ch.Position.Z
								local origH, origD = ch.Size.Y, ch.Size.Z
								ch.Name = ch.Name .. "_SouthLeft"
								ch.Size = Vector3.new(4.8, origH, origD)
								ch.CFrame = CFrame.new(cx - 4.6, origY, origZ)
								local rightCopy = ch:Clone()
								rightCopy.Name = string.gsub(ch.Name, "_SouthLeft", "_SouthRight")
								rightCopy.CFrame = CFrame.new(cx + 4.6, origY, origZ)
								rightCopy.Parent = wt
							end
						end
					end
				end
			end
		end
	end

	-- 4. WALK-IN CITADEL HQ: STAIR LANDINGS, ATC DOORS, ROOF CATWALKS & LIGHTING
	local citadel = if fCentral then fCentral:FindFirstChild("Citadel_Command_HQ_WalkIn") else nil
	if citadel then
		local slateCol = Color3.fromRGB(82, 92, 108)
		local darkMetal = Color3.fromRGB(42, 48, 58)
		local glassCol = Color3.fromRGB(38, 166, 204)

		makeRebuilderPart(citadel, "Floor2_WestNorthLanding", CFrame.new(-26.5, 618.0, -79.90), Vector3.new(9.0, 1.2, 8.2), Enum.Material.Concrete, slateCol)
		makeRebuilderPart(citadel, "Floor2_WestSouthLanding", CFrame.new(-26.5, 618.0, -44.75), Vector3.new(9.0, 1.2, 9.5), Enum.Material.Concrete, slateCol)
		makeRebuilderPart(citadel, "Floor2_EastNorthLanding", CFrame.new(26.5, 618.0, -79.90), Vector3.new(9.0, 1.2, 8.2), Enum.Material.Concrete, slateCol)
		makeRebuilderPart(citadel, "Floor2_EastSouthLanding", CFrame.new(26.5, 618.0, -44.75), Vector3.new(9.0, 1.2, 9.5), Enum.Material.Concrete, slateCol)

		for _, stName in ipairs({ "WestInteriorStairs", "EastInteriorStairs", "RoofAccessStairs_W", "RoofAccessStairs_E" }) do
			local st = citadel:FindFirstChild(stName)
			if st then
				for _, p in ipairs(st:GetChildren()) do
					if p:IsA("BasePart") then
						if string.find(p.Name, "StepNose_") then
							p.CanCollide = false
						elseif string.find(p.Name, "Handrail_") then
							p.Size = Vector3.new(p.Size.X, p.Size.Y, math.max(1, p.Size.Z - 3.5))
						end
					end
				end
			end
		end

		for _, wSpec in ipairs({ { Name = "ATC_LeftWall", X = -37.0 }, { Name = "ATC_RightWall", X = 37.0 } }) do
			local wPart = citadel:FindFirstChild(wSpec.Name) :: BasePart?
			local wx = wSpec.X
			if wPart then
				wPart.Name = wSpec.Name .. "_North"
				wPart.Size = Vector3.new(2.0, 16.0, 14.0)
				wPart.CFrame = CFrame.new(wx, 626.5, -75.0)
				makeRebuilderPart(citadel, wSpec.Name .. "_South", CFrame.new(wx, 626.5, -49.0), Vector3.new(2.0, 16.0, 14.0), Enum.Material.Concrete, slateCol)
				makeRebuilderPart(citadel, wSpec.Name .. "_DoorHeader", CFrame.new(wx, 632.0, -62.0), Vector3.new(2.2, 5.0, 12.0), Enum.Material.Metal, darkMetal)
			end
		end

		makeRebuilderPart(citadel, "CitadelRoofLanding_W", CFrame.new(-45.5, 634.5, -78.25), Vector3.new(13.0, 1.4, 9.5), Enum.Material.DiamondPlate, slateCol)
		makeRebuilderPart(citadel, "CitadelRoofLanding_E", CFrame.new(45.5, 634.5, -78.25), Vector3.new(13.0, 1.4, 9.5), Enum.Material.DiamondPlate, slateCol)
		makeRebuilderPart(citadel, "RoofLandingRail_WN", CFrame.new(-45.5, 636.8, -82.7), Vector3.new(13.0, 3.2, 0.5), Enum.Material.Glass, glassCol, 0.45)
		makeRebuilderPart(citadel, "RoofLandingRail_WW", CFrame.new(-51.75, 636.8, -78.25), Vector3.new(0.5, 3.2, 9.5), Enum.Material.Glass, glassCol, 0.45)
		makeRebuilderPart(citadel, "RoofLandingRail_EN", CFrame.new(45.5, 636.8, -82.7), Vector3.new(13.0, 3.2, 0.5), Enum.Material.Glass, glassCol, 0.45)
		makeRebuilderPart(citadel, "RoofLandingRail_EE", CFrame.new(51.75, 636.8, -78.25), Vector3.new(0.5, 3.2, 9.5), Enum.Material.Glass, glassCol, 0.45)

		makeRebuilderPart(citadel, "Floor2_WestTerraceRail_W", CFrame.new(-66.7, 620.2, -62.0), Vector3.new(0.6, 3.2, 44.0), Enum.Material.Glass, glassCol, 0.45)
		makeRebuilderPart(citadel, "Floor2_EastTerraceRail_E", CFrame.new(66.7, 620.2, -62.0), Vector3.new(0.6, 3.2, 44.0), Enum.Material.Glass, glassCol, 0.45)

		local balc = citadel:FindFirstChild("BalconyGuardrail")
		if balc then
			local fn = balc:FindFirstChild("Frame_N")
			if fn then
				fn:Destroy()
			end
			for _, p in ipairs(balc:GetChildren()) do
				if p:IsA("BasePart") then
					p.Material = Enum.Material.Glass
					p.Transparency = 0.45
					p.Color = glassCol
				end
			end
		end

		for idx, lPos in ipairs({ Vector3.new(-44, 617.2, -62), Vector3.new(46, 617.2, -62), Vector3.new(0, 617.2, -62), Vector3.new(0, 633.6, -62) }) do
			local fix = makeRebuilderPart(citadel, "InteriorCeilingFixture_" .. idx, CFrame.new(lPos), Vector3.new(12, 0.3, 1.8), Enum.Material.Neon, Color3.fromRGB(225, 242, 255), 0, false)
			if fix then
				local pl = Instance.new("PointLight")
				pl.Brightness = 1.6
				pl.Range = 38
				pl.Color = Color3.fromRGB(235, 245, 255)
				pl.Parent = fix
			end
		end
	end

	-- 5. HELIPAD RAMP, DROPSHIP BOARDING RAMP, ARMORY RACKS, RANGE & VIP FIXES
	local neck = if fDeploy then fDeploy:FindFirstChild("HelipadBridgeNeck") :: BasePart? else nil
	if neck then
		neck.Size = Vector3.new(28.0, 2.0, 20.0)
		neck.CFrame = CFrame.new(0, 609.4, -318.0)
		makeRebuilderPart(fDeploy, "HelipadAscentRamp", CFrame.new(0, 611.325, -323.5) * CFrame.Angles(0, math.pi, 0), Vector3.new(28.0, 1.85, 9.0), Enum.Material.DiamondPlate, Color3.fromRGB(82, 92, 108), 0, true, "WedgePart")
	end

	local dropship = if fDeploy then fDeploy:FindFirstChild("Valkyrie_MK4_Dropship") else nil
	if dropship then
		local ramp = dropship:FindFirstChild("RearBoardingRamp") :: BasePart?
		local rCF = CFrame.new(0, 613.9, -342.1) * CFrame.Angles(math.rad(20.9), 0, 0)
		if ramp then
			ramp.Size = Vector3.new(11.5, 0.5, 10.6)
			ramp.CFrame = rCF
		end
		for _, gName in ipairs({ "RampGuideLight_-1", "RampGuideLight_1" }) do
			local gl = dropship:FindFirstChild(gName) :: BasePart?
			if gl then
				local gx = if string.find(gName, "%-1") then -5.4 else 5.4
				gl.Size = Vector3.new(0.4, 0.2, 10.4)
				gl.CanCollide = false
				gl.CFrame = CFrame.new(gx, 614.2, -342.1) * CFrame.Angles(math.rad(20.9), 0, 0)
			end
		end
	end

	local munPav = if fArmory then fArmory:FindFirstChild("Tactical_Munitions_Pavilion") else nil
	if munPav then
		local categories: { { Name: string, Z: number } } = {
			{ Name = "ASSAULT RIFLES", Z = -42 },
			{ Name = "SMG & PDW", Z = -21 },
			{ Name = "SNIPER RIFLES", Z = 0 },
			{ Name = "SHOTGUNS & HEAVY", Z = 21 },
			{ Name = "TACTICAL SPECIALS", Z = 42 },
		}
		for _, cat in ipairs(categories) do
			local wA = munPav:FindFirstChild("WeaponModelA_" .. cat.Name)
			local wB = munPav:FindFirstChild("WeaponModelB_" .. cat.Name)
			if wA then
				translateTree(wA, Vector3.new(-1.6, 0, 1.2))
				makeRebuilderPart(munPav, "RackStandA_" .. cat.Name, CFrame.new(-281.6, 613.55, cat.Z - 2.4), Vector3.new(0.45, 2.5, 1.2), Enum.Material.Metal, Color3.fromRGB(42, 48, 58))
			end
			if wB then
				translateTree(wB, Vector3.new(1.6, 0, -1.2))
				makeRebuilderPart(munPav, "RackStandB_" .. cat.Name, CFrame.new(-278.4, 613.55, cat.Z + 2.4), Vector3.new(0.45, 2.5, 1.2), Enum.Material.Metal, Color3.fromRGB(42, 48, 58))
			end
		end
	end

	local rEast = CFrame.Angles(0, -math.pi * 0.5, 0)
	if fArmory then
		for _, podSpec in ipairs({ { Name = "OperatorPod_-24", Z = -24.0 }, { Name = "OperatorPod_24", Z = 24.0 } }) do
			local pod = fArmory:FindFirstChild(podSpec.Name)
			local pz = podSpec.Z
			if pod then
				local man = pod:FindFirstChild("OperatorMannequin")
				if man then
					local px, py = -248.0, 609.5
					local map: { [string]: CFrame } = {
						LeftLeg = CFrame.new(px, py + 1.5, pz - 0.65) * rEast,
						RightLeg = CFrame.new(px, py + 1.5, pz + 0.65) * rEast,
						Torso = CFrame.new(px, py + 4.3, pz) * rEast,
						ChestRig = CFrame.new(px, py + 4.4, pz) * rEast,
						VisorCore = CFrame.new(px + 0.78, py + 4.6, pz) * rEast,
						LeftArm = CFrame.new(px + 0.3, py + 4.3, pz - 1.7) * rEast * CFrame.Angles(math.rad(25), 0, 0),
						RightArm = CFrame.new(px + 0.5, py + 4.9, pz + 1.7) * rEast * CFrame.Angles(math.rad(55), 0, 0),
						Head = CFrame.new(px, py + 6.4, pz) * rEast,
						TacticalHelmet = CFrame.new(px, py + 6.7, pz) * rEast,
						HelmetVisor = CFrame.new(px + 0.82, py + 6.45, pz) * rEast,
					}
					for cname, cf in pairs(map) do
						local part = man:FindFirstChild(cname) :: BasePart?
						if part then
							part.CFrame = cf
						end
					end
				end
				makeRebuilderPart(pod, "PreviewGunProjector", CFrame.new(-244.0, 610.3, pz), Vector3.new(1.8, 1.6, 1.8), Enum.Material.Metal, Color3.fromRGB(42, 48, 58))
			end
		end
	end

	local rangePav = if fRange then fRange:FindFirstChild("FiveLane_Firing_Pavilion") else nil
	if rangePav then
		for i = 1, 5 do
			local bench = rangePav:FindFirstChild("ShooterBench_" .. i) :: BasePart?
			if bench then
				bench.Size = Vector3.new(4.5, 3.6, 7.0)
				bench.CFrame = bench.CFrame + Vector3.new(0, 0, 1.8)
				makeRebuilderPart(rangePav, "RifleRest_" .. i, CFrame.new(204.2, 612.45, bench.Position.Z), Vector3.new(1.6, 0.5, 1.2), Enum.Material.Metal, Color3.fromRGB(42, 48, 58))
			end
			local brifle = rangePav:FindFirstChild("BenchRifle_Lane" .. i)
			if brifle then
				translateTree(brifle, Vector3.new(0, 0.85, 1.8))
			end
		end
	end

	if fVIP then
		for _, tcName in ipairs({ "TrophyCase_-16_194", "TrophyCase_-16_212", "TrophyCase_16_194", "TrophyCase_16_212" }) do
			local tc = fVIP:FindFirstChild(tcName)
			if tc then
				local ped = tc:FindFirstChild("CasePedestal") :: BasePart?
				local gls = tc:FindFirstChild("CaseGlass") :: BasePart?
				local gun = tc:FindFirstChild("GoldenTrophyGun")
				if ped and gls and gun then
					ped.Size = Vector3.new(5.0, 3.2, 10.5)
					gls.Size = Vector3.new(4.6, 4.4, 10.0)
					gls.CFrame = CFrame.new(ped.Position.X, 627.6, ped.Position.Z)
					translateTree(gun, Vector3.new(0, 0.8, -0.6))
					makeRebuilderPart(tc, "TrophyDisplayStand", CFrame.new(ped.Position.X, 626.3, ped.Position.Z - 0.4), Vector3.new(0.5, 1.8, 1.8), Enum.Material.Metal, Color3.fromRGB(255, 208, 38))
				end
			end
		end
	end

	for _, jpName in ipairs({ "JumpPad_To_Armory", "JumpPad_To_Range", "JumpPad_Armory_To_Plaza", "JumpPad_Range_To_Plaza" }) do
		local jp = lobby:FindFirstChild(jpName, true)
		if jp then
			local sign = jp:FindFirstChild("PadHoloSign") :: BasePart?
			if sign then
				sign.CFrame = CFrame.new(sign.Position) * CFrame.Angles(0, math.pi * 0.5, 0)
			end
		end
	end

	-- 6. REBUILD SKY PARKOUR COURSE (UNOBSTRUCTED SUMMIT TRAJECTORY) & CLOUDS
	if fParkour then
		local parkourCoords: { [number]: Vector3 } = {
			[1] = Vector3.new(230.0, 612.5, -88.0),
			[2] = Vector3.new(220.0, 618.0, -102.0),
			[3] = Vector3.new(209.0, 623.5, -115.0),
			[4] = Vector3.new(198.0, 629.0, -128.0),
			[5] = Vector3.new(188.0, 634.5, -141.0),
			[6] = Vector3.new(179.0, 640.5, -153.0),
			[7] = Vector3.new(171.0, 646.5, -163.0),
		}
		local cylRot = CFrame.Angles(0, 0, math.pi * 0.5)
		for idx, pos in pairs(parkourCoords) do
			local rock = fParkour:FindFirstChild("ParkourDroneRock_" .. idx) :: BasePart?
			local trim = fParkour:FindFirstChild("ParkourTrim_" .. idx) :: BasePart?
			local pad = fParkour:FindFirstChild("ParkourPad_" .. idx) :: BasePart?
			if rock then
				rock.CFrame = CFrame.new(pos) * cylRot
			end
			if trim then
				trim.CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)) * cylRot
			end
			if pad then
				pad.CFrame = CFrame.new(pos + Vector3.new(0, 2.0, 0)) * cylRot
			end
		end

		local rock1 = fParkour:FindFirstChild("ParkourDroneRock_1") :: BasePart?
		local trim1 = fParkour:FindFirstChild("ParkourTrim_1") :: BasePart?
		local pad1 = fParkour:FindFirstChild("ParkourPad_1") :: BasePart?
		if rock1 and trim1 and pad1 then
			for _, extra in ipairs({ { Idx = 0, Pos = Vector3.new(236.0, 608.5, -78.0) }, { Idx = 8, Pos = Vector3.new(163.0, 652.0, -154.0) } }) do
				local idx, pos = extra.Idx, extra.Pos
				if not fParkour:FindFirstChild("ParkourDroneRock_" .. idx) then
					local rClone = rock1:Clone()
					local tClone = trim1:Clone()
					local pClone = pad1:Clone()
					rClone.Name = "ParkourDroneRock_" .. idx
					rClone.CFrame = CFrame.new(pos) * cylRot
					rClone.Parent = fParkour
					tClone.Name = "ParkourTrim_" .. idx
					tClone.CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)) * cylRot
					tClone.Parent = fParkour
					pClone.Name = "ParkourPad_" .. idx
					pClone.CFrame = CFrame.new(pos + Vector3.new(0, 2.0, 0)) * cylRot
					pClone.Parent = fParkour
				end
			end
		end

		local cloud4 = fParkour:FindFirstChild("SkyCloudCluster_4")
		if cloud4 then
			translateTree(cloud4, Vector3.new(-145, 32, -135))
		end
		for _, d in ipairs(fParkour:GetDescendants()) do
			if d:IsA("BasePart") and string.find(d.Name, "CloudPuff") then
				d.CanCollide = false
				d.CastShadow = false
			end
		end
	end
end

local function setupAeroStrikeLobby(arenaRoot: Folder): boolean
	local lobbyFolder = Workspace:FindFirstChild("AeroStrike_SkyIsland_Lobby")
	if not lobbyFolder then
		return false
	end

	applyAeroStrikeLobbyRebuilder(lobbyFolder)

	local spinningParts: { BasePart } = {}
	local movingTargets: { { part: BasePart, origin: CFrame, phase: number } } = {}
	local holoGlobe: BasePart? = nil

	table.clear(lobbySpawns)

	for _, inst in ipairs(lobbyFolder:GetDescendants()) do
		if inst:IsA("SpawnLocation") and string.find(inst.Name, "SquadSpawn") then
			table.insert(lobbySpawns, CFrame.lookAt(inst.Position + Vector3.new(0, 3.15, 0), Vector3.new(0, inst.Position.Y + 3.15, 18)))
		end
	end

	-- Disable Arena SpawnLocations by default so RobloxLoadCharacter always spawns players on the Sky Island Lobby pads first
	local arenaFolder = Workspace:FindFirstChild("PhantomMidway_5v5_Map")
	if arenaFolder then
		for _, inst in ipairs(arenaFolder:GetDescendants()) do
			if inst:IsA("SpawnLocation") then
				inst.Enabled = false
			end
		end
	end

	for _, inst in ipairs(lobbyFolder:GetDescendants()) do
		if inst:IsA("BasePart") then
			if inst.Name == "SpinningRotor" then
				table.insert(spinningParts, inst)
			elseif inst.Name == "HoloGlobe" then
				holoGlobe = inst
			elseif inst.Name == "MovingTarget" then
				inst:SetAttribute("IsHitbox", true)
				table.insert(movingTargets, {
					part = inst,
					origin = inst.CFrame,
					phase = math.random() * math.pi * 2,
				})
			elseif inst.Name == "TorsoSilhouette" or inst.Name == "HeadSilhouette" or string.find(inst.Name, "SniperTarget") then
				inst:SetAttribute("IsHitbox", true)
			elseif inst.Name == "JumpTrigger" then
				local targetVal = inst:FindFirstChild("TargetPosition")
				local debounce: { [Instance]: boolean } = {}
				inst.Touched:Connect(function(hit: BasePart)
					local char = hit.Parent
					if not char then
						return
					end
					local hum = char:FindFirstChildOfClass("Humanoid")
					local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if hum and rootPart and not debounce[char] then
						debounce[char] = true
						local targetPos = if targetVal and targetVal:IsA("Vector3Value")
							then targetVal.Value
							else (inst.Position + Vector3.new(0, 45, 0))
						local disp = targetPos - rootPart.Position
						local gravity = Workspace.Gravity
						local flightTime = math.clamp(disp.Magnitude / 85, 0.85, 1.8)
						local vx = disp.X / flightTime
						local vz = disp.Z / flightTime
						local vy = (disp.Y + 0.5 * gravity * flightTime * flightTime) / flightTime
						rootPart.AssemblyLinearVelocity = Vector3.new(vx, vy, vz)
						task.delay(1.2, function()
							debounce[char] = nil
						end)
					end
				end)
			elseif inst.Name == "QueuePad" or inst.Name == "QueueInnerGrate" then
				local gateDebounce: { [Player]: boolean } = {}
				inst.Touched:Connect(function(hit: BasePart)
					local char = hit.Parent
					if not char then
						return
					end
					local player = Players:GetPlayerFromCharacter(char)
					if not player or gateDebounce[player] then
						return
					end
					gateDebounce[player] = true
					player:SetAttribute("InArena", true)
					local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if rootPart then
						rootPart.AssemblyLinearVelocity = Vector3.zero
						rootPart.CFrame = ArenaGenerator.GetRandomArenaSpawn()
					end
					task.delay(2.0, function()
						gateDebounce[player] = nil
					end)
				end)
			end
		end
	end

	-- Build the 54-Weapon Illuminated Grand Armory Matrix on Armory Island (-262, 609.5, 0)
	local rackModel = Instance.new("Model")
	rackModel.Name = "FPS_Weapon_Display_Rack"
	rackModel.Parent = arenaRoot

	local skinOrder: { string } = WeaponBuilder.SkinOrder or { "Factory_Issue" }
	local weaponSkins = WeaponBuilder.WeaponSkins or {}
	local arsenalOrder: { string } = WeaponData.ArsenalOrder or {
		"M4A1_Carbine",
		"MP5_Tactical",
		"AWM_Sniper",
		"M1014_Shotgun",
		"M249_MachineGun",
		"G19X_Pistol",
		"M67_Frag",
		"KABAR_Knife",
		"Tactical_Bat",
	}

	local centerArmoryX = -262
	local baseArmoryY = 609.5
	for rowIdx, skinId in ipairs(skinOrder) do
		local skinSpec = weaponSkins[skinId]
		local rarityColor = if skinSpec and skinSpec.RarityColor then skinSpec.RarityColor else Color3.fromRGB(0, 240, 255)
		local yTier = baseArmoryY + ((rowIdx - 1) * 1.45)

		for colIdx, weaponKey in ipairs(arsenalOrder) do
			local zOffset = (colIdx - 5) * 4.2
			local builtModel = WeaponBuilder.Build(weaponKey, "Worldmodel")
			if builtModel then
				builtModel.Name = string.format("R%d_C%02d_%s__%s", rowIdx, colIdx, weaponKey, skinId)
				if type(WeaponBuilder.ApplySkinToWeapon) == "function" then
					pcall(WeaponBuilder.ApplySkinToWeapon, builtModel, skinId)
				end
				local handlePart = builtModel:FindFirstChild("Handle") :: BasePart?
				if handlePart then
					builtModel.PrimaryPart = handlePart
					builtModel:PivotTo(CFrame.new(centerArmoryX, yTier, zOffset))
					for _, desc in ipairs(builtModel:GetDescendants()) do
						if desc:IsA("BasePart") then
							desc.Anchored = true
						end
					end
				end
				builtModel.Parent = rackModel

				-- Equip Prompt on the Factory_Issue bottom row so players can walk up and equip any of the 9 weapons
				if rowIdx == 1 and handlePart then
					local prompt = Instance.new("ProximityPrompt")
					prompt.ActionText = "Equip " .. weaponKey
					prompt.ObjectText = if skinSpec then skinSpec.DisplayName else "Tactical Arsenal"
					prompt.HoldDuration = 0
					prompt.MaxActivationDistance = 9
					prompt.RequiresLineOfSight = false
					prompt.Parent = handlePart
					prompt.Triggered:Connect(function(player: Player)
						player:SetAttribute("SelectedWeapon", weaponKey)
					end)
				end
			end
		end

		createPart({
			Name = string.format("ArmoryRowTrim_%02d", rowIdx),
			Size = Vector3.new(0.12, 0.08, 38),
			CFrame = CFrame.new(centerArmoryX + 0.8, yTier - 0.55, 0),
			Color = rarityColor,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = rackModel,
		})
	end

	-- Add reactive Target Dummies on the Live-Fire Range & CQB Killhouse Island (East Island X=234..285, Y=611.5)
	local rangeDummyFolder = Instance.new("Folder")
	rangeDummyFolder.Name = "LobbyKillhouseTargets"
	rangeDummyFolder.Parent = arenaRoot

	local lobbyDummyPositions = {
		{ Name = "Range_25m_Lane1", Pos = Vector3.new(236, 611.5, -58) },
		{ Name = "Range_25m_Lane3", Pos = Vector3.new(236, 611.5, -28) },
		{ Name = "Range_25m_Lane5", Pos = Vector3.new(236, 611.5, 2) },
		{ Name = "Killhouse_Breach_Entry", Pos = Vector3.new(228, 611.5, 38) },
		{ Name = "Killhouse_Center_Room", Pos = Vector3.new(252, 611.5, 44) },
		{ Name = "Killhouse_Back_Clear", Pos = Vector3.new(276, 611.5, 36) },
	}
	for _, d in ipairs(lobbyDummyPositions) do
		createTargetDummy(d.Name, d.Pos, rangeDummyFolder)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		for _, rotor in ipairs(spinningParts) do
			rotor.CFrame = rotor.CFrame * CFrame.Angles(0, dt * 2.6, 0)
		end
		if holoGlobe then
			holoGlobe.CFrame = holoGlobe.CFrame * CFrame.Angles(0, dt * 0.9, 0)
		end
		for _, t in ipairs(movingTargets) do
			local offsetZ = math.sin(elapsed * 2.4 + t.phase) * 5.2
			t.part.CFrame = t.origin * CFrame.new(0, 0, offsetZ)
		end
		-- @captainamado Server Fill: Keep solo/low-player arenas lively with moving strafe bots
		for _, bot in ipairs(activeStrafeBots) do
			if bot.humanoid.Health > 0 and bot.root.Parent then
				local strafeX = math.sin(elapsed * 2.1 + bot.phase) * 3.8
				local newPos = bot.origin + Vector3.new(strafeX, 0, 0)
				bot.root.CFrame = CFrame.new(newPos)
				bot.torso.CFrame = CFrame.new(newPos)
				bot.head.CFrame = CFrame.new(newPos + Vector3.new(0, 1.6, 0))
			end
		end
	end)

	return true
end

function ArenaGenerator.GetRandomArenaSpawn(): CFrame
	local spawns = MapConfig.ArenaSpawns
	if #spawns == 0 then
		return CFrame.new(0, 8, 0)
	end
	return spawns[rng:NextInteger(1, #spawns)]
end

function ArenaGenerator.GetLobbySpawn(): CFrame
	if #lobbySpawns > 0 then
		return lobbySpawns[rng:NextInteger(1, #lobbySpawns)]
	end
	return MapConfig.Lobby.SpawnCFrame
end

function ArenaGenerator.Init()
	if Workspace:FindFirstChild(MapConfig.ArenaName) then
		return
	end

	local arenaRoot = Instance.new("Folder")
	arenaRoot.Name = MapConfig.ArenaName

	local hasAeroStrikeLobby = setupAeroStrikeLobby(arenaRoot)
	local hasPhantomMidway = Workspace:FindFirstChild("PhantomMidway_5v5_Map") ~= nil
	if hasPhantomMidway then
		if not hasAeroStrikeLobby then
			buildLobbyBox(arenaRoot)
		end
		buildFiringRangeAndDummies(arenaRoot, true)
	else
		buildFloorAndPerimeter(arenaRoot)
		if not hasAeroStrikeLobby then
			buildLobbyBox(arenaRoot)
		end
		buildBhopSpeedway(arenaRoot)
		buildDecksAndSightlines(arenaRoot)
		buildStrafeWalls(arenaRoot)
		buildSlideTunnels(arenaRoot)
		buildFiringRangeAndDummies(arenaRoot, false)
	end

	arenaRoot.Parent = Workspace
end

return ArenaGenerator
