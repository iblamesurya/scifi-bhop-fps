--!strict
-- AeroStrike_Lobby_Rebuilder_And_Controller.server.luau
-- 70/20/10 Aerospace Tactical Palette, De-slopping, Geometry Rebuilder & Runtime Controller.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
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
	if targetLobby:GetAttribute("AeroStrikeControllerConnected") == true then
		return
	end
end
targetLobby:SetAttribute("AeroStrikeRebuilderApplied", true)
targetLobby:SetAttribute("AeroStrikeControllerConnected", true)
local lobby = targetLobby

local fCentral = targetLobby:FindFirstChild("01_Central_Command_Island")
local fDeploy  = targetLobby:FindFirstChild("02_Deployment_Matchmaking_Island")
local fArmory  = targetLobby:FindFirstChild("03_Armory_And_Crate_Island")
local fRange   = targetLobby:FindFirstChild("04_LiveFire_Range_And_Killhouse_Island")
local fVIP     = targetLobby:FindFirstChild("05_Hall_Of_Legends_VIP_Island")
local fParkour = targetLobby:FindFirstChild("06_Sky_Parkour_And_Airspace")

-- ============================================================================
-- 0. GLOBAL 70/20/10 TACTICAL AEROSPACE PALETTE & UTILITIES
-- ============================================================================
local PALETTE = {
	-- 70% Neutral Architecture & Natural Strata
	BaseConcrete   = Color3.fromRGB(158, 164, 172),
	AlpineTurf     = Color3.fromRGB(62, 84, 66),
	CliffStrata    = Color3.fromRGB(58, 63, 70),
	CanopyOlive    = Color3.fromRGB(68, 88, 64),
	BarkDark       = Color3.fromRGB(72, 58, 46),

	-- 20% Structural Metal & Framing
	HeavyFraming   = Color3.fromRGB(34, 38, 44),
	PolymerDark    = Color3.fromRGB(38, 42, 48),
	SteelTarget    = Color3.fromRGB(42, 46, 52),
	GunshipGray    = Color3.fromRGB(52, 58, 66),
	SmokedGlass    = Color3.fromRGB(28, 36, 44),
	HudBackground  = Color3.fromRGB(18, 22, 28),

	-- 10% Functional Directional Accents
	NorthAmber     = Color3.fromRGB(235, 115, 32),  -- Play / Deploy
	WestCerulean   = Color3.fromRGB(56, 152, 212),  -- Loadout / Gear
	EastCrimson    = Color3.fromRGB(218, 68, 68),   -- Range / Warmup
	SouthBrass     = Color3.fromRGB(198, 162, 78),  -- Prestige / VIP

	-- Sub-Accents (VIP, Crates, Ranked, Dropship)
	RankedGold     = Color3.fromRGB(245, 222, 138),
	RescueMarking  = Color3.fromRGB(195, 95, 38),
	ObsidianMarble = Color3.fromRGB(28, 30, 36),
	CrimsonVelvet  = Color3.fromRGB(125, 24, 32),
	CrateStandard  = Color3.fromRGB(110, 142, 168), -- Steel Blue
	CrateTactical  = Color3.fromRGB(56, 128, 204),  -- Cobalt
	CrateElite     = Color3.fromRGB(142, 82, 188),  -- Amethyst
	CrateMythic    = Color3.fromRGB(198, 162, 78),  -- Burnished Gold
}

