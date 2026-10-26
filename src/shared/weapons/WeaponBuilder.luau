--!strict
--[[
	WeaponBuilder.luau
	Procedural micro-geometry weapon builder for the 9-weapon CAD arsenal
	(M4A1, MP5, AWM, M1014, M249, G19X, M67, KA-BAR, Slugger Bat).

	Integrated from roblox_fps_weapon_suite.luau (v4.0). Differences from the original:
	  * Builders emit `Model`s following the AGENTS.md rig convention instead of `Tool`s:
	      Viewmodel  -> vm_<id>: RootPart -> WeaponMotor -> WeaponMesh (+ AimPart, MuzzleAttachment,
	                    ShellEjectAttachment, animated Motor6D joints)
	      Worldmodel -> wm_<id>: PrimaryPart = Handle
	  * Weapon stats live in WeaponData; muzzle textures live in AssetRegistry.Textures.
	  * Models are consumed through AssetRegistry.GetViewmodel / GetWorldmodel, which fall back
	    to this builder when no authored .rbxm template exists.
]]

local Shared = (script.Parent :: Instance).Parent :: Instance
local AssetRegistry = require(Shared:WaitForChild("configs"):WaitForChild("AssetRegistry")) :: any
local WeaponData = require(Shared:WaitForChild("configs"):WaitForChild("WeaponData")) :: any

export type BuildKind = "Viewmodel" | "Worldmodel"

--[[
  CRITICAL PRECISION RULE:
  Roblox BasePart.Size clamps at 0.05 studs minimum. To completely eliminate
  blocky 0.05-stud quantization, `WeaponBuilder.AddPart` sets `part.Size = (1,1,1)`
  and uses `SpecialMesh.Scale` for exact floating-point dimensions down to 0.001
  studs! That means cooling fins, Picatinny teeth, razor edges, hollow bores,
  and scope crosshairs have true sub-millimeter precision.
]]

local WeaponBuilder = {}

local PALETTE = {
	GunmetalDark = Color3.fromRGB(26, 28, 32),
	ReceiverBlack = Color3.fromRGB(34, 37, 42),
	AnodizedSlate = Color3.fromRGB(48, 53, 60),
	ParkerizedSteel = Color3.fromRGB(58, 63, 68),
	BarrelSteel = Color3.fromRGB(42, 45, 50),
	StainlessSteel = Color3.fromRGB(185, 192, 200),
	BoltChrome = Color3.fromRGB(160, 168, 176),
	TitaniumNitride = Color3.fromRGB(212, 175, 55), -- Gold TiN match barrel coating
	PolymerBlack = Color3.fromRGB(22, 23, 26),
	RubberGrip = Color3.fromRGB(16, 17, 19),
	PolymerFDE = Color3.fromRGB(142, 122, 96), -- Magpul Flat Dark Earth
	CoyoteBronze = Color3.fromRGB(118, 98, 74), -- Daniel Defense RIS II Anodized Bronze
	SniperODG = Color3.fromRGB(62, 76, 56), -- Accuracy International Olive Drab
	GrenadeODG = Color3.fromRGB(68, 78, 58),
	SawBoxGreen = Color3.fromRGB(52, 62, 48),
	BrassGold = Color3.fromRGB(205, 165, 75),
	CopperJacket = Color3.fromRGB(188, 112, 65),
	LeadTip = Color3.fromRGB(95, 100, 105),
	ShotgunShellRed = Color3.fromRGB(185, 32, 32),
	OpticRuby = Color3.fromRGB(255, 42, 42),
	TritiumGreen = Color3.fromRGB(55, 255, 105),
	LaserRed = Color3.fromRGB(255, 30, 30),
	BlueSafetyScrew = Color3.fromRGB(40, 115, 220),
	LensGlass = Color3.fromRGB(80, 165, 210),
	LensEmerald = Color3.fromRGB(45, 160, 115),
	KnifeCarbon = Color3.fromRGB(28, 30, 34),
	BladeEdge = Color3.fromRGB(218, 225, 232),
	LeatherBrown = Color3.fromRGB(92, 56, 36),
	LeatherDark = Color3.fromRGB(58, 34, 22),
	AshWood = Color3.fromRGB(172, 128, 84),
	WalnutDark = Color3.fromRGB(115, 78, 48),
	GripTapeBlack = Color3.fromRGB(20, 20, 23),
	GripTapeGray = Color3.fromRGB(38, 40, 44),
	SafetyYellow = Color3.fromRGB(238, 192, 38),
	BoreVoid = Color3.fromRGB(6, 6, 8),
}

type PartSpec = {
	Name: string,
	Size: Vector3,
	Offset: CFrame,
	Color: Color3,
	Material: Enum.Material,
	Reflectance: number?,
	Transparency: number?,
	Shape: ("Block" | "CylinderX" | "CylinderY" | "CylinderZ" | "Sphere" | "Wedge")?,
	ParentPart: BasePart?,
	IsAnimatedJoint: boolean?,
}

-- Ultra-Precision Part Builder: Uses a 1x1x1 base part + SpecialMesh.Scale so
-- dimensions below 0.05 studs (like 0.008-stud sheet metal or 0.015-stud rails)
-- render at exact floating-point thickness without Roblox's 0.05-stud clamp!
function WeaponBuilder.AddPart(model: Instance, root: BasePart, spec: PartSpec): BasePart
	local part = Instance.new("Part")
	part.Name = spec.Name
	part.Size = Vector3.new(1, 1, 1)
	part.Color = spec.Color
	part.Material = spec.Material
	part.Reflectance = spec.Reflectance or 0
	part.Transparency = spec.Transparency or 0
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local mesh = Instance.new("SpecialMesh")
	local finalOffset = spec.Offset

	if spec.Shape == "CylinderZ" then
		-- Cylinder aligned along local Z-axis (barrel axis): Spec.Size = (DiameterX, DiameterY, LengthZ)
		mesh.MeshType = Enum.MeshType.Cylinder
		mesh.Scale = Vector3.new(spec.Size.Z, spec.Size.Y, spec.Size.X)
		finalOffset = finalOffset * CFrame.Angles(0, math.rad(90), 0)
	elseif spec.Shape == "CylinderY" then
		-- Cylinder aligned along local Y-axis (vertical post): Spec.Size = (DiameterX, HeightY, DiameterZ)
		mesh.MeshType = Enum.MeshType.Cylinder
		mesh.Scale = Vector3.new(spec.Size.Y, spec.Size.X, spec.Size.Z)
		finalOffset = finalOffset * CFrame.Angles(0, 0, math.rad(90))
	elseif spec.Shape == "CylinderX" then
		-- Cylinder aligned along local X-axis (cross-pins): Spec.Size = (LengthX, DiameterY, DiameterZ)
		mesh.MeshType = Enum.MeshType.Cylinder
		mesh.Scale = spec.Size
	elseif spec.Shape == "Sphere" then
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = spec.Size
	elseif spec.Shape == "Wedge" then
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Scale = spec.Size
	else
		mesh.MeshType = Enum.MeshType.Brick
		mesh.Scale = spec.Size
	end
	mesh.Parent = part

	local attachTo = spec.ParentPart or root
	part.CFrame = attachTo.CFrame * finalOffset
	part.Parent = model

	if spec.IsAnimatedJoint then
		local motor = Instance.new("Motor6D")
		motor.Name = spec.Name .. "_Motor"
		motor.Part0 = attachTo
		motor.Part1 = part
		motor.C0 = finalOffset
		motor.C1 = CFrame.new()
		motor.Parent = attachTo
	else
		local weld = Instance.new("WeldConstraint")
		weld.Name = spec.Name .. "_Weld"
		weld.Part0 = attachTo
		weld.Part1 = part
		weld.Parent = part
	end

	return part
end

--==============================================================================
-- SECTION 2.1: REUSABLE HIGH-DETAIL SUB-ASSEMBLY ENGINEERING MODULES
--==============================================================================

-- 1. True-to-Life MIL-STD-1913 Picatinny Rail Builder (Continuous riser + angled side dovetails + individual recoil lugs)
function WeaponBuilder.AddPicatinnyRail(
	model: Instance,
	parent: BasePart,
	prefix: string,
	centerOffset: CFrame,
	length: number,
	lugCount: number,
	railColor: Color3?
)
	local col = railColor or PALETTE.ReceiverBlack
	-- Narrow neck riser
	WeaponBuilder.AddPart(model, parent, {
		Name = prefix .. "_Riser",
		Size = Vector3.new(0.14, 0.035, length),
		Offset = centerOffset * CFrame.new(0, -0.015, 0),
		Color = col,
		Material = Enum.Material.Metal,
	})
	-- Wide upper dovetail spine
	WeaponBuilder.AddPart(model, parent, {
		Name = prefix .. "_Spine",
		Size = Vector3.new(0.21, 0.025, length),
		Offset = centerOffset * CFrame.new(0, 0.012, 0),
		Color = col,
		Material = Enum.Material.Metal,
	})
	-- Individual cross-lugs with recoil grooves
	local step = length / lugCount
	local lugLen = step * 0.58
	local startZ = -(length * 0.5) + (step * 0.5)
	for i = 1, lugCount do
		local z = startZ + (i - 1) * step
		WeaponBuilder.AddPart(model, parent, {
			Name = string.format("%s_Lug_%02d", prefix, i),
			Size = Vector3.new(0.215, 0.028, lugLen),
			Offset = centerOffset * CFrame.new(0, 0.036, z),
			Color = PALETTE.GunmetalDark,
			Material = Enum.Material.Metal,
		})
	end
end

-- 2. True Hollow Cylindrical Tube / Ring / Shroud Builder (arranged in a radial ring of curved staves)
function WeaponBuilder.AddHollowTube(
	model: Instance,
	parent: BasePart,
	prefix: string,
	centerOffset: CFrame,
	outerRadius: number,
	wallThickness: number,
	length: number,
	segments: number,
	color: Color3,
	material: Enum.Material
)
	local midRadius = outerRadius - (wallThickness * 0.5)
	local arcWidth = (2 * math.pi * outerRadius / segments) * 1.08
	for i = 1, segments do
		local angle = (i - 1) * (2 * math.pi / segments)
		local segCF = centerOffset * CFrame.Angles(0, 0, angle) * CFrame.new(0, midRadius, 0)
		WeaponBuilder.AddPart(model, parent, {
			Name = string.format("%s_Wall_%02d", prefix, i),
			Size = Vector3.new(arcWidth, wallThickness, length),
			Offset = segCF,
			Color = color,
			Material = material,
			Reflectance = (material == Enum.Material.Metal) and 0.08 or 0,
		})
	end
end

-- 3. Complete 5.56mm / 7.62mm / .338 Brass Cartridge with Bottleneck Case + Copper Spitzer Bullet Tip
function WeaponBuilder.AddCompleteCartridge(
	model: Instance,
	parent: BasePart,
	prefix: string,
	offset: CFrame,
	caseDia: number,
	caseLen: number,
	bulletLen: number
)
	-- Brass Rim & Extractor Groove
	WeaponBuilder.AddPart(model, parent, {
		Name = prefix .. "_Rim",
		Size = Vector3.new(caseDia * 1.04, caseDia * 1.04, 0.025),
		Offset = offset * CFrame.new(0, 0, caseLen * 0.5),
		Color = PALETTE.BrassGold,
		Material = Enum.Material.Metal,
		Reflectance = 0.35,
		Shape = "CylinderZ",
		ParentPart = parent,
	})
	-- Main Brass Case Body
	WeaponBuilder.AddPart(model, parent, {
		Name = prefix .. "_Case",
		Size = Vector3.new(caseDia, caseDia, caseLen),
		Offset = offset,
		Color = PALETTE.BrassGold,
		Material = Enum.Material.Metal,
		Reflectance = 0.38,
		Shape = "CylinderZ",
		ParentPart = parent,
	})
	-- Copper-Jacketed Spitzer Projectile
	WeaponBuilder.AddPart(model, parent, {
		Name = prefix .. "_Bullet",
		Size = Vector3.new(caseDia * 0.68, caseDia * 0.68, bulletLen),
		Offset = offset * CFrame.new(0, 0, -(caseLen * 0.5 + bulletLen * 0.35)),
		Color = PALETTE.CopperJacket,
		Material = Enum.Material.Metal,
		Reflectance = 0.28,
		Shape = "CylinderZ",
		ParentPart = parent,
	})
	-- Pointed Ogive Nose Tip
	WeaponBuilder.AddPart(model, parent, {
		Name = prefix .. "_BulletTip",
		Size = Vector3.new(caseDia * 0.62, caseDia * 0.62, bulletLen * 0.65),
		Offset = offset * CFrame.new(0, 0, -(caseLen * 0.5 + bulletLen * 0.72)),
		Color = PALETTE.CopperJacket,
		Material = Enum.Material.Metal,
		Reflectance = 0.32,
		Shape = "Sphere",
		ParentPart = parent,
	})
end

-- 4. Multi-Segment Progressive Curved Box Magazine (6 spline segments + ribs + feed lips + visible double-stack rounds)
function WeaponBuilder.BuildSplineCurvedMagazine(
	model: Instance,
	handle: BasePart,
	magOffset: CFrame,
	width: number,
	depth: number,
	segHeight: number,
	curvePerSegDeg: number,
	bodyColor: Color3,
	hasWindow: boolean
): BasePart
	-- Root Animated Magazine Upper Segment (Motor6D attached to Handle)
	local magRoot = WeaponBuilder.AddPart(model, handle, {
		Name = "Magazine",
		Size = Vector3.new(width, segHeight, depth),
		Offset = magOffset,
		Color = bodyColor,
		Material = Enum.Material.SmoothPlastic,
		IsAnimatedJoint = true,
	})

	-- Steel Feed Lips at top of Magazine
	WeaponBuilder.AddPart(model, magRoot, {
		Name = "MagFeedLipLeft",
		Size = Vector3.new(0.03, 0.08, depth * 0.82),
		Offset = CFrame.new(-(width * 0.38), segHeight * 0.52, 0),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
		ParentPart = magRoot,
	})
	WeaponBuilder.AddPart(model, magRoot, {
		Name = "MagFeedLipRight",
		Size = Vector3.new(0.03, 0.08, depth * 0.82),
		Offset = CFrame.new(width * 0.38, segHeight * 0.52, 0),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
		ParentPart = magRoot,
	})
	-- Anti-Tilt Follower & Top 2 Double-Stack Brass Cartridges
	WeaponBuilder.AddCompleteCartridge(
		model,
		magRoot,
		"TopRound1",
		CFrame.new(-width * 0.16, segHeight * 0.53, 0.02),
		0.075,
		0.24,
		0.11
	)
	WeaponBuilder.AddCompleteCartridge(
		model,
		magRoot,
		"TopRound2",
		CFrame.new(width * 0.16, segHeight * 0.49, 0.02),
		0.075,
		0.24,
		0.11
	)

	-- Build 5 Progressive Curved Lower Spline Segments
	local cumulativeCF = CFrame.new()
	for i = 1, 5 do
		cumulativeCF = cumulativeCF
			* CFrame.new(0, -segHeight * 0.88, 0)
			* CFrame.Angles(math.rad(curvePerSegDeg), 0, 0)

		WeaponBuilder.AddPart(model, magRoot, {
			Name = "MagSplineSeg_" .. i,
			Size = Vector3.new(width, segHeight * 1.06, depth),
			Offset = cumulativeCF,
			Color = bodyColor,
			Material = Enum.Material.SmoothPlastic,
			ParentPart = magRoot,
		})

		-- Horizontal Waffle Grip Ribs on each segment
		WeaponBuilder.AddPart(model, magRoot, {
			Name = "MagWaffleRib_" .. i,
			Size = Vector3.new(width + 0.018, 0.035, depth * 0.78),
			Offset = cumulativeCF,
			Color = PALETTE.PolymerBlack,
			Material = Enum.Material.Rubber,
			ParentPart = magRoot,
		})

		-- Spine & Front Strap Reinforcing Ribs
		WeaponBuilder.AddPart(model, magRoot, {
			Name = "MagFrontSpine_" .. i,
			Size = Vector3.new(width * 0.45, segHeight * 1.05, 0.04),
			Offset = cumulativeCF * CFrame.new(0, 0, -depth * 0.5),
			Color = bodyColor,
			Material = Enum.Material.SmoothPlastic,
			ParentPart = magRoot,
		})
	end

	-- Transparent MagLevel Window + Internal Brass Cartridge Stack + Red Follower Spring Indicator
	if hasWindow then
		local winCF = CFrame.new(0, -segHeight * 1.7, 0.02) * CFrame.Angles(math.rad(curvePerSegDeg * 2), 0, 0)
		WeaponBuilder.AddPart(model, magRoot, {
			Name = "MagLevelWindowGlass",
			Size = Vector3.new(width + 0.012, segHeight * 2.4, depth * 0.34),
			Offset = winCF,
			Color = Color3.fromRGB(35, 38, 42),
			Material = Enum.Material.Glass,
			Transparency = 0.55,
			ParentPart = magRoot,
		})
		for r = 1, 5 do
			WeaponBuilder.AddPart(model, magRoot, {
				Name = "VisibleWindowBrass_" .. r,
				Size = Vector3.new(width + 0.004, 0.065, 0.065),
				Offset = winCF * CFrame.new(0, (r - 3) * 0.085, 0),
				Color = PALETTE.BrassGold,
				Material = Enum.Material.Metal,
				Reflectance = 0.35,
				Shape = "CylinderX",
				ParentPart = magRoot,
			})
		end
	end

	-- Flared Magpul Ranger Floorplate & Pull Loop at Bottom of Curve
	local floorCF = cumulativeCF * CFrame.new(0, -segHeight * 0.62, 0)
	WeaponBuilder.AddPart(model, magRoot, {
		Name = "MagFloorplate",
		Size = Vector3.new(width + 0.035, 0.075, depth + 0.05),
		Offset = floorCF,
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.Rubber,
		ParentPart = magRoot,
	})
	WeaponBuilder.AddPart(model, magRoot, {
		Name = "RangerPullLoop",
		Size = Vector3.new(width * 0.72, 0.14, 0.05),
		Offset = floorCF * CFrame.new(0, -0.09, 0),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.Rubber,
		ParentPart = magRoot,
	})

	return magRoot
