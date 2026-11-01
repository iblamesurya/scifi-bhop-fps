--!strict
-- AeroStrike_Lobby_Rebuilder_And_Controller.server.luau
-- Manages turf color/z-fighting, bridges, watchtowers, walk-in citadel HQ, helipads, and runtime lobby gameplay.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local lobby: Instance? = Workspace:FindFirstChild("AeroStrike_SkyIsland_Lobby")
if not lobby or lobby.Name ~= "AeroStrike_SkyIsland_Lobby" then
	local waited = Workspace:WaitForChild("AeroStrike_SkyIsland_Lobby", 5)
	if waited and waited.Name == "AeroStrike_SkyIsland_Lobby" then
		lobby = waited
	else
		warn("[AeroStrike] AeroStrike_SkyIsland_Lobby folder not found!")
		return
	end
end

local targetLobby = lobby :: Instance

if targetLobby:GetAttribute("AeroStrikeRebuilderApplied") == true then
	-- Rebuilder already ran; only attach runtime controller if not already connected
	if targetLobby:GetAttribute("AeroStrikeControllerConnected") == true then
		return
	end
end
targetLobby:SetAttribute("AeroStrikeRebuilderApplied", true)
targetLobby:SetAttribute("AeroStrikeControllerConnected", true)

local fCentral = targetLobby:FindFirstChild("01_Central_Command_Island")
local fDeploy = targetLobby:FindFirstChild("02_Deployment_Matchmaking_Island")
local fArmory = targetLobby:FindFirstChild("03_Armory_And_Crate_Island")
local fRange = targetLobby:FindFirstChild("04_LiveFire_Range_And_Killhouse_Island")
local fVIP = targetLobby:FindFirstChild("05_Hall_Of_Legends_VIP_Island")
local fParkour = targetLobby:FindFirstChild("06_Sky_Parkour_And_Airspace")