local function makePart(parent, name, cframe, size, mat, color, trans, canCollide, className)
	local existing = parent and parent:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		existing:Destroy()
	end
	local p = Instance.new(className or "Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = (canCollide == nil) and true or canCollide
	p.CastShadow = (trans or 0) < 0.5
	p.Transparency = trans or 0
	p.Material = mat or Enum.Material.Concrete
	p.Color = color or PALETTE.BaseConcrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local function translateTree(inst, deltaVec)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + deltaVec
		end
	end
end

local function stripEmojis(str)
	if type(str) ~= "string" then return "" end
	local cleaned = str
	local emojiList = {"⚡", "🔫", "🎯", "🏆", "✈️", "🎖️", "🔥", "⭐", "🚀", "💀", "🛡️", "⚔️", "💎", "👑", "🔊", "✅", "⚠️"}
	for _, em in ipairs(emojiList) do
		cleaned = string.gsub(cleaned, em, "")
	end
	-- Strip remaining high-plane UTF-8 emoji sequences (F0 9F .. ..)
	cleaned = string.gsub(cleaned, "[\240][\159][\128-\191][\128-\191]", "")
	cleaned = string.gsub(cleaned, "^%s+", "")
	cleaned = string.gsub(cleaned, "%s+$", "")
	cleaned = string.gsub(cleaned, "%s%s+", " ")
	return cleaned
end

local function attachPrompt(parent, name, actionText, objectText, maxDist, holdDuration)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = maxDist or 10
	prompt.HoldDuration = holdDuration or 0
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = parent
	return prompt
end

local function colorClose(c1, r, g, b, tol)
	tol = tol or 18
	return math.abs(c1.R * 255 - r) <= tol
		and math.abs(c1.G * 255 - g) <= tol
		and math.abs(c1.B * 255 - b) <= tol
end

-- ============================================================================
-- 1. GLOBAL DE-SLOPPING PASS: NEON PRUNING, PALETTE & SIGNAGE TYPOGRAPHY
-- ============================================================================
for _, d in ipairs(lobby:GetDescendants()) do
	if d:IsA("BasePart") then
		local n = d.Name

		-- Prune structural Neon curbs, stair nosings, perimeter bars, octagon rings
		if string.find(n, "^PerimeterNeon_")
			or string.find(n, "^StepNose_")
			or string.find(n, "InnerPlazaOctagonRing")
			or string.find(n, "Curb")
			or string.find(n, "Pylon")
			or string.find(n, "Truss")
			or string.find(n, "GantryPillar")
			or string.find(n, "GantryHeader")
		then
			d.Material = Enum.Material.Metal
			d.Color = PALETTE.HeavyFraming
			d.Reflectance = 0.05

		elseif string.find(n, "StrataCore") or string.find(n, "CliffCrag") then
			d.Material = Enum.Material.Slate
			d.Color = PALETTE.CliffStrata

		elseif d.Material == Enum.Material.Concrete or colorClose(d.Color, 206, 214, 224, 20) then
			d.Material = Enum.Material.Concrete
			d.Color = PALETTE.BaseConcrete

		elseif colorClose(d.Color, 42, 48, 58, 12) then
			d.Material = Enum.Material.Metal
			d.Color = PALETTE.HeavyFraming
		end

		-- Catch remaining non-exempt Neon parts and convert to brushed metal unless functional
		if d.Material == Enum.Material.Neon then
			local isExempt = (n == "JumpTrigger")
				or (n == "QueuePad")
				or string.find(n, "PortalCore")
				or string.find(n, "PortalField")
				or string.find(n, "FloodlightFixture")
				or string.find(n, "CeilingLight")
				or string.find(n, "InteriorCeilingFixture")
				or string.find(n, "GantryLight")
				or string.find(n, "BridgeNeonTop")
				or string.find(n, "ParkourPad")
				or string.find(n, "LeadingLine")
			if not isExempt then
				d.Material = Enum.Material.Metal
				d.Color = PALETTE.HeavyFraming
			end
		end

	elseif d:IsA("TextLabel") then
		d.Text = stripEmojis(d.Text)
		if d.TextSize >= 28 or string.find(d.Name, "Header") or string.find(d.Name, "Title") then
			d.Font = Enum.Font.Michroma
		else
			d.Font = Enum.Font.RobotoMono
		end
		if colorClose(d.BackgroundColor3, 42, 48, 58, 20) then
			d.BackgroundColor3 = PALETTE.HudBackground
			d.BackgroundTransparency = math.max(d.BackgroundTransparency, 0.15)
		end
		-- Replace neon purple UI text (186, 72, 255) or radioactive yellow
		if colorClose(d.TextColor3, 186, 72, 255, 30) or colorClose(d.TextColor3, 255, 208, 24, 30) then
			d.TextColor3 = Color3.fromRGB(230, 236, 242)
		end
	elseif d:IsA("Frame") then
		if colorClose(d.BackgroundColor3, 42, 48, 58, 20) then
			d.BackgroundColor3 = PALETTE.HudBackground
		end
	end
end

-- ============================================================================
-- 2. TERRAIN DE-PROCEDURING, TURF COLOR, Z-FIGHTING & BRIDGE APPROACHES
-- ============================================================================
local bridgeCurbs = {
	CentralIsland_Terrain    = {CliffCurb_1=true, CliffCurb_5=true, CliffCurb_9=true, CliffCurb_13=true},
	DeploymentIsland_Terrain = {CliffCurb_1=true, CliffCurb_9=true},
	ArmoryIsland_Terrain     = {CliffCurb_5=true},
	RangeIsland_Terrain      = {CliffCurb_13=true},
	VIPIsland_Terrain        = {CliffCurb_9=true},
}

for _, d in ipairs(lobby:GetDescendants()) do
	if d:IsA("Model") and string.find(d.Name, "Terrain") then
		local t1 = d:FindFirstChild("TurfTop_OctBar_1")
		local baseY = t1 and t1.Position.Y or nil
		for i = 1, 8 do
			local bar = d:FindFirstChild("TurfTop_OctBar_" .. i)
			if bar and baseY then
				bar.CFrame = CFrame.new(bar.Position.X, baseY - (i - 1) * 0.02, bar.Position.Z) * bar.CFrame.Rotation
				bar.Material = Enum.Material.Grass
				bar.Color = PALETTE.AlpineTurf
			end
		end

		-- Convert PerimeterNeon_1..16 into dark gunmetal blast-shield coping
		for i = 1, 16 do
			local pNeon = d:FindFirstChild("PerimeterNeon_" .. i)
			if pNeon and pNeon:IsA("BasePart") then
				pNeon.Material = Enum.Material.Metal
				pNeon.Color = PALETTE.HeavyFraming
			end
			local vPylon = d:FindFirstChild("VertexPylon_" .. i)
			if vPylon and vPylon:IsA("BasePart") then
				vPylon.Material = Enum.Material.Metal
				vPylon.Color = PALETTE.HeavyFraming
			end
			local cCurb = d:FindFirstChild("CliffCurb_" .. i)
			if cCurb and cCurb:IsA("BasePart") then
				cCurb.Material = Enum.Material.Concrete
				cCurb.Color = PALETTE.BaseConcrete
			end
		end

		-- De-procedure CliffCrag rock parts so cliff face reads like fractured basalt
		local cragIdx = 0
		for _, ch in ipairs(d:GetChildren()) do
			if ch:IsA("BasePart") and string.find(ch.Name, "CliffCrag") then
				cragIdx += 1
				ch.Material = Enum.Material.Slate
				ch.Color = PALETTE.CliffStrata
				if not ch:GetAttribute("DeProcedured") then
					ch:SetAttribute("DeProcedured", true)
					local scaleX = 0.85 + ((cragIdx * 17) % 35) * 0.01
					local scaleY = 0.90 + ((cragIdx * 29) % 40) * 0.01
					local scaleZ = 0.75 + ((cragIdx * 43) % 65) * 0.01
					ch.Size = Vector3.new(ch.Size.X * scaleX, ch.Size.Y * scaleY, ch.Size.Z * scaleZ)
					local pitch = math.rad(((cragIdx * 23) % 28) - 14)
					local yaw   = math.rad(((cragIdx * 47) % 36) - 18)
					local roll  = math.rad(((cragIdx * 31) % 24) - 12)
					ch.CFrame = ch.CFrame * CFrame.Angles(pitch, yaw, roll)
				end
			end
		end

		local curbMap = bridgeCurbs[d.Name]
		if curbMap then
			for cname, _ in pairs(curbMap) do
				local curb = d:FindFirstChild(cname)
				if curb and not curb:GetAttribute("CurbLowered") then
					curb:SetAttribute("CurbLowered", true)
					curb.CFrame = curb.CFrame - Vector3.new(0, 0.35, 0)
				end
			end
		end
	end
end

-- Add paved concrete walkways from plazas to bridge mouths
makePart(fCentral, "NorthBridgeWalkway", CFrame.new(0, 600.15, -96.5), Vector3.new(26, 0.3, 26), Enum.Material.Concrete, PALETTE.BaseConcrete)
makePart(fCentral, "SouthBridgeWalkway", CFrame.new(0, 600.15, 93.0),  Vector3.new(22, 0.3, 38), Enum.Material.Concrete, PALETTE.BaseConcrete)
makePart(fCentral, "WestBridgeWalkway",  CFrame.new(-90, 600.15, 0),   Vector3.new(44, 0.3, 20), Enum.Material.Concrete, PALETTE.BaseConcrete)
makePart(fCentral, "EastBridgeWalkway",  CFrame.new(90, 600.15, 0),    Vector3.new(44, 0.3, 20), Enum.Material.Concrete, PALETTE.BaseConcrete)
makePart(fDeploy,  "SouthBridgeApproach", CFrame.new(0, 610.20, -184), Vector3.new(26, 0.4, 28), Enum.Material.Concrete, PALETTE.BaseConcrete)
makePart(fArmory,  "EastBridgeApproach",  CFrame.new(-177, 608.2, 0),  Vector3.new(24, 0.4, 20), Enum.Material.DiamondPlate, PALETTE.HeavyFraming)
makePart(fRange,   "WestBridgeApproach",  CFrame.new(175, 608.2, 0),   Vector3.new(20, 0.4, 20), Enum.Material.Concrete, PALETTE.BaseConcrete)
makePart(fVIP,     "NorthBridgeApproach", CFrame.new(0, 622.2, 172),   Vector3.new(22, 0.4, 22), Enum.Material.Marble, PALETTE.ObsidianMarble)

-- ============================================================================
-- 3. SLOPED BRIDGE CURBS, GANTRY ALIGNMENT & SEMANTIC CARDINAL ACCENTS
-- ============================================================================
for _, m in ipairs(lobby:GetDescendants()) do
	if m:IsA("Model") and string.find(m.Name, "Bridge") then
		local accentCol = PALETTE.NorthAmber
		local accentMat = Enum.Material.Neon
		if string.find(m.Name, "West") or string.find(m.Name, "Armory") then
			accentCol = PALETTE.WestCerulean
		elseif string.find(m.Name, "East") or string.find(m.Name, "Range") then
			accentCol = PALETTE.EastCrimson
		elseif string.find(m.Name, "South") or string.find(m.Name, "VIP") then
			accentCol = PALETTE.SouthBrass
			accentMat = Enum.Material.Metal
		end

		local deck = m:FindFirstChild("BridgeRoadDeck")
		if deck then
			deck.Material = Enum.Material.Concrete
			deck.Color = PALETTE.BaseConcrete
			local dCF = deck.CFrame
			local halfW = deck.Size.X * 0.5
			for _, ch in ipairs(m:GetChildren()) do
				if ch:IsA("BasePart") then
					local sign = string.find(ch.Name, "%-1") and -1 or 1
					if string.find(ch.Name, "BridgeCurb_") then
						ch.CFrame = dCF * CFrame.new(sign * (halfW - 0.9), 1.40, 0)
						ch.Material = Enum.Material.Metal
						ch.Color = PALETTE.HeavyFraming
					elseif string.find(ch.Name, "BridgeNeonTop_") then
						ch.CFrame = dCF * CFrame.new(sign * (halfW - 0.9), 2.45, 0)
						ch.Material = accentMat
						ch.Color = accentCol
						if accentMat == Enum.Material.Metal then
							ch.Reflectance = 0.25
						end
					elseif string.find(ch.Name, "BridgeForceWall_") then
						ch.CFrame = dCF * CFrame.new(sign * (halfW - 0.9), 4.00, 0)
					elseif string.find(ch.Name, "GantryPillar_") then
						local localPos = dCF:PointToObjectSpace(ch.Position)
						ch.Size = Vector3.new(ch.Size.X, 11.2, ch.Size.Z)
						ch.CFrame = dCF * CFrame.new(localPos.X, 6.60, localPos.Z)
						ch.Material = Enum.Material.Metal
						ch.Color = PALETTE.HeavyFraming
					elseif string.find(ch.Name, "GantryHeader_") then
						local localPos = dCF:PointToObjectSpace(ch.Position)
						ch.CFrame = dCF * CFrame.new(localPos.X, 12.60, localPos.Z)
						ch.Material = Enum.Material.Metal
						ch.Color = PALETTE.HeavyFraming
					elseif string.find(ch.Name, "GantryLight_") then
						local localPos = dCF:PointToObjectSpace(ch.Position)
						ch.CFrame = dCF * CFrame.new(localPos.X, 11.40, localPos.Z)
						ch.Material = accentMat
						ch.Color = accentCol
					end
				end
			end
		end
	end
end

-- ============================================================================
-- 4. ONBOARDING UX: SIGHTLINE FIX, FLOOR CHEVRON LINES & 3-STEP HOLOGRAM
-- ============================================================================
if fCentral then
	-- 4A. 70% Open-Deck Sightline Rule: Shrink DirectionHubSign & open 36-stud lane
	local dirSign = fCentral:FindFirstChild("DirectionHubSign", true)
	if dirSign then
		if dirSign:IsA("BasePart") then
			dirSign.Size = Vector3.new(11.0, 1.8, 11.0)
			dirSign.CFrame = CFrame.new(0, 624.5, dirSign.Position.Z)
			dirSign.Material = Enum.Material.Glass
			dirSign.Color = PALETTE.SmokedGlass
			dirSign.Transparency = 0.65
			dirSign.CanCollide = false
		elseif dirSign:IsA("Model") then
			for _, p in ipairs(dirSign:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Size = Vector3.new(math.min(p.Size.X, 11), math.min(p.Size.Y, 1.8), math.min(p.Size.Z, 11))
					p.Material = Enum.Material.Glass
					p.Color = PALETTE.SmokedGlass
					p.Transparency = 0.65
					p.CanCollide = false
				end
			end
		end
	end

	-- Clear 36-stud central corridor lane running straight from Spawn Ring through Breezeway
	makePart(fCentral, "CentralBreezewayCorridor", CFrame.new(0, 600.16, -34.0), Vector3.new(36.0, 0.3, 108.0), Enum.Material.Concrete, PALETTE.BaseConcrete)

	-- 4B. Floor Chevron Leading Lines (Zero-Reading Navigation from (0, 600.3, 18))
	local navFolder = fCentral:FindFirstChild("Onboarding_Navigation_Lines") or Instance.new("Folder")
	navFolder.Name = "Onboarding_Navigation_Lines"
	navFolder.Parent = fCentral
	navFolder:ClearAllChildren()

	-- Primary Double-Amber Line (North -> Matchmaking)
	makePart(navFolder, "LeadingLine_North_L", CFrame.new(-0.9, 600.32, -45.0), Vector3.new(0.6, 0.08, 126.0), Enum.Material.Neon, PALETTE.NorthAmber, 0, false)
	makePart(navFolder, "LeadingLine_North_R", CFrame.new( 0.9, 600.32, -45.0), Vector3.new(0.6, 0.08, 126.0), Enum.Material.Neon, PALETTE.NorthAmber, 0, false)

	-- Blue Line (West -> Loadouts & Skin Crates)
	makePart(navFolder, "LeadingLine_West_Stem",   CFrame.new(-34.0, 600.32, 18.0), Vector3.new(68.0, 0.08, 0.6), Enum.Material.Neon, PALETTE.WestCerulean, 0, false)
	makePart(navFolder, "LeadingLine_West_Corner", CFrame.new(-68.0, 600.32, 9.0),  Vector3.new(0.6, 0.08, 18.0), Enum.Material.Neon, PALETTE.WestCerulean, 0, false)
	makePart(navFolder, "LeadingLine_West_Bridge", CFrame.new(-88.0, 600.32, 0.0),  Vector3.new(40.0, 0.08, 0.6), Enum.Material.Neon, PALETTE.WestCerulean, 0, false)

	-- Red Line (East -> Aim Warmup & Killhouse)
	makePart(navFolder, "LeadingLine_East_Stem",   CFrame.new(34.0, 600.32, 18.0), Vector3.new(68.0, 0.08, 0.6), Enum.Material.Neon, PALETTE.EastCrimson, 0, false)
	makePart(navFolder, "LeadingLine_East_Corner", CFrame.new(68.0, 600.32, 9.0),  Vector3.new(0.6, 0.08, 18.0), Enum.Material.Neon, PALETTE.EastCrimson, 0, false)
	makePart(navFolder, "LeadingLine_East_Bridge", CFrame.new(88.0, 600.32, 0.0),  Vector3.new(40.0, 0.08, 0.6), Enum.Material.Neon, PALETTE.EastCrimson, 0, false)

	-- Brushed Brass Line (South -> Hall of Legends VIP)
	makePart(navFolder, "LeadingLine_South_VIP", CFrame.new(0.0, 600.32, 64.0), Vector3.new(0.6, 0.08, 92.0), Enum.Material.Metal, PALETTE.SouthBrass, 0, false)

	-- 4C. 3-Step Diegetic "How to Play" Hologram at Spawn (Y = 606.5)
	local holoMon = fCentral:FindFirstChild("Central_Hologram_Monument") or fCentral
	local hudBoard = makePart(
		holoMon,
		"HowToPlay_TacticalHUD",
		CFrame.new(0, 606.5, 4.0),
		Vector3.new(22.0, 5.2, 0.35),
		Enum.Material.Glass,
		PALETTE.SmokedGlass,
		0.35,
		false
	)

	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local sgui = Instance.new("SurfaceGui")
		sgui.Name = "OnboardingHUD_" .. face.Name
		sgui.Face = face
		sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sgui.PixelsPerStud = 45
		sgui.AlwaysOnTop = false
		sgui.Parent = hudBoard

		local steps = {
			{
				title = "STEP 1 — EQUIP (WEST)",
				desc  = "Customize rifles, optics & skins at the Armory.",
				col   = PALETTE.WestCerulean,
				pos   = 0.02,
			},
			{
				title = "STEP 2 — WARM UP (EAST)",
				desc  = "Test recoil & movement in the 75m Range or CQB Killhouse.",
				col   = PALETTE.EastCrimson,
				pos   = 0.35,
			},
			{
				title = "STEP 3 — DEPLOY (NORTH)",
				desc  = "Step onto a Matchmaking Pad (5v5, Ranked, FFA) to launch.",
				col   = PALETTE.NorthAmber,
				pos   = 0.68,
			},
		}

		for _, st in ipairs(steps) do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.30, 0, 0.88, 0)
			card.Position = UDim2.new(st.pos, 0, 0.06, 0)
			card.BackgroundColor3 = PALETTE.HudBackground
			card.BackgroundTransparency = 0.15
			card.BorderSizePixel = 0
			card.Parent = sgui

			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(1, 0, 0.08, 0)
			bar.BackgroundColor3 = st.col
			bar.BorderSizePixel = 0
			bar.Parent = card

			local hdr = Instance.new("TextLabel")
			hdr.Size = UDim2.new(0.92, 0, 0.34, 0)
			hdr.Position = UDim2.new(0.04, 0, 0.12, 0)
			hdr.BackgroundTransparency = 1
			hdr.Font = Enum.Font.Michroma
			hdr.Text = st.title
			hdr.TextColor3 = st.col
			hdr.TextScaled = true
			hdr.TextXAlignment = Enum.TextXAlignment.Left
			hdr.Parent = card

			local body = Instance.new("TextLabel")
			body.Size = UDim2.new(0.92, 0, 0.46, 0)
			body.Position = UDim2.new(0.04, 0, 0.48, 0)
			body.BackgroundTransparency = 1
			body.Font = Enum.Font.RobotoMono
			body.Text = st.desc
			body.TextColor3 = Color3.fromRGB(225, 232, 240)
			body.TextScaled = true
			body.TextWrapped = true
			body.TextXAlignment = Enum.TextXAlignment.Left
			body.Parent = card
		end
	end
end

-- ============================================================================
-- 5. ISLAND 01: CENTRAL COMMAND (DE-CLUTTER, FOLIAGE, WATCHTOWERS & CITADEL)
-- ============================================================================
if fCentral then
	-- Push APCs and Cargo Containers outward by 8 studs toward island perimeter (X = ±66)
	local plazaShifts = {
		ReconAPC_Blue_West      = Vector3.new(-8, 0, 0),
		CargoContainer_Blue_W   = Vector3.new(-8, 0, 0),
		ReconAPC_Orange_East    = Vector3.new( 8, 0, 0),
		CargoContainer_Orange_E = Vector3.new( 8, 0, 0),
	}
	for mName, delta in pairs(plazaShifts) do
		local m = fCentral:FindFirstChild(mName)
		if m and not m:GetAttribute("OutwardShifted") then
			m:SetAttribute("OutwardShifted", true)
			translateTree(m, delta)
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then
					if p.Material == Enum.Material.Neon then
						p.Material = Enum.Material.Metal
					end
					if colorClose(p.Color, 255, 108, 28, 30) or colorClose(p.Color, 32, 162, 255, 30) then
						p.Color = PALETTE.GunshipGray
					end
				end
			end
		end
	end

	-- Replace blocky neon-green foliage on CentralTree models with olive-drab canopy & dark bark
	for _, d in ipairs(fCentral:GetDescendants()) do
		if d:IsA("Model") and string.find(d.Name, "CentralTree") then
			for _, p in ipairs(d:GetDescendants()) do
				if p:IsA("BasePart") then
					if string.find(p.Name, "Foliage") or string.find(p.Name, "Canopy") or string.find(p.Name, "Leaf") then
						p.Material = Enum.Material.Grass
						p.Color = PALETTE.CanopyOlive
					else
						p.Material = Enum.Material.Wood
						p.Color = PALETTE.BarkDark
					end
				end
			end
		end
	end

	-- Watchtower relocation, exterior truss ladder & cabin doorway
	local towerShifts = {
		Watchtower_NW = Vector3.new(-10, 0, 20),
		Watchtower_NE = Vector3.new( 10, 0, 20),
		Watchtower_SW = Vector3.new(  4, 0, -4),
		Watchtower_SE = Vector3.new( -4, 0, -4),
	}

	for wtName, shift in pairs(towerShifts) do
		local wt = fCentral:FindFirstChild(wtName)
		if wt then
			if not wt:GetAttribute("TowerShifted") then
				wt:SetAttribute("TowerShifted", true)
				translateTree(wt, shift)
			end
			local fpad = wt:FindFirstChild("FoundationPad")
			if fpad then
				local cx, cz = fpad.Position.X, fpad.Position.Z
				local truss = wt:FindFirstChild("ClimbTruss")
				if truss then
					truss.Size = Vector3.new(2.2, 26.0, 2.0)
					truss.CFrame = CFrame.new(cx, 613.5, cz + 9.15)
					truss.Material = Enum.Material.Metal
					truss.Color = PALETTE.HeavyFraming
				end
				local rim = wt:FindFirstChild("DeckNeonRim")
				if rim then
					for _, seg in ipairs(rim:GetChildren()) do
						if seg:IsA("BasePart") then
							seg.CanCollide = false
							seg.Material = Enum.Material.Metal
							seg.Color = PALETTE.HeavyFraming
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

	-- Walk-In Citadel HQ: Stair landings, ATC doors, roof catwalks, smoked tactical glass & stencil screens
	local citadel = fCentral:FindFirstChild("Citadel_Command_HQ_WalkIn")
	if citadel then
		-- Smoked tactical glass on Citadel windows
		for _, winName in ipairs({"West_NorthWindow", "East_NorthWindow", "ATC_FrontGlassLeft", "ATC_FrontGlassRight"}) do
			local w = citadel:FindFirstChild(winName, true)
			if w and w:IsA("BasePart") then
				w.Material = Enum.Material.Glass
				w.Color = PALETTE.SmokedGlass
				w.Transparency = 0.55
			end
		end

		-- Clean military stencil typography on BriefingScreen & HeroTitleBillboard
		for _, scrName in ipairs({"BriefingScreen", "HeroTitleBillboard"}) do
			local scr = citadel:FindFirstChild(scrName, true)
			if scr then
				for _, lbl in ipairs(scr:GetDescendants()) do
					if lbl:IsA("TextLabel") then
						lbl.Font = (scrName == "HeroTitleBillboard") and Enum.Font.Michroma or Enum.Font.RobotoMono
						lbl.Text = stripEmojis(lbl.Text)
						lbl.TextColor3 = Color3.fromRGB(235, 240, 245)
					end
				end
			end
		end

		-- Floor 2 North & South Stairwell Landings
		makePart(citadel, "Floor2_WestNorthLanding", CFrame.new(-26.5, 618.0, -79.90), Vector3.new(9.0, 1.2, 8.2), Enum.Material.Concrete, PALETTE.BaseConcrete)
		makePart(citadel, "Floor2_WestSouthLanding", CFrame.new(-26.5, 618.0, -44.75), Vector3.new(9.0, 1.2, 9.5), Enum.Material.Concrete, PALETTE.BaseConcrete)
		makePart(citadel, "Floor2_EastNorthLanding", CFrame.new( 26.5, 618.0, -79.90), Vector3.new(9.0, 1.2, 8.2), Enum.Material.Concrete, PALETTE.BaseConcrete)
		makePart(citadel, "Floor2_EastSouthLanding", CFrame.new( 26.5, 618.0, -44.75), Vector3.new(9.0, 1.2, 9.5), Enum.Material.Concrete, PALETTE.BaseConcrete)

		-- Smooth stair nosings (Metal) & trim handrails at landings
		for _, stName in ipairs({"WestInteriorStairs", "EastInteriorStairs", "RoofAccessStairs_W", "RoofAccessStairs_E"}) do
			local st = citadel:FindFirstChild(stName)
			if st then
				for _, p in ipairs(st:GetChildren()) do
					if p:IsA("BasePart") then
						if string.find(p.Name, "StepNose_") then
							p.CanCollide = false
							p.Material = Enum.Material.Metal
							p.Color = PALETTE.HeavyFraming
						elseif string.find(p.Name, "Handrail_") and not p:GetAttribute("Trimmed") then
							p:SetAttribute("Trimmed", true)
							p.Size = Vector3.new(p.Size.X, p.Size.Y, p.Size.Z - 3.5)
							p.Material = Enum.Material.Metal
							p.Color = PALETTE.HeavyFraming
						end
					end
				end
			end
		end

		-- Open 12-stud doorways through ATC_LeftWall and ATC_RightWall
		for _, wSpec in ipairs({{"ATC_LeftWall", -37.0}, {"ATC_RightWall", 37.0}}) do
			local wPart = citadel:FindFirstChild(wSpec[1])
			local wx = wSpec[2]
			if wPart then
				wPart.Name = wSpec[1] .. "_North"
				wPart.Size = Vector3.new(2.0, 16.0, 14.0)
				wPart.CFrame = CFrame.new(wx, 626.5, -75.0)
				wPart.Material = Enum.Material.Concrete
				wPart.Color = PALETTE.BaseConcrete
				makePart(citadel, wSpec[1] .. "_South", CFrame.new(wx, 626.5, -49.0), Vector3.new(2.0, 16.0, 14.0), Enum.Material.Concrete, PALETTE.BaseConcrete)
				makePart(citadel, wSpec[1] .. "_DoorHeader", CFrame.new(wx, 632.0, -62.0), Vector3.new(2.2, 5.0, 12.0), Enum.Material.Metal, PALETTE.HeavyFraming)
			end
		end

		-- Add Roof Catwalk Landings at top of RoofAccessStairs_W/E
		makePart(citadel, "CitadelRoofLanding_W", CFrame.new(-45.5, 634.5, -78.25), Vector3.new(13.0, 1.4, 9.5), Enum.Material.DiamondPlate, PALETTE.HeavyFraming)
		makePart(citadel, "CitadelRoofLanding_E", CFrame.new( 45.5, 634.5, -78.25), Vector3.new(13.0, 1.4, 9.5), Enum.Material.DiamondPlate, PALETTE.HeavyFraming)
		makePart(citadel, "RoofLandingRail_WN", CFrame.new(-45.5, 636.8, -82.7),  Vector3.new(13.0, 3.2, 0.5), Enum.Material.Glass, PALETTE.SmokedGlass, 0.55)
		makePart(citadel, "RoofLandingRail_WW", CFrame.new(-51.75, 636.8, -78.25), Vector3.new(0.5, 3.2, 9.5), Enum.Material.Glass, PALETTE.SmokedGlass, 0.55)
		makePart(citadel, "RoofLandingRail_EN", CFrame.new( 45.5, 636.8, -82.7),  Vector3.new(13.0, 3.2, 0.5), Enum.Material.Glass, PALETTE.SmokedGlass, 0.55)
		makePart(citadel, "RoofLandingRail_EE", CFrame.new( 51.75, 636.8, -78.25), Vector3.new(0.5, 3.2, 9.5), Enum.Material.Glass, PALETTE.SmokedGlass, 0.55)

		-- Add Floor 2 Outer Terrace Safety Guardrails
		makePart(citadel, "Floor2_WestTerraceRail_W", CFrame.new(-66.7, 620.2, -62.0), Vector3.new(0.6, 3.2, 44.0), Enum.Material.Glass, PALETTE.SmokedGlass, 0.55)
		makePart(citadel, "Floor2_EastTerraceRail_E", CFrame.new( 66.7, 620.2, -62.0), Vector3.new(0.6, 3.2, 44.0), Enum.Material.Glass, PALETTE.SmokedGlass, 0.55)

		-- Fix BalconyGuardrail: remove blocking Frame_N and convert Frame_S/W/E from Neon to Glass
		local balc = citadel:FindFirstChild("BalconyGuardrail")
		if balc then
			local fn = balc:FindFirstChild("Frame_N")
			if fn then fn:Destroy() end
			for _, p in ipairs(balc:GetChildren()) do
				if p:IsA("BasePart") then
					p.Material = Enum.Material.Glass
					p.Transparency = 0.55
					p.Color = PALETTE.SmokedGlass
				end
			end
		end

		-- Add Interior Lighting to Citadel Wings & ATC Room
		for idx, lPos in ipairs({Vector3.new(-44, 617.2, -62), Vector3.new(46, 617.2, -62), Vector3.new(0, 617.2, -62), Vector3.new(0, 633.6, -62)}) do
			local fix = makePart(citadel, "InteriorCeilingFixture_" .. idx, CFrame.new(lPos), Vector3.new(12, 0.3, 1.8), Enum.Material.Neon, Color3.fromRGB(225, 242, 255), 0, false)
			local pl = Instance.new("PointLight")
			pl.Brightness = 1.6
			pl.Range = 38
			pl.Color = Color3.fromRGB(235, 245, 255)
			pl.Parent = fix
		end
	end
end

-- ============================================================================
-- 6. ISLAND 02: DEPLOYMENT & MATCHMAKING (2-TIER GATES, QUEUE UX & DROPSHIP)
-- ============================================================================
if fDeploy then
	local neck = fDeploy:FindFirstChild("HelipadBridgeNeck")
	if neck then
		neck.Size = Vector3.new(28.0, 2.0, 20.0)
		neck.CFrame = CFrame.new(0, 609.4, -318.0)
		neck.Material = Enum.Material.Concrete
		neck.Color = PALETTE.BaseConcrete
		makePart(fDeploy, "HelipadAscentRamp", CFrame.new(0, 611.325, -323.5) * CFrame.Angles(0, math.pi, 0), Vector3.new(28.0, 1.85, 9.0), Enum.Material.DiamondPlate, PALETTE.HeavyFraming, 0, true, "WedgePart")
	end

	-- Unify TeleporterGate_1_5v5..TeleporterGate_5_1v1 frames & add Live Queue Counter UX
	local gateConfigs = {
		{name = "TeleporterGate_1_5v5",     mode = "5V5 TACTICAL",       players = "08/10", wait = "04s", ranked = false},
		{name = "TeleporterGate_2_Ranked",  mode = "RANKED COMPETITIVE", players = "09/10", wait = "02s", ranked = true},
		{name = "TeleporterGate_3_FFA",     mode = "FREE FOR ALL",       players = "11/12", wait = "03s", ranked = false},
		{name = "TeleporterGate_4_GunGame", mode = "ARMS RACE",          players = "06/08", wait = "06s", ranked = false},
		{name = "TeleporterGate_5_1v1",     mode = "1V1 DUEL ARENA",     players = "01/02", wait = "01s", ranked = false},
	}

	for _, cfg in ipairs(gateConfigs) do
		local gate = fDeploy:FindFirstChild(cfg.name)
		if gate then
			local tierColor = cfg.ranked and PALETTE.RankedGold or PALETTE.NorthAmber
			for _, p in ipairs(gate:GetDescendants()) do
				if p:IsA("BasePart") then
					if string.find(p.Name, "GantryPillar")
						or string.find(p.Name, "PortalBacking")
						or string.find(p.Name, "SideGuardRail")
						or string.find(p.Name, "Frame")
					then
						p.Material = Enum.Material.Metal
						p.Color = PALETTE.HeavyFraming
					elseif p.Name == "QueuePad" or string.find(p.Name, "PortalCore") or string.find(p.Name, "PortalField") then
						p.Material = Enum.Material.Neon
						p.Color = tierColor
					end
				end
			end

			-- Live Queue Telemetry formatting on QueueStatusSign
			local qSign = gate:FindFirstChild("QueueStatusSign", true)
			if qSign then
				for _, lbl in ipairs(qSign:GetDescendants()) do
					if lbl:IsA("TextLabel") then
						lbl.Font = Enum.Font.RobotoMono
						lbl.TextColor3 = tierColor
						lbl.Text = string.format("%s // QUEUE: %s PLAYERS // EST. WAIT: %s", cfg.mode, cfg.players, cfg.wait)
					end
				end
			end

			-- QueuePad ProximityPrompt & Step-on Matchmaking Countdown
			local qPad = gate:FindFirstChild("QueuePad", true)
			if qPad and qPad:IsA("BasePart") then
				qPad.Size = Vector3.new(15.5, 0.25, 11.0)
				local prompt = attachPrompt(qPad, "MatchQueuePrompt", "Enter Matchmaking Queue", cfg.mode, 12, 0)
				local padDebounce = {}

				local function triggerQueue(player)
					if not player or padDebounce[player] then return end
					padDebounce[player] = true
					if qSign then
						for _, lbl in ipairs(qSign:GetDescendants()) do
							if lbl:IsA("TextLabel") then
								lbl.Text = string.format("DEPLOYING %s TO %s IN 3s...", string.upper(player.Name), cfg.mode)
							end
						end
					end
					task.delay(3, function()
						if qSign then
							for _, lbl in ipairs(qSign:GetDescendants()) do
								if lbl:IsA("TextLabel") then
									lbl.Text = string.format("%s // QUEUE: %s PLAYERS // EST. WAIT: %s", cfg.mode, cfg.players, cfg.wait)
								end
							end
						end
						padDebounce[player] = nil
					end)
				end

				prompt.Triggered:Connect(triggerQueue)
				qPad.Touched:Connect(function(hit)
					local plr = Players:GetPlayerFromCharacter(hit.Parent)
					if plr then triggerQueue(plr) end
				end)
			end
		end
	end

	-- Valkyrie MK-IV Dropship Realism: Gunship gray, matte rescue markings & downwash emitter
	local dropship = fDeploy:FindFirstChild("Valkyrie_MK4_Dropship")
	if dropship then
		local ramp = dropship:FindFirstChild("RearBoardingRamp")
		local rCF = CFrame.new(0, 613.9, -342.1) * CFrame.Angles(math.rad(20.9), 0, 0)
		if ramp then
			ramp.Size = Vector3.new(11.5, 0.5, 10.6)
			ramp.CFrame = rCF
			ramp.Material = Enum.Material.DiamondPlate
			ramp.Color = PALETTE.HeavyFraming
		end
		for _, gName in ipairs({"RampGuideLight_-1", "RampGuideLight_1"}) do
			local gl = dropship:FindFirstChild(gName)
			if gl then
				local gx = string.find(gName, "%-1") and -5.4 or 5.4
				gl.Size = Vector3.new(0.4, 0.2, 10.4)
				gl.CanCollide = false
				gl.Material = Enum.Material.Neon
				gl.Color = PALETTE.NorthAmber
				gl.CFrame = CFrame.new(gx, 614.2, -342.1) * CFrame.Angles(math.rad(20.9), 0, 0)
			end
		end

		for _, p in ipairs(dropship:GetDescendants()) do
			if p:IsA("BasePart") then
				if string.find(p.Name, "HullStripeOrange") then
					p.Material = Enum.Material.Metal
					p.Color = PALETTE.RescueMarking
				elseif string.find(p.Name, "CockpitAvionics") then
					p.Material = Enum.Material.Glass
					p.Color = PALETTE.SmokedGlass
					p.Transparency = 0.25
				elseif string.find(p.Name, "Hull") or string.find(p.Name, "Fuselage") or string.find(p.Name, "Wing") then
					p.Material = Enum.Material.Metal
					p.Color = PALETTE.GunshipGray
				end
			end
		end

		for _,nozName in ipairs({"ThrusterNozzleDown_-1", "ThrusterNozzleDown_1"}) do
			local noz = dropship:FindFirstChild(nozName, true)
			if noz and noz:IsA("BasePart") then
				local oldEm = noz:FindFirstChild("VTOLDownwash")
				if oldEm then oldEm:Destroy() end
				local em = Instance.new("ParticleEmitter")
				em.Name = "VTOLDownwash"
				em.EmissionDirection = Enum.NormalId.Bottom
				em.Rate = 28
				em.Speed = NumberRange.new(18, 28)
				em.Lifetime = NumberRange.new(0.35, 0.65)
				em.SpreadAngle = Vector2.new(25, 25)
				em.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1.5),
					NumberSequenceKeypoint.new(1, 5.5),
				})
				em.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.65),
					NumberSequenceKeypoint.new(1, 1.0),
				})
				em.Color = ColorSequence.new(Color3.fromRGB(210, 220, 230))
				em.Parent = noz
			end
		end
	end