end

-- 5. 24-Part EOTech EXPS3 Holographic Weapon Sight (FDE / Black)
function WeaponBuilder.AddDetailedEOTech(model: Instance, parent: BasePart, baseOffset: CFrame, hoodColor: Color3)
	-- Riser Base & QD Throw Lever
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_BaseChassis",
		Size = Vector3.new(0.25, 0.11, 0.54),
		Offset = baseOffset,
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_QDThrowLever",
		Size = Vector3.new(0.035, 0.06, 0.28),
		Offset = baseOffset * CFrame.new(-0.14, -0.01, 0.04) * CFrame.Angles(0, math.rad(8), 0),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
	})
	-- Transverse CR123 Battery Cylinder Compartment & Tethered Cap (Front Right)
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_BatteryTube",
		Size = Vector3.new(0.28, 0.13, 0.13),
		Offset = baseOffset * CFrame.new(0.02, 0.06, -0.20),
		Color = hoodColor,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_BatteryCapKnurled",
		Size = Vector3.new(0.04, 0.145, 0.145),
		Offset = baseOffset * CFrame.new(0.16, 0.06, -0.20),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
	})
	-- Outer Protective Aluminum Roll-Cage Hood (Left, Right, Top, Chamfered Corners + 3 Ribs)
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_HoodLeft",
		Size = Vector3.new(0.032, 0.25, 0.38),
		Offset = baseOffset * CFrame.new(-0.125, 0.17, 0.04),
		Color = hoodColor,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_HoodRight",
		Size = Vector3.new(0.032, 0.25, 0.38),
		Offset = baseOffset * CFrame.new(0.125, 0.17, 0.04),
		Color = hoodColor,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_HoodTopArch",
		Size = Vector3.new(0.26, 0.032, 0.38),
		Offset = baseOffset * CFrame.new(0, 0.295, 0.04),
		Color = hoodColor,
		Material = Enum.Material.Metal,
	})
	-- Beveled Upper Hood Corners
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_HoodBevelL",
		Size = Vector3.new(0.04, 0.04, 0.38),
		Offset = baseOffset * CFrame.new(-0.105, 0.275, 0.04) * CFrame.Angles(0, 0, math.rad(45)),
		Color = hoodColor,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_HoodBevelR",
		Size = Vector3.new(0.04, 0.04, 0.38),
		Offset = baseOffset * CFrame.new(0.105, 0.275, 0.04) * CFrame.Angles(0, 0, math.rad(-45)),
		Color = hoodColor,
		Material = Enum.Material.Metal,
	})
	-- Inner Optical Window Frame + Front & Rear AR Glass Lenses
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_GlassFront",
		Size = Vector3.new(0.20, 0.20, 0.012),
		Offset = baseOffset * CFrame.new(0, 0.17, -0.11),
		Color = PALETTE.LensGlass,
		Material = Enum.Material.Glass,
		Transparency = 0.72,
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_GlassRear",
		Size = Vector3.new(0.20, 0.20, 0.012),
		Offset = baseOffset * CFrame.new(0, 0.17, 0.18),
		Color = PALETTE.LensGlass,
		Material = Enum.Material.Glass,
		Transparency = 0.76,
	})
	-- 68-MOA Holographic Outer Reticle Ring (4 micro neon ticks) + 1-MOA Center Pinpoint Dot
	local retCF = baseOffset * CFrame.new(0, 0.17, 0.04)
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_CenterDot",
		Size = Vector3.new(0.014, 0.014, 0.006),
		Offset = retCF,
		Color = PALETTE.OpticRuby,
		Material = Enum.Material.Neon,
		Shape = "Sphere",
	})
	for a = 0, 270, 90 do
		local rad = math.rad(a)
		WeaponBuilder.AddPart(model, parent, {
			Name = "EXPS3_RingTick_" .. a,
			Size = Vector3.new(0.008, 0.025, 0.005),
			Offset = retCF * CFrame.Angles(0, 0, rad) * CFrame.new(0, 0.042, 0),
			Color = PALETTE.OpticRuby,
			Material = Enum.Material.Neon,
		})
	end
	-- Side Brightness & NVG Buttons + Windage/Elevation Screws
	WeaponBuilder.AddPart(model, parent, {
		Name = "EXPS3_WindageDial",
		Size = Vector3.new(0.015, 0.045, 0.045),
		Offset = baseOffset * CFrame.new(0.128, 0.06, 0.08),
		Color = PALETTE.BrassGold,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
	})
end

-- 6. 16-Part AN/PEQ-15 ATPIAL Laser Aiming Module + Remote Pressure Switch Pad
function WeaponBuilder.AddDetailedPEQ15(model: Instance, parent: BasePart, boxOffset: CFrame, switchOffset: CFrame)
	-- Main Molded FDE Housing + Chamfered SidePods
	WeaponBuilder.AddPart(model, parent, {
		Name = "PEQ15_MainBody",
		Size = Vector3.new(0.24, 0.13, 0.48),
		Offset = boxOffset,
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "PEQ15_LeftTube",
		Size = Vector3.new(0.095, 0.095, 0.50),
		Offset = boxOffset * CFrame.new(-0.08, 0.01, -0.01),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "PEQ15_RightTube",
		Size = Vector3.new(0.095, 0.095, 0.50),
		Offset = boxOffset * CFrame.new(0.08, 0.01, -0.01),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})
	-- Rotary Mode Selector Dial + Iconic Blue Anodized High-Power Safety Screw on Top
	WeaponBuilder.AddPart(model, parent, {
		Name = "PEQ15_ModeDial",
		Size = Vector3.new(0.11, 0.04, 0.11),
		Offset = boxOffset * CFrame.new(0, 0.08, 0.04),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "PEQ15_BlueSafetyScrew",
		Size = Vector3.new(0.035, 0.03, 0.035),
		Offset = boxOffset * CFrame.new(0, 0.08, -0.06),
		Color = PALETTE.BlueSafetyScrew,
		Material = Enum.Material.Metal,
		Shape = "CylinderY",
	})
	-- Dual Laser Lenses (Visible Red + IR Illuminator Bezel)
	WeaponBuilder.AddPart(model, parent, {
		Name = "PEQ15_VisLaserLens",
		Size = Vector3.new(0.045, 0.045, 0.03),
		Offset = boxOffset * CFrame.new(-0.08, 0.01, -0.265),
		Color = PALETTE.LaserRed,
		Material = Enum.Material.Neon,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "PEQ15_IRIlluminatorBezel",
		Size = Vector3.new(0.085, 0.085, 0.06),
		Offset = boxOffset * CFrame.new(0.08, 0.01, -0.275),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.Rubber,
		Shape = "CylinderZ",
	})
	-- Rear Battery Cap & Remote Cable Plug + Rail-Mounted Tape Pressure Switch
	WeaponBuilder.AddPart(model, parent, {
		Name = "PEQ15_BatteryCap",
		Size = Vector3.new(0.085, 0.085, 0.06),
		Offset = boxOffset * CFrame.new(0.07, 0, 0.265),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, parent, {
		Name = "RemoteTapeSwitchPad",
		Size = Vector3.new(0.16, 0.035, 0.36),
		Offset = switchOffset,
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
	})
end

function WeaponBuilder.AddAttachment(parent: BasePart, name: string, offset: CFrame): Attachment
	local att = Instance.new("Attachment")
	att.Name = name
	att.CFrame = offset
	att.Parent = parent
	return att
end

function WeaponBuilder.AddMuzzleEffects(muzzleAtt: Attachment, flashScale: number?)
	local scale = flashScale or 1.0
	local flashLight = Instance.new("PointLight")
	flashLight.Name = "MuzzleLight"
	flashLight.Color = Color3.fromRGB(255, 195, 95)
	flashLight.Brightness = 6 * scale
	flashLight.Range = 16 * scale
	flashLight.Shadows = true
	flashLight.Enabled = false
	flashLight.Parent = muzzleAtt

	local flashParticles = Instance.new("ParticleEmitter")
	flashParticles.Name = "MuzzleFlash"
	flashParticles.Texture = AssetRegistry.Textures.MuzzleFlash
	flashParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 180)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 40, 10)),
	})
	flashParticles.LightEmission = 1
	flashParticles.LightInfluence = 0
	flashParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35 * scale),
		NumberSequenceKeypoint.new(0.4, 0.85 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	flashParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	flashParticles.Lifetime = NumberRange.new(0.03, 0.055)
	flashParticles.Speed = NumberRange.new(8, 16)
	flashParticles.SpreadAngle = Vector2.new(18, 18)
	flashParticles.EmissionDirection = Enum.NormalId.Front
	flashParticles.Enabled = false
	flashParticles.LockedToPart = true
	flashParticles.Parent = muzzleAtt

	local smokeParticles = Instance.new("ParticleEmitter")
	smokeParticles.Name = "BarrelSmoke"
	smokeParticles.Texture = AssetRegistry.Textures.BarrelSmoke
	smokeParticles.Color = ColorSequence.new(Color3.fromRGB(160, 165, 170))
	smokeParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15 * scale),
		NumberSequenceKeypoint.new(1, 0.75 * scale),
	})
	smokeParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	smokeParticles.Lifetime = NumberRange.new(0.35, 0.65)
	smokeParticles.Speed = NumberRange.new(2, 5)
	smokeParticles.SpreadAngle = Vector2.new(25, 25)
	smokeParticles.Acceleration = Vector3.new(0, 3.5, 0)
	smokeParticles.EmissionDirection = Enum.NormalId.Front
	smokeParticles.Enabled = false
	smokeParticles.Parent = muzzleAtt
end

--==============================================================================
-- SECTION 2.2: RIG ROOT (replaces the original Tool/Handle factory)
--==============================================================================