local function makePart(
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

local function translateTree(inst: Instance?, deltaVec: Vector3): ()
	if not inst then
		return
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + deltaVec
		end
	end
end

-- ============================================================================
-- 1. TURF COLOR, Z-FIGHTING & ISLAND CURB FIXES AT BRIDGE APPROACHES
-- ============================================================================
local bridgeCurbs: { [string]: { [string]: boolean } } = {
	CentralIsland_Terrain = { CliffCurb_1 = true, CliffCurb_5 = true, CliffCurb_9 = true, CliffCurb_13 = true },
	DeploymentIsland_Terrain = { CliffCurb_1 = true, CliffCurb_9 = true },
	ArmoryIsland_Terrain = { CliffCurb_5 = true },
	RangeIsland_Terrain = { CliffCurb_13 = true },
	VIPIsland_Terrain = { CliffCurb_9 = true },
}

for _, d in ipairs(targetLobby:GetDescendants()) do
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

-- Add paved concrete walkways from plazas to bridge mouths
local concreteCol = Color3.fromRGB(206, 214, 224)
makePart(fCentral, "NorthBridgeWalkway", CFrame.new(0, 600.15, -96.5), Vector3.new(26, 0.3, 26), Enum.Material.Concrete, concreteCol)
makePart(fCentral, "SouthBridgeWalkway", CFrame.new(0, 600.15, 93.0), Vector3.new(22, 0.3, 38), Enum.Material.Concrete, concreteCol)
makePart(fCentral, "WestBridgeWalkway", CFrame.new(-90, 600.15, 0), Vector3.new(44, 0.3, 20), Enum.Material.Concrete, concreteCol)
makePart(fCentral, "EastBridgeWalkway", CFrame.new(90, 600.15, 0), Vector3.new(44, 0.3, 20), Enum.Material.Concrete, concreteCol)
makePart(fDeploy, "SouthBridgeApproach", CFrame.new(0, 610.20, -184), Vector3.new(26, 0.4, 28), Enum.Material.Concrete, concreteCol)
makePart(fArmory, "EastBridgeApproach", CFrame.new(-177, 608.2, 0), Vector3.new(24, 0.4, 20), Enum.Material.DiamondPlate, Color3.fromRGB(82, 92, 108))
makePart(fRange, "WestBridgeApproach", CFrame.new(175, 608.2, 0), Vector3.new(20, 0.4, 20), Enum.Material.Concrete, concreteCol)
makePart(fVIP, "NorthBridgeApproach", CFrame.new(0, 622.2, 172), Vector3.new(22, 0.4, 22), Enum.Material.Marble, Color3.fromRGB(235, 235, 240))

-- ============================================================================
-- 2. SLOPED BRIDGE CURBS & GANTRY PILLAR ALIGNMENT
-- ============================================================================
for _, m in ipairs(targetLobby:GetDescendants()) do
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

-- ============================================================================
-- 3. WATCHTOWER RELOCATION, EXTERIOR TRUSS LADDER & CABIN DOORWAY
-- ============================================================================
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

-- ============================================================================
-- 4. WALK-IN CITADEL HQ: STAIR LANDINGS, ATC DOORS, ROOF CATWALKS & LIGHTING
-- ============================================================================
local citadel = if fCentral then fCentral:FindFirstChild("Citadel_Command_HQ_WalkIn") else nil
if citadel then
	local slateCol = Color3.fromRGB(82, 92, 108)
	local darkMetal = Color3.fromRGB(42, 48, 58)
	local glassCol = Color3.fromRGB(38, 166, 204)

	makePart(citadel, "Floor2_WestNorthLanding", CFrame.new(-26.5, 618.0, -79.90), Vector3.new(9.0, 1.2, 8.2), Enum.Material.Concrete, slateCol)
	makePart(citadel, "Floor2_WestSouthLanding", CFrame.new(-26.5, 618.0, -44.75), Vector3.new(9.0, 1.2, 9.5), Enum.Material.Concrete, slateCol)
	makePart(citadel, "Floor2_EastNorthLanding", CFrame.new(26.5, 618.0, -79.90), Vector3.new(9.0, 1.2, 8.2), Enum.Material.Concrete, slateCol)
	makePart(citadel, "Floor2_EastSouthLanding", CFrame.new(26.5, 618.0, -44.75), Vector3.new(9.0, 1.2, 9.5), Enum.Material.Concrete, slateCol)

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
			makePart(citadel, wSpec.Name .. "_South", CFrame.new(wx, 626.5, -49.0), Vector3.new(2.0, 16.0, 14.0), Enum.Material.Concrete, slateCol)
			makePart(citadel, wSpec.Name .. "_DoorHeader", CFrame.new(wx, 632.0, -62.0), Vector3.new(2.2, 5.0, 12.0), Enum.Material.Metal, darkMetal)
		end
	end

	makePart(citadel, "CitadelRoofLanding_W", CFrame.new(-45.5, 634.5, -78.25), Vector3.new(13.0, 1.4, 9.5), Enum.Material.DiamondPlate, slateCol)
	makePart(citadel, "CitadelRoofLanding_E", CFrame.new(45.5, 634.5, -78.25), Vector3.new(13.0, 1.4, 9.5), Enum.Material.DiamondPlate, slateCol)
	makePart(citadel, "RoofLandingRail_WN", CFrame.new(-45.5, 636.8, -82.7), Vector3.new(13.0, 3.2, 0.5), Enum.Material.Glass, glassCol, 0.45)
	makePart(citadel, "RoofLandingRail_WW", CFrame.new(-51.75, 636.8, -78.25), Vector3.new(0.5, 3.2, 9.5), Enum.Material.Glass, glassCol, 0.45)
	makePart(citadel, "RoofLandingRail_EN", CFrame.new(45.5, 636.8, -82.7), Vector3.new(13.0, 3.2, 0.5), Enum.Material.Glass, glassCol, 0.45)
	makePart(citadel, "RoofLandingRail_EE", CFrame.new(51.75, 636.8, -78.25), Vector3.new(0.5, 3.2, 9.5), Enum.Material.Glass, glassCol, 0.45)

	makePart(citadel, "Floor2_WestTerraceRail_W", CFrame.new(-66.7, 620.2, -62.0), Vector3.new(0.6, 3.2, 44.0), Enum.Material.Glass, glassCol, 0.45)
	makePart(citadel, "Floor2_EastTerraceRail_E", CFrame.new(66.7, 620.2, -62.0), Vector3.new(0.6, 3.2, 44.0), Enum.Material.Glass, glassCol, 0.45)

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
		local fix = makePart(citadel, "InteriorCeilingFixture_" .. idx, CFrame.new(lPos), Vector3.new(12, 0.3, 1.8), Enum.Material.Neon, Color3.fromRGB(225, 242, 255), 0, false)
		if fix then
			local pl = Instance.new("PointLight")
			pl.Brightness = 1.6
			pl.Range = 38
			pl.Color = Color3.fromRGB(235, 245, 255)
			pl.Parent = fix
		end
	end
end

-- ============================================================================
-- 5. HELIPAD RAMP, DROPSHIP BOARDING RAMP, ARMORY RACKS, RANGE & VIP FIXES
-- ============================================================================
local neck = if fDeploy then fDeploy:FindFirstChild("HelipadBridgeNeck") :: BasePart? else nil
if neck then
	neck.Size = Vector3.new(28.0, 2.0, 20.0)
	neck.CFrame = CFrame.new(0, 609.4, -318.0)
	makePart(fDeploy, "HelipadAscentRamp", CFrame.new(0, 611.325, -323.5) * CFrame.Angles(0, math.pi, 0), Vector3.new(28.0, 1.85, 9.0), Enum.Material.DiamondPlate, Color3.fromRGB(82, 92, 108), 0, true, "WedgePart")
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
			makePart(munPav, "RackStandA_" .. cat.Name, CFrame.new(-281.6, 613.55, cat.Z - 2.4), Vector3.new(0.45, 2.5, 1.2), Enum.Material.Metal, Color3.fromRGB(42, 48, 58))
		end
		if wB then
			translateTree(wB, Vector3.new(1.6, 0, -1.2))
			makePart(munPav, "RackStandB_" .. cat.Name, CFrame.new(-278.4, 613.55, cat.Z + 2.4), Vector3.new(0.45, 2.5, 1.2), Enum.Material.Metal, Color3.fromRGB(42, 48, 58))
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
			makePart(pod, "PreviewGunProjector", CFrame.new(-244.0, 610.3, pz), Vector3.new(1.8, 1.6, 1.8), Enum.Material.Metal, Color3.fromRGB(42, 48, 58))
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
			makePart(rangePav, "RifleRest_" .. i, CFrame.new(204.2, 612.45, bench.Position.Z), Vector3.new(1.6, 0.5, 1.2), Enum.Material.Metal, Color3.fromRGB(42, 48, 58))
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
				makePart(tc, "TrophyDisplayStand", CFrame.new(ped.Position.X, 626.3, ped.Position.Z - 0.4), Vector3.new(0.5, 1.8, 1.8), Enum.Material.Metal, Color3.fromRGB(255, 208, 38))
			end
		end
	end
end

for _, jpName in ipairs({ "JumpPad_To_Armory", "JumpPad_To_Range", "JumpPad_Armory_To_Plaza", "JumpPad_Range_To_Plaza" }) do
	local jp = targetLobby:FindFirstChild(jpName, true)
	if jp then
		local sign = jp:FindFirstChild("PadHoloSign") :: BasePart?
		if sign then
			sign.CFrame = CFrame.new(sign.Position) * CFrame.Angles(0, math.pi * 0.5, 0)
		end
	end
end

-- ============================================================================
-- 6. REBUILD SKY PARKOUR COURSE (UNOBSTRUCTED SUMMIT TRAJECTORY) & CLOUDS
-- ============================================================================
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

-- ============================================================================
-- 7. RUNTIME GAMEPLAY CONTROLLER (JUMPPADS, ROTORS & MOVING RANGE TARGETS)
-- ============================================================================
local padCooldowns: { [Model]: number } = {}
for _, d in ipairs(targetLobby:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "JumpTrigger" then
		local targetVal = d:FindFirstChild("TargetPosition")
		if targetVal and targetVal:IsA("Vector3Value") then
			d.Touched:Connect(function(hit: BasePart)
				local char = hit.Parent
				if not char or not char:IsA("Model") then
					return
				end
				local hum = char:FindFirstChildOfClass("Humanoid")
				local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hum and rootPart then
					local now = os.clock()
					if (padCooldowns[char] or 0) > now then
						return
					end
					padCooldowns[char] = now + 0.85
					local g = Vector3.new(0, -Workspace.Gravity, 0)
					local flightTime = 1.35
					local delta = targetVal.Value - rootPart.Position
					local v0 = (delta - 0.5 * g * (flightTime * flightTime)) / flightTime
					hum.Jump = true
					rootPart.AssemblyLinearVelocity = v0
				end
			end)
		end
	elseif d:IsA("BasePart") and d.Name == "MovingTarget" then
		local startCF = d.CFrame
		local tweenInfo = TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(d, tweenInfo, { CFrame = startCF + Vector3.new(0, 0, 4.5) }):Play()
	end
end

local spinningParts: { BasePart } = {}
for _, d in ipairs(targetLobby:GetDescendants()) do
	if d:IsA("BasePart") and (d.Name == "SpinningRotor" or d.Name == "HoloGlobe") then
		table.insert(spinningParts, d)
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	local stepRot = CFrame.Angles(0, dt * 4.5, 0)
	for _, p in ipairs(spinningParts) do
		p.CFrame = p.CFrame * stepRot
	end
end)