end

-- ============================================================================
-- 7. ISLAND 03: ARMORY & CRATES (CLERESTORY WINDOWS, PROMPTS & RARITY RIMS)
-- ============================================================================
if fArmory then
	local munPav = fArmory:FindFirstChild("Tactical_Munitions_Pavilion")
	if munPav then
		-- Convert upper half of ShowroomNorthWall and ShowroomSouthWall (Y = 618 to 632) into clerestory windows
		for _, wName in ipairs({"ShowroomNorthWall", "ShowroomSouthWall"}) do
			local wall = munPav:FindFirstChild(wName)
			if wall and wall:IsA("BasePart") then
				local wx, wz = wall.Position.X, wall.Position.Z
				local sx, sz = wall.Size.X, wall.Size.Z
				wall.Size = Vector3.new(sx, 10.0, sz)
				wall.CFrame = CFrame.new(wx, 613.0, wz)
				wall.Material = Enum.Material.Concrete
				wall.Color = PALETTE.BaseConcrete

				makePart(
					munPav,
					wName .. "_ClerestoryGlass",
					CFrame.new(wx, 625.0, wz),
					Vector3.new(sx, 14.0, math.min(sz, 0.8)),
					Enum.Material.Glass,
					PALETTE.SmokedGlass,
					0.45
				)
			end
		end

		local backWall = munPav:FindFirstChild("ShowroomBackWall")
		if backWall and backWall:IsA("BasePart") then
			backWall.Material = Enum.Material.Concrete
			backWall.Color = PALETTE.BaseConcrete
		end

		-- Separate colliding Armory Rack weapons, add display stands & attach Loadout ProximityPrompts
		local rackCategories = {
			{id = "ASSAULT RIFLES",    label = "Assault Rifles",    z = -42},
			{id = "SMG & PDW",         label = "SMG & PDW",         z = -21},
			{id = "SNIPER RIFLES",     label = "Sniper Rifles",     z =   0},
			{id = "SHOTGUNS & HEAVY",  label = "Shotguns & Heavy",  z =  21},
			{id = "TACTICAL SPECIALS", label = "Tactical Specials", z =  42},
		}

		for idx, cat in ipairs(rackCategories) do
			local wA = munPav:FindFirstChild("WeaponModelA_" .. cat.id)
			local wB = munPav:FindFirstChild("WeaponModelB_" .. cat.id)
			if wA and not wA:GetAttribute("Separated") then
				wA:SetAttribute("Separated", true)
				translateTree(wA, Vector3.new(-1.6, 0, 1.2))
			end
			if wB and not wB:GetAttribute("Separated") then
				wB:SetAttribute("Separated", true)
				translateTree(wB, Vector3.new(1.6, 0, -1.2))
			end
			local standA = makePart(munPav, "RackStandA_" .. cat.id, CFrame.new(-281.6, 613.55, cat.z - 2.4), Vector3.new(0.45, 2.5, 1.2), Enum.Material.Metal, PALETTE.HeavyFraming)
			makePart(munPav, "RackStandB_" .. cat.id, CFrame.new(-278.4, 613.55, cat.z + 2.4), Vector3.new(0.45, 2.5, 1.2), Enum.Material.Metal, PALETTE.HeavyFraming)

			local ped = munPav:FindFirstChild("RackPedestal_" .. cat.id)
				or munPav:FindFirstChild("RackPedestal_" .. idx)
				or standA
			if ped then
				attachPrompt(ped, "InspectRackPrompt", "Inspect " .. cat.label, "LOADOUT STATION // " .. cat.id, 10, 0)
			end
		end
	end

	-- Rarity Color Discipline on Crates & Interactive Crate Prompts
	local crateSpecs = {
		{tier = "STANDARD", label = "Standard Crate", cost = "500 CR",   col = PALETTE.CrateStandard},
		{tier = "TACTICAL", label = "Tactical Crate", cost = "1,500 CR", col = PALETTE.CrateTactical},
		{tier = "ELITE",    label = "Elite Crate",    cost = "4,000 CR", col = PALETTE.CrateElite},
		{tier = "MYTHIC",   label = "Mythic Crate",   cost = "10,000 CR", col = PALETTE.CrateMythic},
	}

	for idx, cSpec in ipairs(crateSpecs) do
		local stage = fArmory:FindFirstChild("CrateStage_" .. cSpec.tier, true)
			or fArmory:FindFirstChild("CrateStage_" .. idx, true)
		if stage then
			for _, p in ipairs(stage:GetDescendants()) do
				if p:IsA("BasePart") then
					if string.find(p.Name, "StageOctagonGlow") then
						p.Material = Enum.Material.Metal
						p.Color = cSpec.col
						p.Reflectance = 0.25
					elseif string.find(p.Name, "ChestLower") or string.find(p.Name, "ChestUpperLid") then
						p.Material = Enum.Material.Metal
						p.Color = PALETTE.PolymerDark
					end
				end
			end
			local targetPart = stage:IsA("BasePart") and stage or stage:FindFirstChildWhichIsA("BasePart", true)
			if targetPart then
				attachPrompt(
					targetPart,
					"OpenCratePrompt",
					string.format("Open %s — %s", cSpec.label, cSpec.cost),
					"MUNITIONS SUPPLY // " .. cSpec.tier,
					10,
					0.25
				)
			end
		end
	end

	-- Fix OperatorPod Mannequins (East-facing +X alignment)
	local rEast = CFrame.Angles(0, -math.pi * 0.5, 0)
	for _, podSpec in ipairs({{"OperatorPod_-24", -24.0}, {"OperatorPod_24", 24.0}}) do
		local pod = fArmory:FindFirstChild(podSpec[1])
		local pz = podSpec[2]
		if pod then
			local man = pod:FindFirstChild("OperatorMannequin")
			if man then
				local px, py = -248.0, 609.5
				local map = {
					LeftLeg        = CFrame.new(px, py + 1.5, pz - 0.65) * rEast,
					RightLeg       = CFrame.new(px, py + 1.5, pz + 0.65) * rEast,
					Torso          = CFrame.new(px, py + 4.3, pz) * rEast,
					ChestRig       = CFrame.new(px, py + 4.4, pz) * rEast,
					VisorCore      = CFrame.new(px + 0.78, py + 4.6, pz) * rEast,
					LeftArm        = CFrame.new(px + 0.3, py + 4.3, pz - 1.7) * rEast * CFrame.Angles(math.rad(25), 0, 0),
					RightArm       = CFrame.new(px + 0.5, py + 4.9, pz + 1.7) * rEast * CFrame.Angles(math.rad(55), 0, 0),
					Head           = CFrame.new(px, py + 6.4, pz) * rEast,
					TacticalHelmet = CFrame.new(px, py + 6.7, pz) * rEast,
					HelmetVisor    = CFrame.new(px + 0.82, py + 6.45, pz) * rEast,
				}
				for cname, cf in pairs(map) do
					local part = man:FindFirstChild(cname)
					if part then part.CFrame = cf end
				end
			end
			makePart(pod, "PreviewGunProjector", CFrame.new(-244.0, 610.3, pz), Vector3.new(1.8, 1.6, 1.8), Enum.Material.Metal, PALETTE.HeavyFraming)
		end
	end