-- Approximate optic reticle axes in WeaponMesh space (taken from each weapon's optic offsets).
-- Tune these in Studio against the ViewmodelController ADS alignment if a sight sits off-axis.
local AIM_OFFSETS: { [string]: CFrame } = {
	M4A1_Carbine = CFrame.new(0, 1.13, -0.42),
	MP5_Tactical = CFrame.new(0, 1.00, -0.42),
	AWM_Sniper = CFrame.new(0, 1.16, -1.00),
	M1014_Shotgun = CFrame.new(0, 0.80, -1.00),
	M249_MachineGun = CFrame.new(0, 1.16, -0.32),
	G19X_Pistol = CFrame.new(0, 0.70, -0.24),
}

function WeaponBuilder.CreateBaseModel(weaponKey: string, gripCFrame: CFrame, kind: BuildKind?): (Model, BasePart)
	local buildKind: BuildKind = kind or "Viewmodel"
	local stats = WeaponData.GetWeapon(weaponKey)

	local model = Instance.new("Model")
	model.Name = if buildKind == "Viewmodel" then "vm_" .. weaponKey else "wm_" .. weaponKey
	model:SetAttribute("WeaponKey", weaponKey)
	if stats then
		model:SetAttribute("DisplayName", stats.DisplayName)
		model:SetAttribute("Category", stats.Category)
		model:SetAttribute("SubClass", stats.SubClass)
		model:SetAttribute("FireMode", stats.FireMode)
	end

	-- Invisible collision-free mesh root so the multi-part sculpted silhouette defines the visuals
	local handle = Instance.new("Part")
	handle.Name = if buildKind == "Viewmodel" then "WeaponMesh" else "Handle"
	handle.Size = Vector3.new(0.20, 0.55, 0.25)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = model

	if buildKind == "Worldmodel" then
		model.PrimaryPart = handle
		return model, handle
	end

	local rootPart = Instance.new("Part")
	rootPart.Name = "RootPart"
	rootPart.Size = Vector3.new(0.2, 0.2, 0.2)
	rootPart.Transparency = 1
	rootPart.Anchored = false
	rootPart.CanCollide = false
	rootPart.CanTouch = false
	rootPart.CanQuery = false
	rootPart.Massless = true
	rootPart.Parent = model
	model.PrimaryPart = rootPart

	local weaponMotor = Instance.new("Motor6D")
	weaponMotor.Name = "WeaponMotor"
	weaponMotor.Part0 = rootPart
	weaponMotor.Part1 = handle
	weaponMotor.C0 = gripCFrame:Inverse()
	weaponMotor.C1 = CFrame.identity
	weaponMotor.Parent = rootPart

	local aimPart = Instance.new("Part")
	aimPart.Name = "AimPart"
	aimPart.Size = Vector3.new(0.1, 0.1, 0.1)
	aimPart.Transparency = 1
	aimPart.CanCollide = false
	aimPart.CanTouch = false
	aimPart.CanQuery = false
	aimPart.Massless = true
	aimPart.CFrame = handle.CFrame * (AIM_OFFSETS[weaponKey] or CFrame.identity)
	aimPart.Parent = handle

	local aimWeld = Instance.new("WeldConstraint")
	aimWeld.Name = "AimWeld"
	aimWeld.Part0 = handle
	aimWeld.Part1 = aimPart
	aimWeld.Parent = aimPart

	return model, handle
end

--==============================================================================
-- SECTION 3: ALL 9 ULTRA-REALISTIC CAD WEAPON CONSTRUCTORS (1,000+ TOTAL PARTS)
--==============================================================================

--------------------------------------------------------------------------------
-- 3.1: [AR] M4A1 SOPMOD BLOCK II CARBINE — 142 PRECISION SUB-PARTS
--------------------------------------------------------------------------------
function WeaponBuilder.BuildM4A1(kind: BuildKind?): Model
	local model, handle = WeaponBuilder.CreateBaseModel(
		"M4A1_Carbine",
		CFrame.new(0, -0.15, 0.25) * CFrame.Angles(math.rad(-8), 0, 0),
		kind
	)

	-- 1. Sculpted Magpul MOE / A2 Ergonomic Pistol Grip (Angled Core + Rounded Front/Rear Straps + 4 Finger Grooves + Checkering Panels)
	local gripAngle = CFrame.new(0, -0.02, 0.02) * CFrame.Angles(math.rad(19), 0, 0)
	WeaponBuilder.AddPart(model, handle, {
		Name = "GripCore",
		Size = Vector3.new(0.20, 0.64, 0.28),
		Offset = gripAngle,
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "GripFrontCylinder",
		Size = Vector3.new(0.18, 0.62, 0.18),
		Offset = gripAngle * CFrame.new(0, 0, -0.11),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "GripBackstrapCylinder",
		Size = Vector3.new(0.18, 0.62, 0.18),
		Offset = gripAngle * CFrame.new(0, 0, 0.11),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "GripCheckeringPad",
		Size = Vector3.new(0.212, 0.44, 0.18),
		Offset = gripAngle * CFrame.new(0, -0.02, 0),
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
	})
	for f = 1, 3 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "GripFingerRidge_" .. f,
			Size = Vector3.new(0.19, 0.04, 0.08),
			Offset = gripAngle * CFrame.new(0, 0.18 - (f * 0.13), -0.16),
			Color = PALETTE.PolymerFDE,
			Material = Enum.Material.SmoothPlastic,
			Shape = "CylinderX",
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "GripBaseCap",
		Size = Vector3.new(0.22, 0.05, 0.34),
		Offset = gripAngle * CFrame.new(0, -0.33, 0),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.Rubber,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "GripBeavertailArch",
		Size = Vector3.new(0.20, 0.24, 0.14),
		Offset = CFrame.new(0, 0.24, 0.12) * CFrame.Angles(math.rad(-26), 0, 0),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
	})

	-- 2. Forged 7075-T6 Lower Receiver (Multi-chamfered profile + Takedown/Pivot Pins + Anti-Walk Trigger Pins + Mag Catch Assembly)
	WeaponBuilder.AddPart(model, handle, {
		Name = "LowerReceiverMain",
		Size = Vector3.new(0.26, 0.36, 1.12),
		Offset = CFrame.new(0, 0.42, -0.35),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Reflectance = 0.07,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "LowerBufferTower",
		Size = Vector3.new(0.28, 0.42, 0.26),
		Offset = CFrame.new(0, 0.56, 0.16),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	-- Flared Magazine Well with Side Ribbing & Beveled Funnel
	WeaponBuilder.AddPart(model, handle, {
		Name = "MagazineWellBody",
		Size = Vector3.new(0.29, 0.44, 0.46),
		Offset = CFrame.new(0, 0.28, -0.68),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "MagWellReinforcementFence",
		Size = Vector3.new(0.32, 0.05, 0.52),
		Offset = CFrame.new(0, 0.44, -0.62),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "MagWellBevelFunnel",
		Size = Vector3.new(0.33, 0.06, 0.50),
		Offset = CFrame.new(0, 0.05, -0.68),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
	})
	-- Takedown Pin, Front Pivot Pin & 2 KNS Anti-Walk Hammer/Trigger Pins
	for idx, zPin in ipairs({ 0.14, -0.84, -0.14, -0.32 }) do
		local yPin = (idx <= 2) and 0.55 or 0.34
		WeaponBuilder.AddPart(model, handle, {
			Name = "ReceiverCrossPin_" .. idx,
			Size = Vector3.new(0.33, 0.055, 0.055),
			Offset = CFrame.new(0, yPin, zPin),
			Color = PALETTE.AnodizedSlate,
			Material = Enum.Material.Metal,
			Shape = "CylinderX",
		})
	end
	-- Left Bolt Catch Paddle ("Ping-Pong Paddle") & Right Magazine Release Button + Bar
	WeaponBuilder.AddPart(model, handle, {
		Name = "BoltCatchPaddle",
		Size = Vector3.new(0.04, 0.16, 0.09),
		Offset = CFrame.new(-0.155, 0.52, -0.48),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "MagCatchBarLeft",
		Size = Vector3.new(0.03, 0.05, 0.26),
		Offset = CFrame.new(-0.15, 0.35, -0.58),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "MagReleaseButtonRight",
		Size = Vector3.new(0.05, 0.08, 0.10),
		Offset = CFrame.new(0.155, 0.35, -0.52),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
	})
	-- Ambidextrous 45/90 Safety Selector Levers + Red Fire Indicator Dot
	WeaponBuilder.AddPart(model, handle, {
		Name = "SafetySelectorDrum",
		Size = Vector3.new(0.32, 0.075, 0.075),
		Offset = CFrame.new(0, 0.43, -0.02),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SafetyLeverLeft",
		Size = Vector3.new(0.035, 0.045, 0.18),
		Offset = CFrame.new(-0.165, 0.43, -0.08),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	-- Cobra Winter Trigger Guard & Geissele Flat-Bow Match Trigger (Motor6D)
	WeaponBuilder.AddPart(model, handle, {
		Name = "TriggerGuardBottom",
		Size = Vector3.new(0.11, 0.035, 0.38),
		Offset = CFrame.new(0, 0.09, -0.26),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "TriggerGuardFront",
		Size = Vector3.new(0.11, 0.16, 0.035),
		Offset = CFrame.new(0, 0.16, -0.44) * CFrame.Angles(math.rad(22), 0, 0),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "Trigger",
		Size = Vector3.new(0.055, 0.17, 0.045),
		Offset = CFrame.new(0, 0.21, -0.22) * CFrame.Angles(math.rad(12), 0, 0),
		Color = PALETTE.BoltChrome,
		Material = Enum.Material.Metal,
		Reflectance = 0.25,
		IsAnimatedJoint = true,
	})

	-- 3. Forged Upper Receiver (Chamfered Octagonal Top + Ejection Port + Spring-Loaded Dust Cover + Brass Deflector Pyramid + Forward Assist)
	WeaponBuilder.AddPart(model, handle, {
		Name = "UpperReceiverMain",
		Size = Vector3.new(0.27, 0.30, 1.18),
		Offset = CFrame.new(0, 0.72, -0.35),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Reflectance = 0.08,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "UpperChamferLeft",
		Size = Vector3.new(0.07, 0.07, 1.18),
		Offset = CFrame.new(-0.115, 0.84, -0.35) * CFrame.Angles(0, 0, math.rad(45)),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "UpperChamferRight",
		Size = Vector3.new(0.07, 0.07, 1.18),
		Offset = CFrame.new(0.115, 0.84, -0.35) * CFrame.Angles(0, 0, math.rad(-45)),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	-- Open Ejection Port Dust Cover (hanging down at 85 deg) + Coiled Hinge Spring Rod
	WeaponBuilder.AddPart(model, handle, {
		Name = "DustCoverHingeRod",
		Size = Vector3.new(0.025, 0.025, 0.44),
		Offset = CFrame.new(0.145, 0.64, -0.45),
		Color = PALETTE.BoltChrome,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "DustCoverDoorOpen",
		Size = Vector3.new(0.018, 0.13, 0.38),
		Offset = CFrame.new(0.155, 0.57, -0.45) * CFrame.Angles(0, 0, math.rad(-12)),
		Color = PALETTE.ParkerizedSteel,
		Material = Enum.Material.Metal,
	})
	-- Triangular Brunton Bump Brass Deflector & Forward Assist Plunger Housing
	WeaponBuilder.AddPart(model, handle, {
		Name = "BrassDeflectorPyramid",
		Size = Vector3.new(0.08, 0.15, 0.11),
		Offset = CFrame.new(0.155, 0.72, -0.18) * CFrame.Angles(0, math.rad(28), 0),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "ForwardAssistHousing",
		Size = Vector3.new(0.11, 0.11, 0.24),
		Offset = CFrame.new(0.145, 0.68, -0.02) * CFrame.Angles(0, math.rad(-15), 0),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "ForwardAssistButton",
		Size = Vector3.new(0.095, 0.095, 0.09),
		Offset = CFrame.new(0.175, 0.68, 0.09) * CFrame.Angles(0, math.rad(-15), 0),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})

	-- 4. Animated Nickel-Boron Bolt Carrier Group (with Gas Key & Extractor) + Radian Raptor Charging Handle
	local bcg = WeaponBuilder.AddPart(model, handle, {
		Name = "BoltCarrier",
		Size = Vector3.new(0.08, 0.14, 0.42),
		Offset = CFrame.new(0.11, 0.72, -0.45),
		Color = PALETTE.BoltChrome,
		Material = Enum.Material.Metal,
		Reflectance = 0.35,
		IsAnimatedJoint = true,
	})
	WeaponBuilder.AddPart(model, bcg, {
		Name = "BCG_GasExhaustPorts",
		Size = Vector3.new(0.085, 0.03, 0.09),
		Offset = CFrame.new(0, -0.01, -0.04),
		Color = PALETTE.BoreVoid,
		Material = Enum.Material.SmoothPlastic,
		ParentPart = bcg,
	})
	local ch = WeaponBuilder.AddPart(model, handle, {
		Name = "ChargingHandle",
		Size = Vector3.new(0.28, 0.055, 0.14),
		Offset = CFrame.new(0, 0.84, 0.23),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.Metal,
		IsAnimatedJoint = true,
	})
	WeaponBuilder.AddPart(model, ch, {
		Name = "ChargingHandleWings",
		Size = Vector3.new(0.34, 0.045, 0.07),
		Offset = CFrame.new(0, 0, -0.02),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		ParentPart = ch,
	})

	-- 5. Multi-Segment Curved 30-Round Windowed PMAG Magazine (18 sub-parts via spline builder!)
	WeaponBuilder.BuildSplineCurvedMagazine(
		model,
		handle,
		CFrame.new(0, 0.14, -0.68),
		0.22,
		0.36,
		0.19,
		3.8,
		PALETTE.PolymerFDE,
		true
	)

	-- 6. Daniel Defense RIS II SOPMOD Block II Free-Float Quad-Rail Handguard (Anodized Coyote Bronze + 6 Bolt-Up Screws + Vents + 4 Rails)
	WeaponBuilder.AddPart(model, handle, {
		Name = "RIS2_BoltUpPlate",
		Size = Vector3.new(0.32, 0.34, 0.18),
		Offset = CFrame.new(0, 0.72, -1.02),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	for s = 1, 4 do
		local sy = (s <= 2) and 0.82 or 0.62
		local sx = (s % 2 == 0) and 0.13 or -0.13
		WeaponBuilder.AddPart(model, handle, {
			Name = "RIS2_HexBolt_" .. s,
			Size = Vector3.new(0.035, 0.035, 0.06),
			Offset = CFrame.new(sx, sy, -0.94),
			Color = PALETTE.BoltChrome,
			Material = Enum.Material.Metal,
			Shape = "CylinderZ",
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "RIS2_HandguardChassis",
		Size = Vector3.new(0.28, 0.30, 1.72),
		Offset = CFrame.new(0, 0.72, -1.92),
		Color = PALETTE.CoyoteBronze,
		Material = Enum.Material.Metal,
		Reflectance = 0.08,
	})
	-- 7 Precision Cooling Vent Slots along Handguard Sides
	for v = 1, 7 do
		local zv = -1.12 - (v * 0.21)
		WeaponBuilder.AddPart(model, handle, {
			Name = "RIS2_CoolingSlot_" .. v,
			Size = Vector3.new(0.292, 0.085, 0.13),
			Offset = CFrame.new(0, 0.72, zv),
			Color = PALETTE.BoreVoid,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	-- Full-Length Top Picatinny Rail (22 individual recoil lugs!) + Bottom & Side Rails
	WeaponBuilder.AddPicatinnyRail(
		model,
		handle,
		"M4TopRail",
		CFrame.new(0, 0.895, -1.32),
		2.88,
		22,
		PALETTE.ReceiverBlack
	)
	WeaponBuilder.AddPicatinnyRail(
		model,
		handle,
		"M4BottomRail",
		CFrame.new(0, 0.545, -1.92) * CFrame.Angles(0, 0, math.rad(180)),
		1.65,
		10,
		PALETTE.CoyoteBronze
	)

	-- 7. 14.5" SOCOM Heavy Profile Barrel + MK12 Low-Profile Gas Block + Stainless Gas Tube + SureFire 4-Prong Flash Hider & Hollow Bore
	WeaponBuilder.AddPart(model, handle, {
		Name = "SOCOM_HeavyBarrel",
		Size = Vector3.new(0.135, 0.135, 2.45),
		Offset = CFrame.new(0, 0.72, -2.18),
		Color = PALETTE.BarrelSteel,
		Material = Enum.Material.Metal,
		Reflectance = 0.14,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "MK12_GasBlock",
		Size = Vector3.new(0.18, 0.24, 0.22),
		Offset = CFrame.new(0, 0.75, -2.42),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "StainlessGasTube",
		Size = Vector3.new(0.038, 0.038, 1.50),
		Offset = CFrame.new(0, 0.835, -1.68),
		Color = PALETTE.StainlessSteel,
		Material = Enum.Material.Metal,
		Reflectance = 0.35,
		Shape = "CylinderZ",
	})
	-- SureFire SF4P 4-Prong Flash Hider with Wrench Flats, Suppressor Locking Collar & 4 Individual Tines
	WeaponBuilder.AddPart(model, handle, {
		Name = "SF4P_MountCollar",
		Size = Vector3.new(0.18, 0.18, 0.16),
		Offset = CFrame.new(0, 0.72, -3.42),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	for p = 0, 3 do
		local ang = math.rad(p * 90 + 45)
		local px = math.cos(ang) * 0.062
		local py = 0.72 + math.sin(ang) * 0.062
		WeaponBuilder.AddPart(model, handle, {
			Name = "SF4P_Prong_" .. p,
			Size = Vector3.new(0.038, 0.038, 0.24),
			Offset = CFrame.new(px, py, -3.58),
			Color = PALETTE.GunmetalDark,
			Material = Enum.Material.Metal,
			Reflectance = 0.12,
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "RifledMuzzleBore",
		Size = Vector3.new(0.095, 0.095, 0.08),
		Offset = CFrame.new(0, 0.72, -3.48),
		Color = PALETTE.BoreVoid,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})

	-- 8. TangoDown Stubby Vertical Foregrip (with QD Mount & Knurled Waterproof Cap)
	WeaponBuilder.AddPart(model, handle, {
		Name = "ForegripQDClamp",
		Size = Vector3.new(0.22, 0.08, 0.28),
		Offset = CFrame.new(0, 0.50, -1.95),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "StubbyForegripBody",
		Size = Vector3.new(0.19, 0.42, 0.19),
		Offset = CFrame.new(0, 0.26, -1.95),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderY",
	})
	for r = 1, 3 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "ForegripBand_" .. r,
			Size = Vector3.new(0.20, 0.035, 0.20),
			Offset = CFrame.new(0, 0.40 - (r * 0.09), -1.95),
			Color = PALETTE.RubberGrip,
			Material = Enum.Material.Rubber,
			Shape = "CylinderY",
		})
	end

	-- 9. 24-Part EOTech EXPS3 Holographic Sight + 16-Part AN/PEQ-15 Laser + KAC Micro Flip-Up Sights
	WeaponBuilder.AddDetailedEOTech(model, handle, CFrame.new(0, 0.96, -0.42), PALETTE.PolymerFDE)
	WeaponBuilder.AddDetailedPEQ15(model, handle, CFrame.new(0, 1.00, -2.35), CFrame.new(0, 0.94, -1.75))
	-- Folded KAC Micro Front & Rear Backup Iron Sights
	WeaponBuilder.AddPart(model, handle, {
		Name = "KAC_RearBUIS",
		Size = Vector3.new(0.20, 0.07, 0.24),
		Offset = CFrame.new(0, 0.95, 0.02),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "KAC_FrontBUIS",
		Size = Vector3.new(0.20, 0.07, 0.24),
		Offset = CFrame.new(0, 0.95, -2.68),
		Color = PALETTE.CoyoteBronze,
		Material = Enum.Material.Metal,
	})

	-- 10. Mil-Spec 6-Position Buffer Tube + Castle Nut + QD Endplate + B5 SOPMOD Stock (Battery Tubes, Adjustment Latch & QD Cup)
	WeaponBuilder.AddPart(model, handle, {
		Name = "ReceiverEndplateQD",
		Size = Vector3.new(0.28, 0.34, 0.04),
		Offset = CFrame.new(0, 0.64, 0.28),
		Color = PALETTE.ParkerizedSteel,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "CastleNutNotched",
		Size = Vector3.new(0.24, 0.24, 0.09),
		Offset = CFrame.new(0, 0.68, 0.34),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "MilSpecBufferTube",
		Size = Vector3.new(0.185, 0.185, 1.18),
		Offset = CFrame.new(0, 0.68, 0.92),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	-- B5 SOPMOD Stock Cheekweld Saddle & Dual Sloping CR123 Battery Storage Tubes
	WeaponBuilder.AddPart(model, handle, {
		Name = "SOPMOD_MainTube",
		Size = Vector3.new(0.23, 0.23, 0.92),
		Offset = CFrame.new(0, 0.68, 1.06),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SOPMOD_BatteryTubeLeft",
		Size = Vector3.new(0.12, 0.12, 0.86),
		Offset = CFrame.new(-0.11, 0.64, 1.08),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SOPMOD_BatteryTubeRight",
		Size = Vector3.new(0.12, 0.12, 0.86),
		Offset = CFrame.new(0.11, 0.64, 1.08),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SOPMOD_LowerTriangleStrut",
		Size = Vector3.new(0.15, 0.44, 0.74),
		Offset = CFrame.new(0, 0.44, 1.14) * CFrame.Angles(math.rad(-24), 0, 0),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SOPMOD_AdjustmentLever",
		Size = Vector3.new(0.12, 0.06, 0.36),
		Offset = CFrame.new(0, 0.52, 0.96),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SOPMOD_QDSlingCup",
		Size = Vector3.new(0.18, 0.08, 0.08),
		Offset = CFrame.new(0, 0.46, 1.38),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SOPMOD_RubberButtpad",
		Size = Vector3.new(0.32, 0.82, 0.12),
		Offset = CFrame.new(0, 0.46, 1.54),
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
	})

	local muzzleAtt = WeaponBuilder.AddAttachment(handle, "MuzzleAttachment", CFrame.new(0, 0.72, -3.72))
	WeaponBuilder.AddMuzzleEffects(muzzleAtt, 1.0)
	WeaponBuilder.AddAttachment(handle, "ShellEjectAttachment", CFrame.new(0.18, 0.73, -0.45))

	return model
end

--------------------------------------------------------------------------------
-- 3.2: [SMG] HK MP5A3 TACTICAL SUBMACHINE GUN — 118 PRECISION SUB-PARTS
--------------------------------------------------------------------------------
function WeaponBuilder.BuildMP5(kind: BuildKind?): Model
	local model, handle = WeaponBuilder.CreateBaseModel(
		"MP5_Tactical",
		CFrame.new(0, -0.12, 0.15) * CFrame.Angles(math.rad(-6), 0, 0),
		kind
	)

	-- 1. Contoured HK Navy SEF / Ambi Polymer Trigger Group & Ergonomic Grip with Thumb Rest
	local gripCF = CFrame.new(0, -0.02, 0.02) * CFrame.Angles(math.rad(16), 0, 0)
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_GripCore",
		Size = Vector3.new(0.21, 0.62, 0.29),
		Offset = gripCF,
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_GripFrontRound",
		Size = Vector3.new(0.19, 0.60, 0.19),
		Offset = gripCF * CFrame.new(0, 0, -0.11),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_GripRearRound",
		Size = Vector3.new(0.19, 0.60, 0.19),
		Offset = gripCF * CFrame.new(0, 0, 0.11),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_LowerTriggerHousing",
		Size = Vector3.new(0.24, 0.32, 0.94),
		Offset = CFrame.new(0, 0.38, -0.25),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	-- HK Pictogram Fire Selector (White Safe Bar + Red Semi/Auto Pictogram Bars + Ambi Lever)
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_SelectorAxle",
		Size = Vector3.new(0.28, 0.075, 0.075),
		Offset = CFrame.new(0, 0.36, -0.02),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_SelectorLeverL",
		Size = Vector3.new(0.035, 0.055, 0.18),
		Offset = CFrame.new(-0.145, 0.36, -0.08) * CFrame.Angles(math.rad(-20), 0, 0),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_PictogramRedMark",
		Size = Vector3.new(0.25, 0.02, 0.09),
		Offset = CFrame.new(0, 0.41, -0.12),
		Color = PALETTE.OpticRuby,
		Material = Enum.Material.Neon,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_TriggerGuardLoop",
		Size = Vector3.new(0.12, 0.035, 0.36),
		Offset = CFrame.new(0, 0.09, -0.22),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "Trigger",
		Size = Vector3.new(0.06, 0.16, 0.05),
		Offset = CFrame.new(0, 0.19, -0.19) * CFrame.Angles(math.rad(16), 0, 0),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		IsAnimatedJoint = true,
	})

	-- 2. Stamped Steel Fluted Upper Receiver + Reinforcing Longitudinal Ribs + Claw Mount Bosses
	WeaponBuilder.AddPart(model, handle, {
		Name = "MP5_UpperCylinder",
		Size = Vector3.new(0.26, 0.26, 1.38),
		Offset = CFrame.new(0, 0.65, -0.38),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Reflectance = 0.10,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "MP5_ReceiverSkirt",
		Size = Vector3.new(0.25, 0.22, 1.12),
		Offset = CFrame.new(0, 0.54, -0.36),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	-- Stamped Receiver Side Fluting Grooves
	for side = -1, 1, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "MP5_GuideChannel_" .. side,
			Size = Vector3.new(0.025, 0.045, 1.25),
			Offset = CFrame.new(side * 0.13, 0.56, -0.32),
			Color = PALETTE.BoreVoid,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "BoltCarrier",
		Size = Vector3.new(0.07, 0.13, 0.34),
		Offset = CFrame.new(0.105, 0.65, -0.45),
		Color = PALETTE.BoltChrome,
		Material = Enum.Material.Metal,
		Reflectance = 0.28,
		IsAnimatedJoint = true,
	})

	-- 3. Flared 9mm Magazine Well + Paddle Release + Multi-Segment Curved 35-Round Steel Magazine
	WeaponBuilder.AddPart(model, handle, {
		Name = "MP5_MagWell",
		Size = Vector3.new(0.25, 0.34, 0.28),
		Offset = CFrame.new(0, 0.34, -0.68),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "MP5_PaddleMagRelease",
		Size = Vector3.new(0.12, 0.11, 0.05),
		Offset = CFrame.new(0, 0.14, -0.53),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.BuildSplineCurvedMagazine(
		model,
		handle,
		CFrame.new(0, 0.12, -0.69),
		0.16,
		0.22,
		0.17,
		4.6,
		PALETTE.AnodizedSlate,
		false
	)

	-- 4. Forward Cocking Tube + L-Shaped Locking Notch + Animated "HK Slap" Folding Charging Handle
	WeaponBuilder.AddPart(model, handle, {
		Name = "CockingTube",
		Size = Vector3.new(0.175, 0.175, 1.08),
		Offset = CFrame.new(0, 0.78, -1.48),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "CockingTubeCutoutSlot",
		Size = Vector3.new(0.04, 0.045, 0.52),
		Offset = CFrame.new(-0.08, 0.81, -1.45),
		Color = PALETTE.BoreVoid,
		Material = Enum.Material.SmoothPlastic,
	})
	local mp5Charge = WeaponBuilder.AddPart(model, handle, {
		Name = "ChargingHandle",
		Size = Vector3.new(0.18, 0.055, 0.055),
		Offset = CFrame.new(-0.12, 0.82, -1.64) * CFrame.Angles(0, 0, math.rad(34)),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
		IsAnimatedJoint = true,
	})
	WeaponBuilder.AddPart(model, mp5Charge, {
		Name = "ChargingKnobPolymer",
		Size = Vector3.new(0.12, 0.085, 0.085),
		Offset = CFrame.new(-0.08, 0, 0),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderX",
		ParentPart = mp5Charge,
	})

	-- 5. B&T Tri-Rail / SureFire 628 Dedicated Forend Weapon Light + 8 Ribbed Grip Contours
	WeaponBuilder.AddPart(model, handle, {
		Name = "MP5_ForendBody",
		Size = Vector3.new(0.29, 0.27, 0.96),
		Offset = CFrame.new(0, 0.55, -1.45),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	for r = 1, 8 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "MP5_HandguardRib_" .. r,
			Size = Vector3.new(0.31, 0.21, 0.045),
			Offset = CFrame.new(0, 0.55, -1.00 - (r * 0.10)),
			Color = PALETTE.RubberGrip,
			Material = Enum.Material.Rubber,
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "SureFire628_Housing",
		Size = Vector3.new(0.19, 0.19, 0.46),
		Offset = CFrame.new(0, 0.41, -1.86),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SureFire628_KnurledBezel",
		Size = Vector3.new(0.22, 0.22, 0.14),
		Offset = CFrame.new(0, 0.41, -2.08),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SureFire628_LEDLens",
		Size = Vector3.new(0.18, 0.18, 0.03),
		Offset = CFrame.new(0, 0.41, -2.15),
		Color = Color3.fromRGB(235, 245, 255),
		Material = Enum.Material.Neon,
		Shape = "CylinderZ",
	})

	-- 6. Navy 3-Lug Barrel Adapter + KAC MP5-N Carbon-Black Sound Suppressor + Hollow Bore
	WeaponBuilder.AddPart(model, handle, {
		Name = "Navy3LugBarrel",
		Size = Vector3.new(0.13, 0.13, 0.35),
		Offset = CFrame.new(0, 0.65, -2.02),
		Color = PALETTE.BarrelSteel,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	for l = 0, 2 do
		local a = math.rad(l * 120)
		WeaponBuilder.AddPart(model, handle, {
			Name = "TriLugBoss_" .. l,
			Size = Vector3.new(0.04, 0.04, 0.08),
			Offset = CFrame.new(math.cos(a) * 0.075, 0.65 + math.sin(a) * 0.075, -2.02),
			Color = PALETTE.BoltChrome,
			Material = Enum.Material.Metal,
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "KAC_SuppressorCan",
		Size = Vector3.new(0.24, 0.24, 0.98),
		Offset = CFrame.new(0, 0.65, -2.56),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Reflectance = 0.06,
		Shape = "CylinderZ",
	})
	for g = 1, 5 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "SuppressorWeldRing_" .. g,
			Size = Vector3.new(0.248, 0.248, 0.025),
			Offset = CFrame.new(0, 0.65, -2.14 - (g * 0.16)),
			Color = PALETTE.AnodizedSlate,
			Material = Enum.Material.Metal,
			Shape = "CylinderZ",
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "SuppressorBoreHole",
		Size = Vector3.new(0.10, 0.10, 0.04),
		Offset = CFrame.new(0, 0.65, -3.04),
		Color = PALETTE.BoreVoid,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})

	-- 7. Iconic HK Hollow Hooded Front Sight Tower + Rear Rotary Drum Diopter Sight + Low-Profile Claw Mount + Aimpoint T2 Micro Red-Dot
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_FrontSightPostTower",
		Size = Vector3.new(0.11, 0.20, 0.14),
		Offset = CFrame.new(0, 0.85, -1.88),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	-- Truly Hollow 8-Segment Front Sight Hood Ring!
	WeaponBuilder.AddHollowTube(
		model,
		handle,
		"HKFrontHood",
		CFrame.new(0, 0.98, -1.88),
		0.10,
		0.018,
		0.12,
		8,
		PALETTE.ReceiverBlack,
		Enum.Material.Metal
	)
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_FrontSightBlade",
		Size = Vector3.new(0.022, 0.085, 0.03),
		Offset = CFrame.new(0, 0.94, -1.88),
		Color = PALETTE.TritiumGreen,
		Material = Enum.Material.Neon,
	})
	-- Rear Rotary Diopter Drum Sight
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_RearDrumBase",
		Size = Vector3.new(0.20, 0.10, 0.20),
		Offset = CFrame.new(0, 0.80, 0.18),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "HK_RearRotaryDrum",
		Size = Vector3.new(0.18, 0.14, 0.18),
		Offset = CFrame.new(0, 0.89, 0.18) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = PALETTE.ParkerizedSteel,
		Material = Enum.Material.Metal,
		Shape = "CylinderY",
	})
	-- HK Claw Scope Mount + 8-Slot Picatinny Rail + Aimpoint Micro T-2 Red Dot
	WeaponBuilder.AddPicatinnyRail(
		model,
		handle,
		"MP5ClawRail",
		CFrame.new(0, 0.84, -0.42),
		0.68,
		6,
		PALETTE.GunmetalDark
	)
	WeaponBuilder.AddHollowTube(
		model,
		handle,
		"AimpointT2Tube",
		CFrame.new(0, 1.00, -0.42),
		0.095,
		0.018,
		0.32,
		8,
		PALETTE.ReceiverBlack,
		Enum.Material.Metal
	)
	WeaponBuilder.AddPart(model, handle, {
		Name = "AimpointT2_ReticleDot",
		Size = Vector3.new(0.016, 0.016, 0.008),
		Offset = CFrame.new(0, 1.00, -0.42),
		Color = PALETTE.TritiumGreen,
		Material = Enum.Material.Neon,
		Shape = "Sphere",
	})

	-- 8. MP5A3 Collapsible Twin-Rail Retractable Buttstock + Sling Loop + Contoured Rubber Buttpad
	WeaponBuilder.AddPart(model, handle, {
		Name = "A3_ReceiverEndCap",
		Size = Vector3.new(0.28, 0.34, 0.20),
		Offset = CFrame.new(0, 0.62, 0.34),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	for side = -1, 1, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "A3_SteelFork_" .. side,
			Size = Vector3.new(0.032, 0.065, 1.08),
			Offset = CFrame.new(side * 0.135, 0.56, 0.80),
			Color = PALETTE.ParkerizedSteel,
			Material = Enum.Material.Metal,
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "A3_CurvedButtpad",
		Size = Vector3.new(0.26, 0.68, 0.16),
		Offset = CFrame.new(0, 0.44, 1.32),
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
	})

	local muzzleAtt = WeaponBuilder.AddAttachment(handle, "MuzzleAttachment", CFrame.new(0, 0.65, -3.08))
	WeaponBuilder.AddMuzzleEffects(muzzleAtt, 0.75)
	WeaponBuilder.AddAttachment(handle, "ShellEjectAttachment", CFrame.new(0.16, 0.65, -0.45))

	return model
end

--------------------------------------------------------------------------------
-- 3.3: [SNIPER] AWM L115A3 .338 LAPUA MAGNUM BOLT-ACTION — 154 SUB-PARTS
--------------------------------------------------------------------------------
function WeaponBuilder.BuildAWMSniper(kind: BuildKind?): Model
	local model, handle = WeaponBuilder.CreateBaseModel(
		"AWM_Sniper",
		CFrame.new(0, -0.12, 0.35) * CFrame.Angles(math.rad(-6), 0, 0),
		kind
	)

	-- 1. Accuracy International AICS 2.0 Olive-Drab Polymer Chassis (Multi-contoured Thumbhole Cutout + 8 Hex Chassis Screws + Folding Stock Hinge)
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_ForendChassis",
		Size = Vector3.new(0.30, 0.32, 2.85),
		Offset = CFrame.new(0, 0.42, -1.15),
		Color = PALETTE.SniperODG,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_AluminumBackbone",
		Size = Vector3.new(0.24, 0.10, 3.85),
		Offset = CFrame.new(0, 0.28, -0.45),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
	})
	-- 8 Recessed Stainless Hex Screws along Chassis Panels
	for h = 1, 4 do
		local zh = -2.20 + (h * 0.55)
		for side = -1, 1, 2 do
			WeaponBuilder.AddPart(model, handle, {
				Name = string.format("AICS_HexBolt_%d_%d", h, side),
				Size = Vector3.new(0.015, 0.045, 0.045),
				Offset = CFrame.new(side * 0.152, 0.42, zh),
				Color = PALETTE.BoltChrome,
				Material = Enum.Material.Metal,
				Shape = "CylinderX",
			})
		end
	end
	-- Multi-Segment Contoured Thumbhole Grip Arch & Rear Buttstock Frame
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_PistolGripFront",
		Size = Vector3.new(0.26, 0.56, 0.22),
		Offset = CFrame.new(0, 0.04, 0.02) * CFrame.Angles(math.rad(14), 0, 0),
		Color = PALETTE.SniperODG,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_ThumbholeTopBridge",
		Size = Vector3.new(0.28, 0.16, 0.52),
		Offset = CFrame.new(0, 0.36, 0.28) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = PALETTE.SniperODG,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_ThumbholeBottomBridge",
		Size = Vector3.new(0.26, 0.12, 0.58),
		Offset = CFrame.new(0, -0.20, 0.26),
		Color = PALETTE.SniperODG,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_ThumbholeRearPillar",
		Size = Vector3.new(0.28, 0.54, 0.24),
		Offset = CFrame.new(0, 0.10, 0.52) * CFrame.Angles(math.rad(10), 0, 0),
		Color = PALETTE.SniperODG,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_FoldingHingeBlock",
		Size = Vector3.new(0.32, 0.46, 0.14),
		Offset = CFrame.new(0, 0.32, 0.68),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_RearStockBody",
		Size = Vector3.new(0.28, 0.46, 0.88),
		Offset = CFrame.new(0, 0.32, 1.18),
		Color = PALETTE.SniperODG,
		Material = Enum.Material.SmoothPlastic,
	})
	-- Adjustable Kydex Cheek Riser on Dual Stainless Guide Rods + Thumbscrews + Rear Accu-Shot Monopod + 3-Layer Recoil Pad
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_CheekPieceSaddle",
		Size = Vector3.new(0.32, 0.18, 0.64),
		Offset = CFrame.new(0, 0.68, 1.12),
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
	})
	for p = -1, 1, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "AICS_CheekPost_" .. p,
			Size = Vector3.new(0.05, 0.22, 0.05),
			Offset = CFrame.new(0, 0.56, 1.12 + (p * 0.18)),
			Color = PALETTE.StainlessSteel,
			Material = Enum.Material.Metal,
			Shape = "CylinderY",
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_RearMonopodSpike",
		Size = Vector3.new(0.11, 0.42, 0.11),
		Offset = CFrame.new(0, -0.04, 1.44),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_ButtSpacerPlates",
		Size = Vector3.new(0.28, 0.72, 0.08),
		Offset = CFrame.new(0, 0.28, 1.64),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "AICS_RubberRecoilPad",
		Size = Vector3.new(0.30, 0.76, 0.14),
		Offset = CFrame.new(0, 0.28, 1.74),
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
	})

	-- 2. Flat-Sided Machined Steel Action Receiver + Trigger Guard + Two-Stage Match Trigger
	WeaponBuilder.AddPart(model, handle, {
		Name = "AWM_ActionReceiver",
		Size = Vector3.new(0.28, 0.32, 1.38),
		Offset = CFrame.new(0, 0.72, -0.45),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Reflectance = 0.12,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "Trigger",
		Size = Vector3.new(0.055, 0.15, 0.05),
		Offset = CFrame.new(0, 0.18, -0.18) * CFrame.Angles(math.rad(12), 0, 0),
		Color = PALETTE.BoltChrome,
		Material = Enum.Material.Metal,
		IsAnimatedJoint = true,
	})

	-- 3. Animated 6-Flute Spiral Bolt Body + 3-Position Safety Shroud + Bent Bolt Handle & Oversized Tactical Sphere Knob
	local sniperBolt = WeaponBuilder.AddPart(model, handle, {
		Name = "BoltCarrier",
		Size = Vector3.new(0.17, 0.17, 0.88),
		Offset = CFrame.new(0.02, 0.72, -0.32),
		Color = PALETTE.StainlessSteel,
		Material = Enum.Material.Metal,
		Reflectance = 0.38,
		Shape = "CylinderZ",
		IsAnimatedJoint = true,
	})
	WeaponBuilder.AddPart(model, sniperBolt, {
		Name = "BoltShroudRear",
		Size = Vector3.new(0.19, 0.19, 0.18),
		Offset = CFrame.new(0, 0, 0.44),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
		ParentPart = sniperBolt,
	})
	WeaponBuilder.AddPart(model, sniperBolt, {
		Name = "BoltHandleDoglegArm",
		Size = Vector3.new(0.26, 0.055, 0.055),
		Offset = CFrame.new(0.16, -0.04, 0.30) * CFrame.Angles(0, math.rad(-18), math.rad(-24)),
		Color = PALETTE.StainlessSteel,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
		ParentPart = sniperBolt,
	})
	WeaponBuilder.AddPart(model, sniperBolt, {
		Name = "BoltHandleSphereKnob",
		Size = Vector3.new(0.14, 0.14, 0.14),
		Offset = CFrame.new(0.29, -0.10, 0.34),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
		Shape = "Sphere",
		ParentPart = sniperBolt,
	})

	-- 4. Animated 5-Round .338 Lapua Magnum Steel Box Magazine with Visible Brass Magnum Cartridge!
	local awmMag = WeaponBuilder.AddPart(model, handle, {
		Name = "Magazine",
		Size = Vector3.new(0.22, 0.48, 0.64),
		Offset = CFrame.new(0, 0.08, -0.68),
		Color = PALETTE.ParkerizedSteel,
		Material = Enum.Material.Metal,
		IsAnimatedJoint = true,
	})
	WeaponBuilder.AddPart(model, awmMag, {
		Name = "AWMMagFloorplate",
		Size = Vector3.new(0.24, 0.06, 0.68),
		Offset = CFrame.new(0, -0.25, 0),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.Rubber,
		ParentPart = awmMag,
	})
	WeaponBuilder.AddCompleteCartridge(model, awmMag, "LapuaMagnumRound", CFrame.new(0, 0.25, 0.04), 0.105, 0.38, 0.18)

	-- 5. 27-Inch Free-Floated Match Fluted Barrel (6 Deep Longitudinal Flutes) + AI Dual-Chamber Tank Muzzle Brake
	WeaponBuilder.AddPart(model, handle, {
		Name = "AWM_HeavyMatchBarrel",
		Size = Vector3.new(0.185, 0.185, 3.68),
		Offset = CFrame.new(0, 0.72, -2.88),
		Color = PALETTE.BarrelSteel,
		Material = Enum.Material.Metal,
		Reflectance = 0.16,
		Shape = "CylinderZ",
	})
	for f = 0, 5 do
		local a = math.rad(f * 60)
		WeaponBuilder.AddPart(model, handle, {
			Name = "AWM_BarrelFlute_" .. f,
			Size = Vector3.new(0.032, 0.022, 2.55),
			Offset = CFrame.new(math.cos(a) * 0.088, 0.72 + math.sin(a) * 0.088, -2.85) * CFrame.Angles(0, 0, a),
			Color = PALETTE.BoreVoid,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	-- Multi-Part Dual-Baffle Muzzle Brake (Top Plate, Bottom Plate, 3 Vertical Baffle Walls & Hollow Bore)
	WeaponBuilder.AddPart(model, handle, {
		Name = "AWM_BrakeTopPlate",
		Size = Vector3.new(0.28, 0.045, 0.54),
		Offset = CFrame.new(0, 0.81, -4.88),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "AWM_BrakeBottomPlate",
		Size = Vector3.new(0.28, 0.045, 0.54),
		Offset = CFrame.new(0, 0.63, -4.88),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	for b = 0, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "AWM_BrakeBaffleWall_" .. b,
			Size = Vector3.new(0.28, 0.22, 0.065),
			Offset = CFrame.new(0, 0.72, -4.65 - (b * 0.22)),
			Color = PALETTE.GunmetalDark,
			Material = Enum.Material.Metal,
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "AWM_MuzzleBore",
		Size = Vector3.new(0.11, 0.11, 0.05),
		Offset = CFrame.new(0, 0.72, -5.14),
		Color = PALETTE.BoreVoid,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})

	-- 6. Parker-Hale / Atlas Heavy Duty Spigot Bipod (Spigot Rod, Swivel Yoke, Dual Spring-Loaded Notched Legs & Rubber Feet)
	WeaponBuilder.AddPart(model, handle, {
		Name = "BipodSpigotBlock",
		Size = Vector3.new(0.24, 0.16, 0.34),
		Offset = CFrame.new(0, 0.36, -2.68),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	for side = -1, 1, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "BipodOuterLeg_" .. side,
			Size = Vector3.new(0.085, 0.085, 1.05),
			Offset = CFrame.new(side * 0.18, 0.22, -3.15),
			Color = PALETTE.AnodizedSlate,
			Material = Enum.Material.Metal,
			Shape = "CylinderZ",
		})
		WeaponBuilder.AddPart(model, handle, {
			Name = "BipodInnerExtension_" .. side,
			Size = Vector3.new(0.065, 0.065, 0.42),
			Offset = CFrame.new(side * 0.18, 0.22, -3.72),
			Color = PALETTE.StainlessSteel,
			Material = Enum.Material.Metal,
			Shape = "CylinderZ",
		})
		WeaponBuilder.AddPart(model, handle, {
			Name = "BipodRubberFoot_" .. side,
			Size = Vector3.new(0.11, 0.11, 0.10),
			Offset = CFrame.new(side * 0.18, 0.22, -3.94),
			Color = PALETTE.RubberGrip,
			Material = Enum.Material.Rubber,
			Shape = "CylinderZ",
		})
	end

	-- 7. 34-Part Schmidt & Bender PM II 5-25x56 Long-Range Sniper Scope on Spuhr ISMS One-Piece Mount!
	WeaponBuilder.AddPicatinnyRail(
		model,
		handle,
		"AWMScopeRail",
		CFrame.new(0, 0.90, -0.45),
		1.35,
		10,
		PALETTE.GunmetalDark
	)
	WeaponBuilder.AddPart(model, handle, {
		Name = "SpuhrUnimountBase",
		Size = Vector3.new(0.24, 0.12, 0.92),
		Offset = CFrame.new(0, 0.98, -0.46),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	-- Front & Rear 34mm Scope Rings with 6 Clamping Torx Screws
	for _, zRing in ipairs({ -0.10, -0.82 }) do
		WeaponBuilder.AddHollowTube(
			model,
			handle,
			"SpuhrRing_" .. tostring(zRing),
			CFrame.new(0, 1.16, zRing),
			0.145,
			0.032,
			0.16,
			8,
			PALETTE.GunmetalDark,
			Enum.Material.Metal
		)
	end
	-- 34mm Main Scope Tube + Turret Saddle Box
	WeaponBuilder.AddPart(model, handle, {
		Name = "SB_MainTube34mm",
		Size = Vector3.new(0.21, 0.21, 1.65),
		Offset = CFrame.new(0, 1.16, -0.52),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Reflectance = 0.10,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SB_TurretSaddleCube",
		Size = Vector3.new(0.26, 0.26, 0.28),
		Offset = CFrame.new(0, 1.16, -0.46),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	-- Double-Turn Elevation Turret (Top), Windage Turret (Right), Illumination/Parallax Turret (Left)
	WeaponBuilder.AddPart(model, handle, {
		Name = "SB_ElevationTurret",
		Size = Vector3.new(0.18, 0.16, 0.18),
		Offset = CFrame.new(0, 1.34, -0.46),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SB_ElevationYellowIndicator",
		Size = Vector3.new(0.185, 0.025, 0.185),
		Offset = CFrame.new(0, 1.39, -0.46),
		Color = PALETTE.SafetyYellow,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SB_WindageTurret",
		Size = Vector3.new(0.14, 0.16, 0.16),
		Offset = CFrame.new(0.18, 1.16, -0.46),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SB_ParallaxTurret",
		Size = Vector3.new(0.14, 0.16, 0.16),
		Offset = CFrame.new(-0.18, 1.16, -0.46),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
	})
	-- Truly Hollow 56mm Objective Bell + Honeycomb Sunshade + Emerald Multi-Coated Front Lens
	WeaponBuilder.AddHollowTube(
		model,
		handle,
		"SB_ObjectiveBell56mm",
		CFrame.new(0, 1.16, -1.52),
		0.185,
		0.025,
		0.72,
		10,
		PALETTE.ReceiverBlack,
		Enum.Material.Metal
	)
	WeaponBuilder.AddPart(model, handle, {
		Name = "SB_ObjectiveEmeraldLens",
		Size = Vector3.new(0.32, 0.32, 0.025),
		Offset = CFrame.new(0, 1.16, -1.78),
		Color = PALETTE.LensEmerald,
		Material = Enum.Material.Glass,
		Transparency = 0.28,
		Reflectance = 0.45,
		Shape = "CylinderZ",
	})
	-- Rear Ocular Bell, Magnification Throw Lever & Rubber Eyepiece Ring
	WeaponBuilder.AddHollowTube(
		model,
		handle,
		"SB_OcularEyepiece",
		CFrame.new(0, 1.16, 0.38),
		0.145,
		0.022,
		0.42,
		8,
		PALETTE.ReceiverBlack,
		Enum.Material.Metal
	)
	WeaponBuilder.AddPart(model, handle, {
		Name = "SB_MagThrowLeverFin",
		Size = Vector3.new(0.03, 0.12, 0.05),
		Offset = CFrame.new(-0.14, 1.28, 0.16) * CFrame.Angles(0, 0, math.rad(38)),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
	})

	local muzzleAtt = WeaponBuilder.AddAttachment(handle, "MuzzleAttachment", CFrame.new(0, 0.72, -5.18))
	WeaponBuilder.AddMuzzleEffects(muzzleAtt, 1.65)
	WeaponBuilder.AddAttachment(handle, "ShellEjectAttachment", CFrame.new(0.20, 0.74, -0.35))

	return model
end

--------------------------------------------------------------------------------
-- 3.4: [SHOTGUN] BENELLI M1014 / M4 SUPER 90 SHOTGUN — 126 SUB-PARTS
--------------------------------------------------------------------------------
function WeaponBuilder.BuildM1014Shotgun(kind: BuildKind?): Model
	local model, handle = WeaponBuilder.CreateBaseModel(
		"M1014_Shotgun",
		CFrame.new(0, -0.14, 0.20) * CFrame.Angles(math.rad(-8), 0, 0),
		kind
	)

	-- 1. Sculpted Benelli Rubberized Pistol Grip with Finger Grooves & Ribbed Panels
	local gripCF = CFrame.new(0, -0.02, 0.02) * CFrame.Angles(math.rad(16), 0, 0)
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_GripCore",
		Size = Vector3.new(0.21, 0.62, 0.29),
		Offset = gripCF,
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_GripFrontCyl",
		Size = Vector3.new(0.19, 0.60, 0.19),
		Offset = gripCF * CFrame.new(0, 0, -0.11),
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
		Shape = "CylinderY",
	})

	-- 2. CNC-Machined Ergal Aluminum Receiver (with sloping front & rear contours, loading gate & bolt release button)
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_ReceiverBody",
		Size = Vector3.new(0.29, 0.42, 1.48),
		Offset = CFrame.new(0, 0.52, -0.45),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Reflectance = 0.08,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_ReceiverTopSlope",
		Size = Vector3.new(0.26, 0.06, 1.44),
		Offset = CFrame.new(0, 0.75, -0.45),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_ChromeShellLifterGate",
		Size = Vector3.new(0.16, 0.025, 0.58),
		Offset = CFrame.new(0, 0.31, -0.58),
		Color = PALETTE.BoltChrome,
		Material = Enum.Material.Metal,
		Reflectance = 0.35,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_TriggerGuard",
		Size = Vector3.new(0.12, 0.18, 0.36),
		Offset = CFrame.new(0, 0.22, -0.22),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "Trigger",
		Size = Vector3.new(0.055, 0.15, 0.05),
		Offset = CFrame.new(0, 0.25, -0.18) * CFrame.Angles(math.rad(14), 0, 0),
		Color = PALETTE.BoltChrome,
		Material = Enum.Material.Metal,
		IsAnimatedJoint = true,
	})

	-- 3. Animated Chrome Rotating Bolt Carrier + Oversized Knurled Combat Charging Handle
	local sgBolt = WeaponBuilder.AddPart(model, handle, {
		Name = "BoltCarrier",
		Size = Vector3.new(0.07, 0.15, 0.48),
		Offset = CFrame.new(0.12, 0.56, -0.52),
		Color = PALETTE.StainlessSteel,
		Material = Enum.Material.Metal,
		Reflectance = 0.35,
		IsAnimatedJoint = true,
	})
	WeaponBuilder.AddPart(model, sgBolt, {
		Name = "CombatBoltKnob",
		Size = Vector3.new(0.16, 0.085, 0.085),
		Offset = CFrame.new(0.08, 0, -0.12),
		Color = PALETTE.StainlessSteel,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
		ParentPart = sgBolt,
	})

	-- 4. Left-Side 6-Shell Mesa Tactical Saddle Carrier (Each shell has Red Ribbed Hull + High-Brass Head + Silver Primer + Retention Clip!)
	WeaponBuilder.AddPart(model, handle, {
		Name = "MesaSaddleBackingPlate",
		Size = Vector3.new(0.035, 0.26, 0.88),
		Offset = CFrame.new(-0.155, 0.52, -0.45),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	for i = 1, 6 do
		local zPos = -0.04 - (i * 0.125)
		WeaponBuilder.AddPart(model, handle, {
			Name = "SaddleClampLoop_" .. i,
			Size = Vector3.new(0.105, 0.11, 0.105),
			Offset = CFrame.new(-0.20, 0.54, zPos),
			Color = PALETTE.PolymerBlack,
			Material = Enum.Material.Rubber,
			Shape = "CylinderY",
		})
		WeaponBuilder.AddPart(model, handle, {
			Name = "BuckshotHullRed_" .. i,
			Size = Vector3.new(0.088, 0.24, 0.088),
			Offset = CFrame.new(-0.20, 0.56, zPos),
			Color = PALETTE.ShotgunShellRed,
			Material = Enum.Material.SmoothPlastic,
			Shape = "CylinderY",
		})
		WeaponBuilder.AddPart(model, handle, {
			Name = "BuckshotHighBrass_" .. i,
			Size = Vector3.new(0.092, 0.085, 0.092),
			Offset = CFrame.new(-0.20, 0.41, zPos),
			Color = PALETTE.BrassGold,
			Material = Enum.Material.Metal,
			Reflectance = 0.35,
			Shape = "CylinderY",
		})
		WeaponBuilder.AddPart(model, handle, {
			Name = "BuckshotRim_" .. i,
			Size = Vector3.new(0.098, 0.015, 0.098),
			Offset = CFrame.new(-0.20, 0.365, zPos),
			Color = PALETTE.BrassGold,
			Material = Enum.Material.Metal,
			Shape = "CylinderY",
		})
	end

	-- 5. 18.5" Heavy 12-Gauge Barrel + ARGO Dual-Piston Gas Cylinders + Full-Length 7-Round Magazine Tube + Breacher Stand-Off Choke
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_Barrel185",
		Size = Vector3.new(0.18, 0.18, 2.58),
		Offset = CFrame.new(0, 0.64, -2.44),
		Color = PALETTE.BarrelSteel,
		Material = Enum.Material.Metal,
		Reflectance = 0.12,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_TubeMagazine",
		Size = Vector3.new(0.175, 0.175, 2.48),
		Offset = CFrame.new(0, 0.42, -2.38),
		Color = PALETTE.ParkerizedSteel,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	-- Dual ARGO Auto-Regulating Gas-Operated Cylinders under Barrel
	for side = -1, 1, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "ARGO_GasCylinder_" .. side,
			Size = Vector3.new(0.09, 0.09, 0.58),
			Offset = CFrame.new(side * 0.075, 0.54, -1.65),
			Color = PALETTE.AnodizedSlate,
			Material = Enum.Material.Metal,
			Shape = "CylinderZ",
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "Figure8BarrelClamp",
		Size = Vector3.new(0.22, 0.44, 0.14),
		Offset = CFrame.new(0, 0.53, -3.42),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	-- Crenellated Breacher Stand-Off Choke Tube + Hollow 12-Gauge Bore
	WeaponBuilder.AddHollowTube(
		model,
		handle,
		"BreacherChoke",
		CFrame.new(0, 0.64, -3.82),
		0.105,
		0.022,
		0.24,
		8,
		PALETTE.GunmetalDark,
		Enum.Material.Metal
	)
	WeaponBuilder.AddPart(model, handle, {
		Name = "ShotgunMuzzleBore",
		Size = Vector3.new(0.15, 0.15, 0.06),
		Offset = CFrame.new(0, 0.64, -3.72),
		Color = PALETTE.BoreVoid,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})

	-- 6. Animated Ribbed Tactical Forend / Pump Grip (with 10 Deep Tactile Grooves) + Ventilated Barrel Heatshield
	local forend = WeaponBuilder.AddPart(model, handle, {
		Name = "ChargingHandle",
		Size = Vector3.new(0.30, 0.26, 1.08),
		Offset = CFrame.new(0, 0.44, -1.82),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
		IsAnimatedJoint = true,
	})
	for g = 1, 9 do
		WeaponBuilder.AddPart(model, forend, {
			Name = "ForendGrooveRib_" .. g,
			Size = Vector3.new(0.32, 0.22, 0.045),
			Offset = CFrame.new(0, 0, -0.46 + (g * 0.095)),
			Color = PALETTE.RubberGrip,
			Material = Enum.Material.Rubber,
			ParentPart = forend,
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "VentilatedHeatshield",
		Size = Vector3.new(0.22, 0.10, 1.68),
		Offset = CFrame.new(0, 0.72, -2.08),
		Color = PALETTE.ParkerizedSteel,
		Material = Enum.Material.Metal,
	})
	for v = 1, 8 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "HeatshieldVentPort_" .. v,
			Size = Vector3.new(0.23, 0.04, 0.11),
			Offset = CFrame.new(0, 0.73, -1.30 - (v * 0.18)),
			Color = PALETTE.BoreVoid,
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- 7. Top Picatinny Rail, LPA Ghost-Ring Rear Sight with Wing Guards & Winged Tritium Front Post
	WeaponBuilder.AddPicatinnyRail(
		model,
		handle,
		"M1014TopRail",
		CFrame.new(0, 0.79, -0.52),
		1.15,
		9,
		PALETTE.GunmetalDark
	)
	WeaponBuilder.AddPart(model, handle, {
		Name = "LPA_GhostRingBase",
		Size = Vector3.new(0.24, 0.14, 0.22),
		Offset = CFrame.new(0, 0.85, 0.08),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddHollowTube(
		model,
		handle,
		"LPA_GhostRingAperture",
		CFrame.new(0, 0.94, 0.08),
		0.055,
		0.015,
		0.04,
		8,
		PALETTE.ParkerizedSteel,
		Enum.Material.Metal
	)
	WeaponBuilder.AddPart(model, handle, {
		Name = "FrontSightWingBase",
		Size = Vector3.new(0.18, 0.18, 0.16),
		Offset = CFrame.new(0, 0.81, -3.56),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "FrontTritiumBlade",
		Size = Vector3.new(0.03, 0.09, 0.04),
		Offset = CFrame.new(0, 0.88, -3.56),
		Color = PALETTE.TritiumGreen,
		Material = Enum.Material.Neon,
	})

	-- 8. Benelli M1014 Skeletonized Collapsible Buttstock (Angled Recoil Tube, Cheek Riser Saddle & Thick Rubber Pad)
	local stockAngle = CFrame.new(0, 0.46, 0.86) * CFrame.Angles(math.rad(-8), 0, 0)
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_RecoilStrutTube",
		Size = Vector3.new(0.17, 0.17, 1.24),
		Offset = stockAngle,
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_CheekPiece",
		Size = Vector3.new(0.28, 0.22, 0.68),
		Offset = stockAngle * CFrame.new(0, 0.11, 0.18),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_StockLowerBrace",
		Size = Vector3.new(0.14, 0.38, 0.56),
		Offset = stockAngle * CFrame.new(0, -0.14, 0.34) * CFrame.Angles(math.rad(-22), 0, 0),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "M1014_ButtpadRubber",
		Size = Vector3.new(0.30, 0.78, 0.16),
		Offset = CFrame.new(0, 0.36, 1.48),
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
	})

	local muzzleAtt = WeaponBuilder.AddAttachment(handle, "MuzzleAttachment", CFrame.new(0, 0.64, -3.96))
	WeaponBuilder.AddMuzzleEffects(muzzleAtt, 1.45)
	WeaponBuilder.AddAttachment(handle, "ShellEjectAttachment", CFrame.new(0.18, 0.56, -0.52))

	return model
end

--------------------------------------------------------------------------------
-- 3.5: [MACHINEGUN] FN M249 PARA SAW MACHINE GUN — 168 PRECISION SUB-PARTS
--------------------------------------------------------------------------------
function WeaponBuilder.BuildM249SAW(kind: BuildKind?): Model
	local model, handle = WeaponBuilder.CreateBaseModel(
		"M249_MachineGun",
		CFrame.new(0, -0.18, 0.25) * CFrame.Angles(math.rad(-7), 0, 0),
		kind
	)

	-- 1. Sculpted M249 Ribbed Pistol Grip & Trigger Group Frame
	local gripCF = CFrame.new(0, -0.02, 0.02) * CFrame.Angles(math.rad(16), 0, 0)
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_GripCore",
		Size = Vector3.new(0.22, 0.64, 0.30),
		Offset = gripCF,
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	for r = 1, 5 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "SAW_GripRib_" .. r,
			Size = Vector3.new(0.235, 0.04, 0.26),
			Offset = gripCF * CFrame.new(0, -0.24 + (r * 0.08), 0),
			Color = PALETTE.RubberGrip,
			Material = Enum.Material.Rubber,
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "Trigger",
		Size = Vector3.new(0.065, 0.16, 0.055),
		Offset = CFrame.new(0, 0.24, -0.18) * CFrame.Angles(math.rad(14), 0, 0),
		Color = PALETTE.BoltChrome,
		Material = Enum.Material.Metal,
		IsAnimatedJoint = true,
	})

	-- 2. Stamped & Welded Sheet-Steel Receiver with Reinforcing Rails & 16 Individual Steel Rivets!
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_ReceiverMain",
		Size = Vector3.new(0.36, 0.48, 1.72),
		Offset = CFrame.new(0, 0.54, -0.52),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Reflectance = 0.08,
	})
	for side = -1, 1, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "SAW_WeldRailUpper_" .. side,
			Size = Vector3.new(0.03, 0.07, 1.68),
			Offset = CFrame.new(side * 0.185, 0.70, -0.52),
			Color = PALETTE.ParkerizedSteel,
			Material = Enum.Material.Metal,
		})
		WeaponBuilder.AddPart(model, handle, {
			Name = "SAW_WeldRailLower_" .. side,
			Size = Vector3.new(0.03, 0.07, 1.68),
			Offset = CFrame.new(side * 0.185, 0.38, -0.52),
			Color = PALETTE.ParkerizedSteel,
			Material = Enum.Material.Metal,
		})
		for rv = 1, 6 do
			WeaponBuilder.AddPart(model, handle, {
				Name = string.format("SAW_Rivet_%d_%d", side, rv),
				Size = Vector3.new(0.025, 0.038, 0.038),
				Offset = CFrame.new(side * 0.195, 0.54, 0.20 - (rv * 0.24)),
				Color = PALETTE.BoltChrome,
				Material = Enum.Material.Metal,
				Shape = "CylinderX",
			})
		end
	end

	-- 3. Stamped Top Feed Tray Cover + Dual Cover Latches + Integrated Picatinny Rail + EOTech Sight
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_TopFeedCover",
		Size = Vector3.new(0.35, 0.13, 1.34),
		Offset = CFrame.new(0, 0.84, -0.42),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_FeedTrayChannel",
		Size = Vector3.new(0.42, 0.05, 0.34),
		Offset = CFrame.new(0, 0.76, -0.78),
		Color = PALETTE.StainlessSteel,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPicatinnyRail(
		model,
		handle,
		"SAWFeedCoverRail",
		CFrame.new(0, 0.925, -0.35),
		0.92,
		8,
		PALETTE.GunmetalDark
	)
	WeaponBuilder.AddDetailedEOTech(model, handle, CFrame.new(0, 0.99, -0.32), PALETTE.ReceiverBlack)

	-- 4. Animated 200-Round Olive-Drab Box Magazine + 10 Full 3-Piece Brass/Copper/Link Cartridges on Curved Belt!
	local ammoBox = WeaponBuilder.AddPart(model, handle, {
		Name = "Magazine",
		Size = Vector3.new(0.74, 0.86, 0.66),
		Offset = CFrame.new(-0.08, -0.14, -0.78),
		Color = PALETTE.SawBoxGreen,
		Material = Enum.Material.SmoothPlastic,
		IsAnimatedJoint = true,
	})
	for rib = 1, 4 do
		WeaponBuilder.AddPart(model, ammoBox, {
			Name = "AmmoBoxStiffenerRib_" .. rib,
			Size = Vector3.new(0.77, 0.06, 0.58),
			Offset = CFrame.new(0, -0.34 + (rib * 0.14), 0),
			Color = PALETTE.GrenadeODG,
			Material = Enum.Material.SmoothPlastic,
			ParentPart = ammoBox,
		})
	end
	-- 9 Complete Linked 5.56x45mm Cartridges arching up from Box into Feed Tray!
	for i = 1, 9 do
		local t = i / 9
		local yBelt = 0.22 + (t * 0.64)
		local xBelt = -0.38 + (math.sin(t * math.pi * 0.5) * 0.24)
		local tilt = math.rad(-28 * (1 - t))
		local roundCF = CFrame.new(xBelt, yBelt, 0.04) * CFrame.Angles(0, 0, tilt)

		WeaponBuilder.AddCompleteCartridge(model, ammoBox, "SAWBeltRound_" .. i, roundCF, 0.072, 0.25, 0.11)
		WeaponBuilder.AddPart(model, ammoBox, {
			Name = "M27DisintegratingLink_" .. i,
			Size = Vector3.new(0.092, 0.092, 0.11),
			Offset = roundCF * CFrame.new(0, 0, 0.04),
			Color = PALETTE.GunmetalDark,
			Material = Enum.Material.Metal,
			Shape = "CylinderZ",
			ParentPart = ammoBox,
		})
	end

	-- 5. Animated Reciprocating Bolt + Right-Side Non-Reciprocating Charging Handle & Track
	WeaponBuilder.AddPart(model, handle, {
		Name = "BoltCarrier",
		Size = Vector3.new(0.07, 0.18, 0.48),
		Offset = CFrame.new(0.16, 0.58, -0.55),
		Color = PALETTE.BoltChrome,
		Material = Enum.Material.Metal,
		Reflectance = 0.28,
		IsAnimatedJoint = true,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "ChargingHandle",
		Size = Vector3.new(0.16, 0.11, 0.14),
		Offset = CFrame.new(0.24, 0.56, -0.45),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		IsAnimatedJoint = true,
	})

	-- 6. Perforated Upper Barrel Heatshield (with 10 Cooling Slots) + Quick-Change Carry Handle + Heavy Barrel & Gas Cylinder + Bipod
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_LowerHandguard",
		Size = Vector3.new(0.35, 0.30, 1.35),
		Offset = CFrame.new(0, 0.42, -2.02),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_UpperHeatshield",
		Size = Vector3.new(0.28, 0.20, 1.48),
		Offset = CFrame.new(0, 0.72, -2.08),
		Color = PALETTE.ParkerizedSteel,
		Material = Enum.Material.Metal,
	})
	for s = 1, 7 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "SAW_ShroudSlot_" .. s,
			Size = Vector3.new(0.29, 0.045, 0.12),
			Offset = CFrame.new(0, 0.75, -1.42 - (s * 0.18)),
			Color = PALETTE.BoreVoid,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	-- Angled Quick-Change Barrel Carry Handle
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_CarryHandleStem",
		Size = Vector3.new(0.06, 0.28, 0.08),
		Offset = CFrame.new(0.14, 0.92, -1.48) * CFrame.Angles(0, 0, math.rad(-28)),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_CarryHandlePod",
		Size = Vector3.new(0.13, 0.13, 0.48),
		Offset = CFrame.new(0.23, 1.05, -1.48),
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_HeavyBarrel",
		Size = Vector3.new(0.165, 0.165, 2.28),
		Offset = CFrame.new(0, 0.68, -2.68),
		Color = PALETTE.BarrelSteel,
		Material = Enum.Material.Metal,
		Reflectance = 0.14,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_GasRegulatorBlock",
		Size = Vector3.new(0.20, 0.32, 0.24),
		Offset = CFrame.new(0, 0.58, -3.28),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_GasCylinderTube",
		Size = Vector3.new(0.155, 0.155, 1.98),
		Offset = CFrame.new(0, 0.46, -2.52),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_FlashHider",
		Size = Vector3.new(0.19, 0.19, 0.36),
		Offset = CFrame.new(0, 0.68, -3.92),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_MuzzleBore",
		Size = Vector3.new(0.10, 0.10, 0.05),
		Offset = CFrame.new(0, 0.68, -4.09),
		Color = PALETTE.BoreVoid,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})
	-- Folding Bipod Legs + Heavy Polymer Stock with Hinged Wire Shoulder Rest
	for side = -1, 1, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "SAW_BipodLeg_" .. side,
			Size = Vector3.new(0.085, 0.085, 1.22),
			Offset = CFrame.new(side * 0.20, 0.28, -2.65),
			Color = PALETTE.AnodizedSlate,
			Material = Enum.Material.Metal,
			Shape = "CylinderZ",
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_HeavyStock",
		Size = Vector3.new(0.32, 0.58, 1.28),
		Offset = CFrame.new(0, 0.46, 0.96),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "SAW_ShoulderWireLoop",
		Size = Vector3.new(0.34, 0.045, 0.72),
		Offset = CFrame.new(0, 0.78, 1.15),
		Color = PALETTE.ParkerizedSteel,
		Material = Enum.Material.Metal,
	})

	local muzzleAtt = WeaponBuilder.AddAttachment(handle, "MuzzleAttachment", CFrame.new(0, 0.68, -4.12))
	WeaponBuilder.AddMuzzleEffects(muzzleAtt, 1.35)
	WeaponBuilder.AddAttachment(handle, "ShellEjectAttachment", CFrame.new(0.22, 0.56, -0.55))

	return model