end

-- ============================================================================
-- 8. ISLAND 04: LIVE-FIRE RANGE & KILLHOUSE (TEST RIFLES, TARGETS & TIMER)
-- ============================================================================
local laneScores = {0, 0, 0, 0, 0}
local laneScoreLabels = {}

if fRange then
	local rangePav = fRange:FindFirstChild("FiveLane_Firing_Pavilion")
	if rangePav then
		for i = 1, 5 do
			local bench = rangePav:FindFirstChild("ShooterBench_" .. i)
			if bench then
				if not bench:GetAttribute("BenchAdjusted") then
					bench:SetAttribute("BenchAdjusted", true)
					bench.Size = Vector3.new(4.5, 3.6, 7.0)
					bench.CFrame = bench.CFrame + Vector3.new(0, 0, 1.8)
				end
				bench.Material = Enum.Material.Concrete
				bench.Color = PALETTE.BaseConcrete
				local rest = makePart(rangePav, "RifleRest_" .. i, CFrame.new(204.2, 612.45, bench.Position.Z), Vector3.new(1.6, 0.5, 1.2), Enum.Material.Metal, PALETTE.HeavyFraming)

				-- Lane Score Readout Board
				local scoreBoard = makePart(rangePav, "LaneScoreBoard_" .. i, CFrame.new(204.2, 616.5, bench.Position.Z), Vector3.new(0.4, 1.6, 4.2), Enum.Material.Metal, PALETTE.HeavyFraming, 0, false)
				local sgui = Instance.new("SurfaceGui")
				sgui.Face = Enum.NormalId.Left
				sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				sgui.PixelsPerStud = 40
				sgui.Parent = scoreBoard
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 1, 0)
				lbl.BackgroundColor3 = PALETTE.HudBackground
				lbl.Font = Enum.Font.RobotoMono
				lbl.TextColor3 = PALETTE.EastCrimson
				lbl.TextScaled = true
				lbl.Text = string.format("LANE 0%d // HITS: 000", i)
				lbl.Parent = sgui
				laneScoreLabels[i] = lbl

				local brifle = rangePav:FindFirstChild("BenchRifle_Lane" .. i)
				if brifle then
					if not brifle:GetAttribute("RifleAdjusted") then
						brifle:SetAttribute("RifleAdjusted", true)
						translateTree(brifle, Vector3.new(0, 0.85, 1.8))
					end
				end

				local promptHost = (brifle and brifle:FindFirstChildWhichIsA("BasePart", true)) or rest
				local prompt = attachPrompt(promptHost, "GrabTestRiflePrompt", "Grab Test Rifle (Infinite Ammo)", "LANE 0" .. i .. " // CARBINE TEST", 10, 0)
				prompt.Triggered:Connect(function(player)
					player:SetAttribute("SelectedWeapon", "Carbine")
					player:SetAttribute("InArena", true)
				end)
			end
		end
	end

	-- Distance Markers (25M, 50M, 75M) on Range Floor
	for _, distSpec in ipairs({{label = "25M", x = 228}, {label = "50M", x = 252}, {label = "75M", x = 276}}) do
		local marker = makePart(
			fRange,
			"RangeDistanceMarker_" .. distSpec.label,
			CFrame.new(distSpec.x, 608.22, -22.0),
			Vector3.new(2.4, 0.08, 56.0),
			Enum.Material.Concrete,
			PALETTE.HeavyFraming,
			0,
			false
		)
		local sgui = Instance.new("SurfaceGui")
		sgui.Face = Enum.NormalId.Top
		sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sgui.PixelsPerStud = 32
		sgui.Parent = marker
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Michroma
		lbl.Text = distSpec.label .. " TARGET LINE"
		lbl.TextColor3 = PALETTE.EastCrimson
		lbl.TextScaled = true
		lbl.Parent = sgui
	end

	-- Reactive Target Feedback: Dark steel target plates + bullseye flash + score counter
	for _, d in ipairs(fRange:GetDescendants()) do
		if d:IsA("BasePart") and (string.find(d.Name, "TorsoSilhouette") or string.find(d.Name, "MovingTarget") or string.find(d.Name, "SniperTarget75m")) then
			d.Material = Enum.Material.Metal
			d.Color = PALETTE.SteelTarget

			local oldGui = d:FindFirstChild("ReactiveBullseyeGUI")
			if oldGui then oldGui:Destroy() end
			local sgui = Instance.new("SurfaceGui")
			sgui.Name = "ReactiveBullseyeGUI"
			sgui.Face = Enum.NormalId.Left
			sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sgui.PixelsPerStud = 40
			sgui.Parent = d

			local ring = Instance.new("Frame")
			ring.Size = UDim2.new(0.65, 0, 0.65, 0)
			ring.Position = UDim2.new(0.175, 0, 0.175, 0)
			ring.BackgroundColor3 = Color3.fromRGB(230, 235, 240)
			ring.BorderSizePixel = 0
			ring.Parent = sgui

			local center = Instance.new("Frame")
			center.Size = UDim2.new(0.45, 0, 0.45, 0)
			center.Position = UDim2.new(0.275, 0, 0.275, 0)
			center.BackgroundColor3 = PALETTE.SteelTarget
			center.BorderSizePixel = 0
			center.Parent = ring

			local cd = d:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
			cd.MaxActivationDistance = 160
			cd.Parent = d

			local function registerTargetHit()
				d.Color = PALETTE.EastCrimson
				center.BackgroundColor3 = PALETTE.EastCrimson
				local laneIdx = math.clamp(math.floor((d.Position.Z + 50) / 12) + 1, 1, 5)
				laneScores[laneIdx] = (laneScores[laneIdx] or 0) + 1
				if laneScoreLabels[laneIdx] then
					laneScoreLabels[laneIdx].Text = string.format("LANE 0%d // HITS: %03d", laneIdx, laneScores[laneIdx])
				end
				task.delay(0.15, function()
					if d and d.Parent then
						d.Color = PALETTE.SteelTarget
						center.BackgroundColor3 = PALETTE.SteelTarget
					end
				end)
			end

			cd.MouseClick:Connect(registerTargetHit)
			d.Touched:Connect(function(hit)
				if hit and not Players:GetPlayerFromCharacter(hit.Parent) then
					registerTargetHit()
				end
			end)
		end
	end

	-- CQB Killhouse Course Timer (West Entrance X=214, Z=42 -> East Exit X=285, Z=42) & Tactical Plywood
	local killhouse = fRange:FindFirstChild("CQB_Tactical_Killhouse") or fRange
	for _, d in ipairs(killhouse:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, "KillhousePerimeterHazard") then
			d.Material = Enum.Material.WoodPlanks
			d.Color = Color3.fromRGB(132, 114, 88)
		end
	end

	local startArch = makePart(killhouse, "Killhouse_StartTimerArch", CFrame.new(214, 616.0, 42), Vector3.new(1.2, 2.4, 10.0), Enum.Material.Metal, PALETTE.HeavyFraming, 0, false)
	local startPad  = makePart(killhouse, "Killhouse_StartSensor", CFrame.new(214, 608.25, 42), Vector3.new(3.0, 0.2, 9.0), Enum.Material.Neon, PALETTE.NorthAmber, 0.35, false)
	local finishPad = makePart(killhouse, "Killhouse_FinishSensor", CFrame.new(285, 608.25, 42), Vector3.new(3.0, 0.2, 9.0), Enum.Material.Neon, PALETTE.EastCrimson, 0.35, false)

	local khGui = Instance.new("SurfaceGui")
	khGui.Face = Enum.NormalId.Left
	khGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	khGui.PixelsPerStud = 40
	khGui.Parent = startArch
	local khLabel = Instance.new("TextLabel")
	khLabel.Size = UDim2.new(1, 0, 1, 0)
	khLabel.BackgroundColor3 = PALETTE.HudBackground
	khLabel.Font = Enum.Font.Michroma
	khLabel.TextColor3 = PALETTE.NorthAmber
	khLabel.TextScaled = true
	khLabel.Text = "START CQB TIMER // COURSE READY"
	khLabel.Parent = khGui

	local activeRuns = {}
	startPad.Touched:Connect(function(hit)
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if plr then
			activeRuns[plr] = os.clock()
			khLabel.Text = string.format("LIVE RUN: %s // TIMER ACTIVE", string.upper(plr.Name))
		end
	end)
	finishPad.Touched:Connect(function(hit)
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if plr and activeRuns[plr] then
			local elapsed = os.clock() - activeRuns[plr]
			activeRuns[plr] = nil
			khLabel.Text = string.format("%s CLEARED // TIME: %.2fs", string.upper(plr.Name), elapsed)
		end
	end)