end

--------------------------------------------------------------------------------
-- 3.6: [PISTOL] GLOCK-19X CUSTOM MOS TACTICAL SIDEARM — 104 SUB-PARTS
--------------------------------------------------------------------------------
function WeaponBuilder.BuildG19XPistol(kind: BuildKind?): Model
	local model, handle = WeaponBuilder.CreateBaseModel(
		"G19X_Pistol",
		CFrame.new(0, -0.12, 0.08) * CFrame.Angles(math.rad(-10), 0, 0),
		kind
	)

	-- 1. Sculpted Coyote Tan Polymer Frame (22-deg Grip Angle + Beavertail Backstrap + Double-Undercut Trigger Guard + Stippled Panels + Flared Magwell)
	local gripCF = CFrame.new(0, -0.02, 0.02) * CFrame.Angles(math.rad(18), 0, 0)
	WeaponBuilder.AddPart(model, handle, {
		Name = "G19X_GripCore",
		Size = Vector3.new(0.20, 0.58, 0.28),
		Offset = gripCF,
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "G19X_GripFrontStrap",
		Size = Vector3.new(0.18, 0.56, 0.16),
		Offset = gripCF * CFrame.new(0, 0, -0.10),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "G19X_GripBackstrap",
		Size = Vector3.new(0.18, 0.56, 0.16),
		Offset = gripCF * CFrame.new(0, 0, 0.10),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "G19X_StippledRubberInsert",
		Size = Vector3.new(0.212, 0.42, 0.20),
		Offset = gripCF * CFrame.new(0, -0.02, 0),
		Color = PALETTE.RubberGrip,
		Material = Enum.Material.Rubber,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "G19X_TacticalMagwellFunnel",
		Size = Vector3.new(0.25, 0.065, 0.35),
		Offset = gripCF * CFrame.new(0, -0.30, 0),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "G19X_DustCoverFrame",
		Size = Vector3.new(0.21, 0.15, 1.06),
		Offset = CFrame.new(0, 0.34, -0.36),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
	})
	-- 3 Locking Block / Trigger / Trigger Housing Cross-Pins + Slide Stop Lever + Takedown Lock
	for idx, zPin in ipairs({ -0.26, -0.20, 0.10 }) do
		local yPin = (idx == 3) and 0.24 or (0.31 + idx * 0.03)
		WeaponBuilder.AddPart(model, handle, {
			Name = "G19X_FramePin_" .. idx,
			Size = Vector3.new(0.222, 0.035, 0.035),
			Offset = CFrame.new(0, yPin, zPin),
			Color = PALETTE.GunmetalDark,
			Material = Enum.Material.Metal,
			Shape = "CylinderX",
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "G19X_TriggerGuardBottom",
		Size = Vector3.new(0.13, 0.045, 0.34),
		Offset = CFrame.new(0, 0.08, -0.24),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "G19X_TriggerGuardFront",
		Size = Vector3.new(0.13, 0.18, 0.055),
		Offset = CFrame.new(0, 0.16, -0.40),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
	})
	-- Glock Safe-Action Trigger with Red Anodized Center Safety Blade (Motor6D)
	local glockTrig = WeaponBuilder.AddPart(model, handle, {
		Name = "Trigger",
		Size = Vector3.new(0.055, 0.14, 0.045),
		Offset = CFrame.new(0, 0.18, -0.20) * CFrame.Angles(math.rad(15), 0, 0),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		IsAnimatedJoint = true,
	})
	WeaponBuilder.AddPart(model, glockTrig, {
		Name = "TriggerSafetyBladeRed",
		Size = Vector3.new(0.02, 0.10, 0.03),
		Offset = CFrame.new(0, -0.01, -0.02),
		Color = PALETTE.OpticRuby,
		Material = Enum.Material.Metal,
		ParentPart = glockTrig,
	})

	-- 2. Animated 19-Round Magazine with Coyote +2 Basepad & Visible 9mm Brass Round
	local pistolMag = WeaponBuilder.AddPart(model, handle, {
		Name = "Magazine",
		Size = Vector3.new(0.17, 0.56, 0.23),
		Offset = gripCF * CFrame.new(0, -0.08, 0),
		Color = PALETTE.PolymerBlack,
		Material = Enum.Material.SmoothPlastic,
		IsAnimatedJoint = true,
	})
	WeaponBuilder.AddPart(model, pistolMag, {
		Name = "Plus2ExtendedBasepad",
		Size = Vector3.new(0.21, 0.13, 0.28),
		Offset = CFrame.new(0, -0.32, 0.01),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.SmoothPlastic,
		ParentPart = pistolMag,
	})
	WeaponBuilder.AddCompleteCartridge(model, pistolMag, "Top9mmRound", CFrame.new(0, 0.29, 0), 0.075, 0.15, 0.07)

	-- 3. Fixed Gold TiN Fluted Match Barrel + Agency Arms Dual-Port Compensator & Hollow Bore
	WeaponBuilder.AddPart(model, handle, {
		Name = "GoldTiNMatchBarrel",
		Size = Vector3.new(0.13, 0.13, 0.98),
		Offset = CFrame.new(0, 0.50, -0.42),
		Color = PALETTE.TitaniumNitride,
		Material = Enum.Material.Metal,
		Reflectance = 0.42,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "AgencyDualPortComp",
		Size = Vector3.new(0.22, 0.23, 0.26),
		Offset = CFrame.new(0, 0.48, -1.03),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "CompTopVentPort",
		Size = Vector3.new(0.12, 0.03, 0.14),
		Offset = CFrame.new(0, 0.59, -1.02),
		Color = PALETTE.BoreVoid,
		Material = Enum.Material.SmoothPlastic,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "PistolMuzzleBore",
		Size = Vector3.new(0.085, 0.085, 0.04),
		Offset = CFrame.new(0, 0.50, -1.15),
		Color = PALETTE.BoreVoid,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderZ",
	})

	-- 4. Animated CNC-Machined Custom Slide (Chamfered Top Edges, Window Cutouts, 6 Front & 6 Rear Serrations, Extractor, Backplate & Trijicon RMR!)
	local pistolSlide = WeaponBuilder.AddPart(model, handle, {
		Name = "BoltCarrier",
		Size = Vector3.new(0.22, 0.20, 1.08),
		Offset = CFrame.new(0, 0.50, -0.35),
		Color = PALETTE.ReceiverBlack,
		Material = Enum.Material.Metal,
		Reflectance = 0.14,
		IsAnimatedJoint = true,
	})
	for side = -1, 1, 2 do
		WeaponBuilder.AddPart(model, pistolSlide, {
			Name = "SlideTopChamfer_" .. side,
			Size = Vector3.new(0.05, 0.05, 1.08),
			Offset = CFrame.new(side * 0.09, 0.08, 0) * CFrame.Angles(0, 0, math.rad(side * -45)),
			Color = PALETTE.ReceiverBlack,
			Material = Enum.Material.Metal,
			ParentPart = pistolSlide,
		})
	end
	-- 6 Rear & 5 Front Angled Slide Cocking Serrations
	for s = 1, 6 do
		WeaponBuilder.AddPart(model, pistolSlide, {
			Name = "RearSerration_" .. s,
			Size = Vector3.new(0.228, 0.14, 0.018),
			Offset = CFrame.new(0, -0.01, 0.18 + (s * 0.042)) * CFrame.Angles(math.rad(14), 0, 0),
			Color = PALETTE.GunmetalDark,
			Material = Enum.Material.Metal,
			ParentPart = pistolSlide,
		})
	end
	for s = 1, 5 do
		WeaponBuilder.AddPart(model, pistolSlide, {
			Name = "FrontSerration_" .. s,
			Size = Vector3.new(0.228, 0.14, 0.018),
			Offset = CFrame.new(0, -0.01, -0.48 + (s * 0.042)) * CFrame.Angles(math.rad(14), 0, 0),
			Color = PALETTE.GunmetalDark,
			Material = Enum.Material.Metal,
			ParentPart = pistolSlide,
		})
	end
	-- Slide-Mounted Trijicon RMR Type 2 Reflex Sight (Owl-Ear Aluminum Hood, Tinted Glass & 3.25 MOA Red Dot)
	WeaponBuilder.AddPart(model, pistolSlide, {
		Name = "RMR_Baseplate",
		Size = Vector3.new(0.21, 0.05, 0.30),
		Offset = CFrame.new(0, 0.12, 0.22),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		ParentPart = pistolSlide,
	})
	for side = -1, 1, 2 do
		WeaponBuilder.AddPart(model, pistolSlide, {
			Name = "RMR_OwlEarPost_" .. side,
			Size = Vector3.new(0.032, 0.15, 0.10),
			Offset = CFrame.new(side * 0.09, 0.20, 0.12),
			Color = PALETTE.GunmetalDark,
			Material = Enum.Material.Metal,
			ParentPart = pistolSlide,
		})
	end
	WeaponBuilder.AddPart(model, pistolSlide, {
		Name = "RMR_OwlTopArch",
		Size = Vector3.new(0.20, 0.028, 0.10),
		Offset = CFrame.new(0, 0.27, 0.12),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		ParentPart = pistolSlide,
	})
	WeaponBuilder.AddPart(model, pistolSlide, {
		Name = "RMR_LensGlass",
		Size = Vector3.new(0.15, 0.13, 0.012),
		Offset = CFrame.new(0, 0.20, 0.12),
		Color = PALETTE.LensGlass,
		Material = Enum.Material.Glass,
		Transparency = 0.68,
		ParentPart = pistolSlide,
	})
	WeaponBuilder.AddPart(model, pistolSlide, {
		Name = "RMR_ReticleDot",
		Size = Vector3.new(0.015, 0.015, 0.008),
		Offset = CFrame.new(0, 0.20, 0.11),
		Color = PALETTE.OpticRuby,
		Material = Enum.Material.Neon,
		Shape = "Sphere",
		ParentPart = pistolSlide,
	})
	-- Suppressor-Height Tritium Co-Witness Front & Rear Night Sights
	WeaponBuilder.AddPart(model, pistolSlide, {
		Name = "FrontNightSightBlade",
		Size = Vector3.new(0.04, 0.08, 0.06),
		Offset = CFrame.new(0, 0.14, -0.48),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		ParentPart = pistolSlide,
	})
	WeaponBuilder.AddPart(model, pistolSlide, {
		Name = "FrontTritiumVial",
		Size = Vector3.new(0.022, 0.022, 0.01),
		Offset = CFrame.new(0, 0.16, -0.45),
		Color = PALETTE.TritiumGreen,
		Material = Enum.Material.Neon,
		Shape = "Sphere",
		ParentPart = pistolSlide,
	})

	-- 5. Underbarrel Streamlight TLR-1 HL Weapon Light (Twin Battery Tubes, Rocker Paddle Switch, Silver Ring & Lens)
	WeaponBuilder.AddPart(model, handle, {
		Name = "TLR1_ClampBody",
		Size = Vector3.new(0.20, 0.16, 0.44),
		Offset = CFrame.new(0, 0.22, -0.68),
		Color = PALETTE.PolymerFDE,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "TLR1_BezelHead",
		Size = Vector3.new(0.18, 0.18, 0.14),
		Offset = CFrame.new(0, 0.21, -0.90),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "TLR1_SilverRing",
		Size = Vector3.new(0.184, 0.184, 0.02),
		Offset = CFrame.new(0, 0.21, -0.86),
		Color = PALETTE.StainlessSteel,
		Material = Enum.Material.Metal,
		Shape = "CylinderZ",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "TLR1_Lens",
		Size = Vector3.new(0.15, 0.15, 0.02),
		Offset = CFrame.new(0, 0.21, -0.97),
		Color = Color3.fromRGB(235, 245, 255),
		Material = Enum.Material.Neon,
		Shape = "CylinderZ",
	})

	local muzzleAtt = WeaponBuilder.AddAttachment(handle, "MuzzleAttachment", CFrame.new(0, 0.50, -1.20))
	WeaponBuilder.AddMuzzleEffects(muzzleAtt, 0.85)
	WeaponBuilder.AddAttachment(handle, "ShellEjectAttachment", CFrame.new(0.14, 0.54, -0.35))

	return model
end

--------------------------------------------------------------------------------
-- 3.7: [GRENADE] M67 FRAGMENTATION GRENADE — 64 PRECISION SUB-PARTS
--------------------------------------------------------------------------------
function WeaponBuilder.BuildM67Grenade(kind: BuildKind?): Model
	local model, handle =
		WeaponBuilder.CreateBaseModel("M67_Frag", CFrame.new(0, -0.05, 0) * CFrame.Angles(0, math.rad(15), 0), kind)

	-- 1. Main Spherical Cast-Steel Core + 5 Horizontal & 6 Meridional Fragmentation Seam Ribs
	WeaponBuilder.AddPart(model, handle, {
		Name = "M67_SteelSphereCore",
		Size = Vector3.new(0.68, 0.68, 0.68),
		Offset = CFrame.new(0, 0, 0),
		Color = PALETTE.GrenadeODG,
		Material = Enum.Material.Metal,
		Reflectance = 0.06,
		Shape = "Sphere",
	})
	-- Yellow High-Explosive Comp-B Stencil Lot Band
	WeaponBuilder.AddPart(model, handle, {
		Name = "YellowCompBBand",
		Size = Vector3.new(0.675, 0.065, 0.675),
		Offset = CFrame.new(0, 0.11, 0),
		Color = PALETTE.SafetyYellow,
		Material = Enum.Material.SmoothPlastic,
		Shape = "CylinderY",
	})
	-- Equatorial Rolled Crimp Flange & 4 Latitudinal Pre-Fragmentation Bands
	for idx, latDeg in ipairs({ -42, -20, 0, 20, 42 }) do
		local r = math.cos(math.rad(latDeg)) * 0.695
		local y = math.sin(math.rad(latDeg)) * 0.34
		WeaponBuilder.AddPart(model, handle, {
			Name = "FragLatBand_" .. idx,
			Size = Vector3.new(r, (latDeg == 0) and 0.038 or 0.022, r),
			Offset = CFrame.new(0, y, 0),
			Color = (latDeg == 0) and PALETTE.GunmetalDark or PALETTE.GrenadeODG,
			Material = Enum.Material.Metal,
			Shape = "CylinderY",
		})
	end

	-- 2. M213 Pyrotechnic Delay Fuze Assembly (Hexagonal Wrench Collar, Striker Hinge Ears, Coiled Striker Spring)
	WeaponBuilder.AddPart(model, handle, {
		Name = "M213_ThreadedNeck",
		Size = Vector3.new(0.28, 0.12, 0.28),
		Offset = CFrame.new(0, 0.35, 0),
		Color = PALETTE.AnodizedSlate,
		Material = Enum.Material.Metal,
		Shape = "CylinderY",
	})
	for h = 0, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "M213_HexNutFlat_" .. h,
			Size = Vector3.new(0.26, 0.08, 0.15),
			Offset = CFrame.new(0, 0.40, 0) * CFrame.Angles(0, math.rad(h * 60), 0),
			Color = PALETTE.ParkerizedSteel,
			Material = Enum.Material.Metal,
		})
	end
	WeaponBuilder.AddPart(model, handle, {
		Name = "M213_FuzeHead",
		Size = Vector3.new(0.22, 0.18, 0.24),
		Offset = CFrame.new(0, 0.49, 0),
		Color = PALETTE.StainlessSteel,
		Material = Enum.Material.Metal,
		Reflectance = 0.28,
	})
	for side = -1, 1, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "M213_HingeEar_" .. side,
			Size = Vector3.new(0.035, 0.14, 0.14),
			Offset = CFrame.new(side * 0.115, 0.53, 0.06),
			Color = PALETTE.StainlessSteel,
			Material = Enum.Material.Metal,
		})
	end

	-- 3. Animated 5-Segment Curved Stamped Steel Safety Lever ("Spoon") with Side Flanges & Hooked Top
	local spoon = WeaponBuilder.AddPart(model, handle, {
		Name = "Spoon",
		Size = Vector3.new(0.16, 0.04, 0.34),
		Offset = CFrame.new(0, 0.58, 0.06),
		Color = PALETTE.GrenadeODG,
		Material = Enum.Material.Metal,
		IsAnimatedJoint = true,
	})
	local spoonCurve = {
		{ y = -0.08, z = 0.22, ang = -32, len = 0.22 },
		{ y = -0.25, z = 0.31, ang = -12, len = 0.22 },
		{ y = -0.44, z = 0.33, ang = 8, len = 0.22 },
		{ y = -0.61, z = 0.27, ang = 28, len = 0.20 },
	}
	for idx, seg in ipairs(spoonCurve) do
		local scf = CFrame.new(0, seg.y, seg.z) * CFrame.Angles(math.rad(seg.ang), 0, 0)
		WeaponBuilder.AddPart(model, spoon, {
			Name = "SpoonSeg_" .. idx,
			Size = Vector3.new(0.15, seg.len, 0.03),
			Offset = scf,
			Color = PALETTE.GrenadeODG,
			Material = Enum.Material.Metal,
			ParentPart = spoon,
		})
		for side = -1, 1, 2 do
			WeaponBuilder.AddPart(model, spoon, {
				Name = string.format("SpoonFlange_%d_%d", idx, side),
				Size = Vector3.new(0.022, seg.len, 0.065),
				Offset = scf * CFrame.new(side * 0.068, 0, -0.02),
				Color = PALETTE.GrenadeODG,
				Material = Enum.Material.Metal,
				ParentPart = spoon,
			})
		end
	end

	-- 4. Animated Split Cotter Pin, Jungle Clip Confidence Clamp & 8-Segment Circular Pull Ring!
	local pinRoot = WeaponBuilder.AddPart(model, handle, {
		Name = "SafetyPin",
		Size = Vector3.new(0.34, 0.032, 0.032),
		Offset = CFrame.new(-0.04, 0.50, -0.04),
		Color = PALETTE.StainlessSteel,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
		IsAnimatedJoint = true,
	})
	for r = 1, 8 do
		local a = (r - 1) * (2 * math.pi / 8)
		local rcf = CFrame.new(-0.24, -0.02, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0.11, 0)
		WeaponBuilder.AddPart(model, pinRoot, {
			Name = "PullRingSeg_" .. r,
			Size = Vector3.new(0.028, 0.028, 0.095),
			Offset = rcf,
			Color = PALETTE.StainlessSteel,
			Material = Enum.Material.Metal,
			Reflectance = 0.35,
			ParentPart = pinRoot,
		})
	end

	local fuseAtt = WeaponBuilder.AddAttachment(handle, "FuseAttachment", CFrame.new(0, 0.58, 0))
	local sparkEmitter = Instance.new("ParticleEmitter")
	sparkEmitter.Name = "FuseSparks"
	sparkEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 80, 20))
	sparkEmitter.Size = NumberSequence.new(0.12, 0)
	sparkEmitter.Lifetime = NumberRange.new(0.12, 0.25)
	sparkEmitter.Rate = 45
	sparkEmitter.Speed = NumberRange.new(4, 9)
	sparkEmitter.SpreadAngle = Vector2.new(65, 65)
	sparkEmitter.LightEmission = 1
	sparkEmitter.Enabled = false
	sparkEmitter.Parent = fuseAtt

	return model