end

-- ============================================================================
-- 9. ISLAND 05: HALL OF LEGENDS VIP (PRESTIGE PALETTE, TROPHIES & LEADERBOARDS)
-- ============================================================================
if fVIP then
	for _, d in ipairs(fVIP:GetDescendants()) do
		if d:IsA("BasePart") then
			if string.find(d.Name, "ChampionsGoldBorder") then
				d.Material = Enum.Material.Marble
				d.Color = PALETTE.ObsidianMarble
			elseif string.find(d.Name, "HonorCarpetRunner") then
				d.Material = Enum.Material.Fabric
				d.Color = PALETTE.CrimsonVelvet
			elseif string.find(d.Name, "HonorCarpetGoldTrim") or string.find(d.Name, "PodiumTrim") then
				d.Material = Enum.Material.Metal
				d.Color = PALETTE.SouthBrass
				d.Reflectance = 0.25
			end
		elseif d:IsA("Model") and string.find(d.Name, "VIPGoldTree") then
			for _, p in ipairs(d:GetDescendants()) do
				if p:IsA("BasePart") then
					if string.find(p.Name, "Foliage") or string.find(p.Name, "Leaf") or colorClose(p.Color, 255, 208, 24, 35) then
						p.Material = Enum.Material.Grass
						p.Color = PALETTE.CanopyOlive
						p.Reflectance = 0
					else
						p.Material = Enum.Material.Wood
						p.Color = PALETTE.BarkDark
					end
				end
			end
		end
	end

	-- Fix VIP Trophy Cases so GoldenTrophyGun fits 100% inside the glass
	for _, tcName in ipairs({"TrophyCase_-16_194", "TrophyCase_-16_212", "TrophyCase_16_194", "TrophyCase_16_212"}) do
		local tc = fVIP:FindFirstChild(tcName)
		if tc then
			local ped = tc:FindFirstChild("CasePedestal")
			local gls = tc:FindFirstChild("CaseGlass")
			local gun = tc:FindFirstChild("GoldenTrophyGun")
			if ped and gls and gun then
				ped.Size = Vector3.new(5.0, 3.2, 10.5)
				ped.Material = Enum.Material.Marble
				ped.Color = PALETTE.ObsidianMarble
				gls.Size = Vector3.new(4.6, 4.4, 10.0)
				gls.CFrame = CFrame.new(ped.Position.X, 627.6, ped.Position.Z)
				gls.Material = Enum.Material.Glass
				gls.Color = PALETTE.SmokedGlass
				gls.Transparency = 0.55
				if not gun:GetAttribute("TrophyFitted") then
					gun:SetAttribute("TrophyFitted", true)
					translateTree(gun, Vector3.new(0, 0.8, -0.6))
				end
				for _, gp in ipairs(gun:GetDescendants()) do
					if gp:IsA("BasePart") then
						gp.Material = Enum.Material.Metal
						gp.Color = PALETTE.SouthBrass
						gp.Reflectance = 0.25
					end
				end
				local stand = makePart(tc, "TrophyDisplayStand", CFrame.new(ped.Position.X, 626.3, ped.Position.Z - 0.4), Vector3.new(0.5, 1.8, 1.8), Enum.Material.Metal, PALETTE.SouthBrass)
				stand.Reflectance = 0.25
			end
		end
	end

	-- Switch the 3 massive LeaderboardScreen parts to dark translucent esports broadcast boards
	local boardCategories = {
		{x = -38, title = "GLOBAL ELO RATING // TOP 5"},
		{x =   0, title = "SEASON WINS // TOP 5"},
		{x =  38, title = "KILLHOUSE SPEEDRUN // TOP 5"},
	}

	for _, d in ipairs(fVIP:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, "LeaderboardScreen") then
			d.Material = Enum.Material.Glass
			d.Color = PALETTE.HudBackground
			d.Transparency = 0.15

			local catTitle = "HALL OF LEGENDS // STANDINGS"
			for _, bc in ipairs(boardCategories) do
				if math.abs(d.Position.X - bc.x) < 10 then
					catTitle = bc.title
				end
			end

			local sgui = d:FindFirstChildOfClass("SurfaceGui")
			if sgui then
				sgui:ClearAllChildren()
			else
				sgui = Instance.new("SurfaceGui")
				sgui.Face = Enum.NormalId.Front
				sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				sgui.PixelsPerStud = 35
				sgui.Parent = d
			end

			local bg = Instance.new("Frame")
			bg.Size = UDim2.new(1, 0, 1, 0)
			bg.BackgroundColor3 = PALETTE.HudBackground
			bg.BackgroundTransparency = 0.12
			bg.BorderSizePixel = 0
			bg.Parent = sgui

			local hdr = Instance.new("TextLabel")
			hdr.Size = UDim2.new(0.92, 0, 0.16, 0)
			hdr.Position = UDim2.new(0.04, 0, 0.04, 0)
			hdr.BackgroundTransparency = 1
			hdr.Font = Enum.Font.Michroma
			hdr.Text = catTitle
			hdr.TextColor3 = PALETTE.SouthBrass
			hdr.TextScaled = true
			hdr.TextXAlignment = Enum.TextXAlignment.Left
			hdr.Parent = bg

			local sampleRows = {
				"01  VALKYRIE_ACTUAL      2,840 SR   94.2%",
				"02  KESTREL_ZERO         2,795 SR   91.8%",
				"03  APEX_VANGUARD        2,710 SR   89.5%",
				"04  SPECTRE_NINE         2,665 SR   88.1%",
				"05  TITAN_HORIZON        2,610 SR   86.4%",
			}

			for r = 1, 5 do
				local row = Instance.new("TextLabel")
				row.Size = UDim2.new(0.92, 0, 0.13, 0)
				row.Position = UDim2.new(0.04, 0, 0.22 + (r - 1) * 0.15, 0)
				row.BackgroundColor3 = Color3.fromRGB(26, 30, 38)
				row.BackgroundTransparency = 0.35
				row.BorderSizePixel = 0
				row.Font = Enum.Font.RobotoMono
				row.Text = sampleRows[r]
				row.TextColor3 = (r == 1) and PALETTE.SouthBrass or Color3.fromRGB(220, 226, 234)
				row.TextScaled = true
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Parent = bg
			end
		end
	end