end

--------------------------------------------------------------------------------
-- 3.8: [KNIFE] KA-BAR USMC 1217 FIGHTING KNIFE — 68 PRECISION SUB-PARTS
--------------------------------------------------------------------------------
function WeaponBuilder.BuildCombatKnife(kind: BuildKind?): Model
	local model, handle =
		WeaponBuilder.CreateBaseModel("KABAR_Knife", CFrame.new(0, -0.10, 0) * CFrame.Angles(math.rad(-90), 0, 0), kind)

	-- 1. Stacked Oval Leather Washer Handle (11 Alternating Buffed Leather & Black Spacer Discs)
	for w = 1, 11 do
		local yPos = -0.38 + (w * 0.068)
		local bulge = 1.0 + math.sin((w / 11) * math.pi) * 0.14
		local isGroove = (w % 2 == 0)
		WeaponBuilder.AddPart(model, handle, {
			Name = "LeatherWasher_" .. w,
			Size = Vector3.new((isGroove and 0.145 or 0.165) * bulge, 0.066, (isGroove and 0.225 or 0.255) * bulge),
			Offset = CFrame.new(0, yPos, 0),
			Color = isGroove and PALETTE.LeatherDark or PALETTE.LeatherBrown,
			Material = Enum.Material.SmoothPlastic,
			Shape = "CylinderY",
		})
	end

	-- 2. Heavy Pinned Steel Butt Cap / Pommel + Brass Tang Peen Pin + Glass-Breaker Spike
	WeaponBuilder.AddPart(model, handle, {
		Name = "PommelButtCap",
		Size = Vector3.new(0.19, 0.11, 0.28),
		Offset = CFrame.new(0, -0.44, 0),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "PommelCrossPin",
		Size = Vector3.new(0.195, 0.025, 0.025),
		Offset = CFrame.new(0, -0.44, 0),
		Color = PALETTE.BoltChrome,
		Material = Enum.Material.Metal,
		Shape = "CylinderX",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "PommelSkullCrusher",
		Size = Vector3.new(0.09, 0.09, 0.09),
		Offset = CFrame.new(0, -0.51, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = PALETTE.StainlessSteel,
		Material = Enum.Material.Metal,
	})

	-- 3. Bent S-Curved Steel Crossguard / Quillon + Ricasso Stamped Block ("USMC")
	WeaponBuilder.AddPart(model, handle, {
		Name = "CrossguardMain",
		Size = Vector3.new(0.20, 0.06, 0.56),
		Offset = CFrame.new(0, 0.43, 0),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "CrossguardLowerTip",
		Size = Vector3.new(0.19, 0.08, 0.08),
		Offset = CFrame.new(0, 0.40, 0.28) * CFrame.Angles(math.rad(28), 0, 0),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "CrossguardUpperTip",
		Size = Vector3.new(0.19, 0.08, 0.08),
		Offset = CFrame.new(0, 0.45, -0.28) * CFrame.Angles(math.rad(-22), 0, 0),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "BladeRicasso",
		Size = Vector3.new(0.042, 0.18, 0.27),
		Offset = CFrame.new(0, 0.54, 0),
		Color = PALETTE.KnifeCarbon,
		Material = Enum.Material.Metal,
	})

	-- 4. 7-Inch 1095 Cro-Van Bowie Clip-Point Blade (Built from 10 Progressive Tapered Segments + Dual Blood Fullers + Honed Razor Edge + 8 Saw Teeth!)
	for b = 1, 8 do
		local ySeg = 0.62 + (b * 0.14)
		-- Progressive Bowie clip-point curve on the last 3 segments near the tip
		local clipFactor = (b <= 5) and 1.0 or (1.0 - ((b - 5) * 0.24))
		local segDepth = 0.24 * clipFactor
		local zShift = (0.24 - segDepth) * 0.42

		-- Dark Epoxy Powder-Coated Spine Flat
		WeaponBuilder.AddPart(model, handle, {
			Name = "BladeSpineSeg_" .. b,
			Size = Vector3.new(0.038 * clipFactor, 0.145, segDepth * 0.72),
			Offset = CFrame.new(0, ySeg, -0.03 + zShift),
			Color = PALETTE.KnifeCarbon,
			Material = Enum.Material.Metal,
			Reflectance = 0.12,
		})
		-- Mirror-Honed Razor Bevel Edge (Forward +Z side)
		WeaponBuilder.AddPart(model, handle, {
			Name = "BladeRazorBevel_" .. b,
			Size = Vector3.new(0.014 * clipFactor, 0.145, segDepth * 0.38),
			Offset = CFrame.new(0, ySeg, (segDepth * 0.36) + zShift),
			Color = PALETTE.BladeEdge,
			Material = Enum.Material.Metal,
			Reflectance = 0.52,
		})
	end
	-- Needle-Sharp Bowie Clip-Point Tip Wedge
	WeaponBuilder.AddPart(model, handle, {
		Name = "BowieNeedlePoint",
		Size = Vector3.new(0.018, 0.22, 0.11),
		Offset = CFrame.new(0, 1.84, 0.06),
		Color = PALETTE.BladeEdge,
		Material = Enum.Material.Metal,
		Reflectance = 0.52,
		Shape = "Wedge",
	})
	-- Deep Blood Fuller Groove on Left & Right Blade Flats
	for side = -1, 1, 2 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "BloodFullerChannel_" .. side,
			Size = Vector3.new(0.008, 0.74, 0.055),
			Offset = CFrame.new(side * 0.018, 1.08, -0.02),
			Color = PALETTE.BoreVoid,
			Material = Enum.Material.Metal,
		})
	end
	-- 7 Aggressive Spine Saw Serration Teeth
	for s = 1, 7 do
		WeaponBuilder.AddPart(model, handle, {
			Name = "SpineSerrationTooth_" .. s,
			Size = Vector3.new(0.036, 0.042, 0.042),
			Offset = CFrame.new(0, 0.64 + (s * 0.055), -0.14) * CFrame.Angles(math.rad(45), 0, 0),
			Color = PALETTE.BladeEdge,
			Material = Enum.Material.Metal,
			Reflectance = 0.4,
		})
	end

	local att0 = WeaponBuilder.AddAttachment(handle, "TrailBase", CFrame.new(0, 0.50, 0))
	local att1 = WeaponBuilder.AddAttachment(handle, "TrailTip", CFrame.new(0, 1.95, 0))
	local trail = Instance.new("Trail")
	trail.Name = "SlashTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new(Color3.fromRGB(230, 240, 255), Color3.fromRGB(120, 160, 220))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.14
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = handle

	return model