end

-- Rotate East/West JumpPad PadHoloSigns 90 degrees so text faces approaching players
for _, jpName in ipairs({"JumpPad_To_Armory", "JumpPad_To_Range", "JumpPad_Armory_To_Plaza", "JumpPad_Range_To_Plaza"}) do
	local jp = lobby:FindFirstChild(jpName, true)
	if jp then
		local sign = jp:FindFirstChild("PadHoloSign")
		if sign then
			sign.CFrame = CFrame.new(sign.Position) * CFrame.Angles(0, math.pi * 0.5, 0)
		end
	end
end

-- ============================================================================
-- 10. ISLAND 06: SKY PARKOUR & VOLUMETRIC CLOUDS
-- ============================================================================
-- Enable native volumetric clouds and hide blocky CloudPuff parts
local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
clouds.Cover = 0.62
clouds.Density = 0.45
clouds.Color = Color3.fromRGB(235, 240, 248)
clouds.Parent = Workspace.Terrain

if fParkour then
	for _, d in ipairs(fParkour:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, "CloudPuff") then
			d.Transparency = 1
			d.CanCollide = false
			d.CastShadow = false
		end
	end

	local parkourCoords = {
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
		local rock = fParkour:FindFirstChild("ParkourDroneRock_" .. idx)
		local trim = fParkour:FindFirstChild("ParkourTrim_" .. idx)
		local pad  = fParkour:FindFirstChild("ParkourPad_" .. idx)
		if rock then rock.CFrame = CFrame.new(pos) * cylRot end
		if trim then trim.CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)) * cylRot end
		if pad  then pad.CFrame  = CFrame.new(pos + Vector3.new(0, 2.0, 0)) * cylRot end
	end

	-- Clone Starter Step (0) and Final Summit Step (8)
	for _, extra in ipairs({{0, Vector3.new(236.0, 608.5, -78.0)}, {8, Vector3.new(163.0, 652.0, -154.0)}}) do
		local idx, pos = extra[1], extra[2]
		local rBase = fParkour:FindFirstChild("ParkourDroneRock_1")
		local tBase = fParkour:FindFirstChild("ParkourTrim_1")
		local pBase = fParkour:FindFirstChild("ParkourPad_1")
		if rBase and not fParkour:FindFirstChild("ParkourDroneRock_" .. idx) then
			local rClone = rBase:Clone()
			rClone.Name = "ParkourDroneRock_" .. idx
			rClone.CFrame = CFrame.new(pos) * cylRot
			rClone.Parent = fParkour
		end
		if tBase and not fParkour:FindFirstChild("ParkourTrim_" .. idx) then
			local tClone = tBase:Clone()
			tClone.Name = "ParkourTrim_" .. idx
			tClone.CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)) * cylRot
			tClone.Parent = fParkour
		end
		if pBase and not fParkour:FindFirstChild("ParkourPad_" .. idx) then
			local pClone = pBase:Clone()
			pClone.Name = "ParkourPad_" .. idx
			pClone.CFrame = CFrame.new(pos + Vector3.new(0, 2.0, 0)) * cylRot
			pClone.Parent = fParkour
		end
	end

	-- Add START PARKOUR COURSE // +500 CR REWARD holo-marker at ParkourDroneRock_0
	local startHolo = makePart(
		fParkour,
		"ParkourStartHoloMarker",
		CFrame.new(236.0, 614.2, -78.0),
		Vector3.new(8.5, 2.0, 0.25),
		Enum.Material.Glass,
		PALETTE.SmokedGlass,
		0.35,
		false
	)
	local pkGui = Instance.new("SurfaceGui")
	pkGui.Face = Enum.NormalId.Front
	pkGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	pkGui.PixelsPerStud = 40
	pkGui.Parent = startHolo
	local pkLbl = Instance.new("TextLabel")
	pkLbl.Size = UDim2.new(1, 0, 1, 0)
	pkLbl.BackgroundColor3 = PALETTE.HudBackground
	pkLbl.BackgroundTransparency = 0.15
	pkLbl.Font = Enum.Font.Michroma
	pkLbl.TextColor3 = PALETTE.NorthAmber
	pkLbl.TextScaled = true
	pkLbl.Text = "START PARKOUR COURSE // +500 CR REWARD"
	pkLbl.Parent = pkGui

	-- Tone ParkourPad_0..8 from blinding cyan to pulsing amber with landing sound & particle burst
	for idx = 0, 8 do
		local rock = fParkour:FindFirstChild("ParkourDroneRock_" .. idx)
		local trim = fParkour:FindFirstChild("ParkourTrim_" .. idx)
		local pad  = fParkour:FindFirstChild("ParkourPad_" .. idx)
		if rock then
			rock.Material = Enum.Material.Slate
			rock.Color = PALETTE.CliffStrata
		end
		if trim then
			trim.Material = Enum.Material.Metal
			trim.Color = PALETTE.HeavyFraming
		end
		if pad and pad:IsA("BasePart") then
			pad.Material = Enum.Material.Neon
			pad.Color = PALETTE.NorthAmber
			pad.Transparency = 0.2

			local pEmitter = pad:FindFirstChild("StepBurst") or Instance.new("ParticleEmitter")
			pEmitter.Name = "StepBurst"
			pEmitter.Enabled = false
			pEmitter.Color = ColorSequence.new(PALETTE.NorthAmber)
			pEmitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 0.0),
			})
			pEmitter.Lifetime = NumberRange.new(0.25, 0.45)
			pEmitter.Speed = NumberRange.new(8, 14)
			pEmitter.SpreadAngle = Vector2.new(75, 75)
			pEmitter.Parent = pad

			local sfx = pad:FindFirstChild("StepSound") or Instance.new("Sound")
			sfx.Name = "StepSound"
			sfx.SoundId = "rbxassetid://12222225"
			sfx.Volume = 0.45
			sfx.Pitch = 1.0 + idx * 0.06
			sfx.Parent = pad

			local stepDebounce = {}
			pad.Touched:Connect(function(hit)
				local plr = Players:GetPlayerFromCharacter(hit.Parent)
				if plr and not stepDebounce[plr] then
					stepDebounce[plr] = true
					pEmitter:Emit(14)
					sfx:Play()
					TweenService:Create(pad, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
						Transparency = 0,
						Color = Color3.fromRGB(255, 195, 110),
					}):Play()
					task.delay(0.6, function()
						stepDebounce[plr] = nil
					end)
				end
			end)
		end
	end