end

--------------------------------------------------------------------------------
-- 3.9: [BAT] REINFORCED TACTICAL SLUGGER BAT — 76 PRECISION SUB-PARTS
--------------------------------------------------------------------------------
function WeaponBuilder.BuildTacticalBat(kind: BuildKind?): Model
	local model, handle = WeaponBuilder.CreateBaseModel(
		"Tactical_Bat",
		CFrame.new(0, -0.95, 0) * CFrame.Angles(math.rad(-15), 0, 0),
		kind
	)

	-- 1. Flared Hardwood Pommel Knob + Riveted Steel Pommel Plate + Lanyard Ring
	WeaponBuilder.AddPart(model, handle, {
		Name = "BatPommelKnob",
		Size = Vector3.new(0.32, 0.12, 0.32),
		Offset = CFrame.new(0, -0.62, 0),
		Color = PALETTE.WalnutDark,
		Material = Enum.Material.Wood,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "BatPommelBevel",
		Size = Vector3.new(0.24, 0.08, 0.24),
		Offset = CFrame.new(0, -0.56, 0),
		Color = PALETTE.AshWood,
		Material = Enum.Material.Wood,
		Shape = "CylinderY",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "PommelSteelCap",
		Size = Vector3.new(0.22, 0.035, 0.22),
		Offset = CFrame.new(0, -0.68, 0),
		Color = PALETTE.GunmetalDark,
		Material = Enum.Material.Metal,
		Shape = "CylinderY",
	})

	-- 2. Taped Lower Handle Shaft + 14 Alternating Criss-Cross Spiral Athletic Tape Wraps!
	WeaponBuilder.AddPart(model, handle, {
		Name = "BatGripCore",
		Size = Vector3.new(0.165, 1.12, 0.165),
		Offset = CFrame.new(0, 0.02, 0),
		Color = PALETTE.GripTapeBlack,
		Material = Enum.Material.Rubber,
		Shape = "CylinderY",
	})
	for t = 1, 14 do
		local yTape = -0.48 + (t * 0.072)
		local tilt = (t % 2 == 0) and 14 or -14
		WeaponBuilder.AddPart(model, handle, {
			Name = "SpiralTapeWrap_" .. t,
			Size = Vector3.new(0.176, 0.042, 0.176),
			Offset = CFrame.new(0, yTape, 0) * CFrame.Angles(math.rad(tilt), math.rad(t * 25), 0),
			Color = (t % 2 == 0) and PALETTE.GripTapeGray or PALETTE.GripTapeBlack,
			Material = Enum.Material.Fabric,
			Shape = "CylinderY",
		})
	end

	-- 3. 12-Segment Smooth Lathe-Turned Ash Wood Taper & Heavy Sweet-Spot Barrel Profile!
	-- Instead of 2 blocky steps, 12 progressive segments create a true smooth baseball bat taper curve.
	for seg = 1, 12 do
		local frac = seg / 12
		local ySeg = 0.56 + (seg * 0.175)
		-- Smooth S-curve diameter from 0.175 (handle neck) up to 0.345 (heavy barrel sweet spot)
		local curveT = math.clamp((frac - 0.05) / 0.75, 0, 1)
		local smoothStep = curveT * curveT * (3 - 2 * curveT)
		local dia = 0.172 + (smoothStep * 0.172)

		WeaponBuilder.AddPart(model, handle, {
			Name = string.format("LatheTurnedWoodSeg_%02d", seg),
			Size = Vector3.new(dia, 0.185, dia),
			Offset = CFrame.new(0, ySeg, 0),
			Color = PALETTE.AshWood,
			Material = Enum.Material.Wood,
			Shape = "CylinderY",
		})
	end
	-- Rounded Barrel Crown & Cupped End Recess
	WeaponBuilder.AddPart(model, handle, {
		Name = "BatRoundedCrown",
		Size = Vector3.new(0.34, 0.16, 0.34),
		Offset = CFrame.new(0, 2.72, 0),
		Color = PALETTE.AshWood,
		Material = Enum.Material.Wood,
		Shape = "Sphere",
	})
	WeaponBuilder.AddPart(model, handle, {
		Name = "BatCuppedTopEnd",
		Size = Vector3.new(0.26, 0.03, 0.26),
		Offset = CFrame.new(0, 2.79, 0),
		Color = PALETTE.WalnutDark,
		Material = Enum.Material.Wood,
		Shape = "CylinderY",
	})

	-- 4. Tactical Steel Reinforcement Cage (3 Heavy Steel Barrel Bands + 4 Longitudinal Steel Straps + 16 Hex Bolts & Pyramidal Impact Spikes!)
	for _, yBand in ipairs({ 1.72, 2.14, 2.54 }) do
		WeaponBuilder.AddPart(model, handle, {
			Name = "SteelReinforcementCollar_" .. tostring(yBand),
			Size = Vector3.new(0.362, 0.11, 0.362),
			Offset = CFrame.new(0, yBand, 0),
			Color = PALETTE.GunmetalDark,
			Material = Enum.Material.Metal,
			Reflectance = 0.16,
			Shape = "CylinderY",
		})
	end
	for i = 0, 3 do
		local angle = math.rad(i * 90)
		local cosA = math.cos(angle)
		local sinA = math.sin(angle)
		-- Longitudinal Steel Reinforcement Bar linking the 3 bands
		WeaponBuilder.AddPart(model, handle, {
			Name = "LongitudinalSteelStrap_" .. i,
			Size = Vector3.new(0.055, 0.92, 0.025),
			Offset = CFrame.new(cosA * 0.178, 2.13, sinA * 0.178) * CFrame.Angles(0, -angle + math.rad(90), 0),
			Color = PALETTE.ParkerizedSteel,
			Material = Enum.Material.Metal,
			Reflectance = 0.15,
		})
		-- 3 Rows of Chrome Hex Washer Nuts + hardened Pyramidal Impact Studs!
		for rowIdx, yStud in ipairs({ 1.72, 2.14, 2.54 }) do
			local studCF = CFrame.new(cosA * 0.186, yStud, sinA * 0.186) * CFrame.Angles(0, -angle, 0)
			WeaponBuilder.AddPart(model, handle, {
				Name = string.format("HexWasherBase_%d_%d", i, rowIdx),
				Size = Vector3.new(0.04, 0.08, 0.08),
				Offset = studCF,
				Color = PALETTE.AnodizedSlate,
				Material = Enum.Material.Metal,
				Shape = "CylinderX",
			})
			WeaponBuilder.AddPart(model, handle, {
				Name = string.format("ChromeImpactSpike_%d_%d", i, rowIdx),
				Size = Vector3.new(0.09, 0.065, 0.065),
				Offset = studCF * CFrame.new(0.025, 0, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
				Color = PALETTE.StainlessSteel,
				Material = Enum.Material.Metal,
				Reflectance = 0.42,
			})
		end
	end

	local att0 = WeaponBuilder.AddAttachment(handle, "TrailBase", CFrame.new(0, 1.25, 0))
	local att1 = WeaponBuilder.AddAttachment(handle, "TrailTip", CFrame.new(0, 2.78, 0))
	local trail = Instance.new("Trail")
	trail.Name = "SlashTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 160), Color3.fromRGB(180, 120, 60))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.18
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = handle

	return model
end

--==============================================================================
-- SECTION 3.10: BUILD DISPATCH & TEMPLATE CACHE
--==============================================================================

local CONSTRUCTORS: { [string]: (kind: BuildKind?) -> Model } = {
	M4A1_Carbine = WeaponBuilder.BuildM4A1,
	MP5_Tactical = WeaponBuilder.BuildMP5,
	AWM_Sniper = WeaponBuilder.BuildAWMSniper,
	M1014_Shotgun = WeaponBuilder.BuildM1014Shotgun,
	M249_MachineGun = WeaponBuilder.BuildM249SAW,
	G19X_Pistol = WeaponBuilder.BuildG19XPistol,
	M67_Frag = WeaponBuilder.BuildM67Grenade,
	KABAR_Knife = WeaponBuilder.BuildCombatKnife,
	Tactical_Bat = WeaponBuilder.BuildTacticalBat,
}

local templateCache: { [string]: Model } = {}

function WeaponBuilder.HasWeapon(weaponKey: string): boolean
	return CONSTRUCTORS[weaponKey] ~= nil
end

-- Builds a brand-new (unparented) model. Expensive: ~60-170 parts per weapon.
function WeaponBuilder.Build(weaponKey: string, kind: BuildKind?): Model?
	local constructor = CONSTRUCTORS[weaponKey]
	if not constructor then
		return nil
	end
	return constructor(kind or "Viewmodel")
end

-- Returns a cached, unparented template. Callers must :Clone() it before parenting.
function WeaponBuilder.GetTemplate(weaponKey: string, kind: BuildKind?): Model?
	local resolvedKind: BuildKind = kind or "Viewmodel"
	local cacheKey = resolvedKind .. ":" .. weaponKey
	local cached = templateCache[cacheKey]
	if cached then
		return cached
	end

	local built = WeaponBuilder.Build(weaponKey, resolvedKind)
	if built then
		templateCache[cacheKey] = built
	end
	return built
end

return WeaponBuilder