end

-- ============================================================================
-- 11. RUNTIME GAMEPLAY CONTROLLER (JUMPPADS, ROTORS & MOVING RANGE TARGETS)
-- ============================================================================
local padCooldowns = {}
for _, d in ipairs(lobby:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "JumpTrigger" then
		local targetVal = d:FindFirstChild("TargetPosition")
		if targetVal and targetVal:IsA("Vector3Value") then
			d.Touched:Connect(function(hit)
				local char = hit.Parent
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local rootPart = char and char:FindFirstChild("HumanoidRootPart")
				if hum and rootPart then
					local now = os.clock()
					if (padCooldowns[char] or 0) > now then return end
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
		TweenService:Create(d, tweenInfo, {CFrame = startCF + Vector3.new(0, 0, 4.5)}):Play()
	end
end

local spinningParts = {}
for _, d in ipairs(lobby:GetDescendants()) do
	if d:IsA("BasePart") and (d.Name == "SpinningRotor" or d.Name == "HoloGlobe") then
		table.insert(spinningParts, d)
	end
end

RunService.Heartbeat:Connect(function(dt)
	local stepRot = CFrame.Angles(0, dt * 4.5, 0)
	for _, p in ipairs(spinningParts) do
		p.CFrame = p.CFrame * stepRot
	end
end)
