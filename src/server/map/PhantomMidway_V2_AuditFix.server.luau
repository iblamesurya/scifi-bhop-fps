--!strict
-- PhantomMidway_V2_AuditFix.server.luau
-- O(1) 3D Spatial Hash Grid, Exact Dictionary Cleanup, Top-Preserving Ground Wall Snap,
-- Symmetrical 5v5 Vehicle & Cover Generator, Soft Interior Lighting, and Tactical Callout Volumes.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetRegistry = require(Shared:WaitForChild("configs"):WaitForChild("AssetRegistry"))

pcall(function()
	ChangeHistoryService:SetWaypoint("Before_PhantomMidway_V2_AuditFix")
end)

local map: Instance? = Workspace:FindFirstChild("PhantomMidway_5v5_Map", true)
if not map then
	local waited = Workspace:WaitForChild("PhantomMidway_5v5_Map", 5)
	if waited then
		map = waited
	else
		warn("[MapRefactor] PhantomMidway_5v5_Map not found in Workspace!")
		return
	end
end

local targetMap = map :: Instance
if targetMap:GetAttribute("PhantomMidwayV2Applied") == true then
	return
end
targetMap:SetAttribute("PhantomMidwayV2Applied", true)

local stats = {
	deletedOOB = 0,
	deletedTargetProps = 0,
	deletedDuplicates = 0,
	resizedGroundWalls = 0,
	taggedWindows = 0,
	taggedReliefs = 0,
	lightsCreated = 0,
	mirroredPropsSpawned = 0,
	shadowCulledMicroParts = 0,
	errors = 0,
}

local function safeRun(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		stats.errors += 1
		warn(string.format("[MapRefactor Error in %s]: %s", label, tostring(err)))
	end
end

--------------------------------------------------------------------------------
-- 1. O(1) 3D SPATIAL HASH GRID & AABB MATH
--------------------------------------------------------------------------------
type AABB = {
	minX: number,
	maxX: number,
	minY: number,
	maxY: number,
	minZ: number,
	maxZ: number,
	part: BasePart,
}

local CELL_SIZE = 16
local spatialGrid: { [string]: { AABB } } = {}

local function getPartAABB(part: BasePart, pad: number?): AABB
	local p = pad or 0
	local cf = part.CFrame
	local s = part.Size * 0.5
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local wx = math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z + p
	local wy = math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z + p
	local wz = math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z + p
	local pos = cf.Position
	return {
		minX = pos.X - wx,
		maxX = pos.X + wx,
		minY = pos.Y - wy,
		maxY = pos.Y + wy,
		minZ = pos.Z - wz,
		maxZ = pos.Z + wz,
		part = part,
	}
end

local function aabbIdentical(a: AABB, b: AABB, tol: number): boolean
	return math.abs(a.minX - b.minX) < tol
		and math.abs(a.maxX - b.maxX) < tol
		and math.abs(a.minY - b.minY) < tol
		and math.abs(a.maxY - b.maxY) < tol
		and math.abs(a.minZ - b.minZ) < tol
		and math.abs(a.maxZ - b.maxZ) < tol
end

local function aabbIntersects(
	a: { minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number },
	b: AABB,
	eps: number
): boolean
	return (a.minX < b.maxX - eps and a.maxX > b.minX + eps)
		and (a.minY < b.maxY - eps and a.maxY > b.minY + eps)
		and (a.minZ < b.maxZ - eps and a.maxZ > b.minZ + eps)
end

local function getGridKeys(box: { minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number }): { string }
	local keys: { string } = {}
	local x0, x1 = math.floor(box.minX / CELL_SIZE), math.floor(box.maxX / CELL_SIZE)
	local y0, y1 = math.floor(box.minY / CELL_SIZE), math.floor(box.maxY / CELL_SIZE)
	local z0, z1 = math.floor(box.minZ / CELL_SIZE), math.floor(box.maxZ / CELL_SIZE)
	for gx = x0, x1 do
		for gy = y0, y1 do
			for gz = z0, z1 do
				table.insert(keys, string.format("%d_%d_%d", gx, gy, gz))
			end
		end
	end
	return keys
end

local function checkAndInsertSpatial(box: AABB, checkDuplicateTol: number?): boolean
	local keys = getGridKeys(box)
	if checkDuplicateTol then
		local checked: { [AABB]: boolean } = {}
		for _, k in ipairs(keys) do
			local bucket = spatialGrid[k]
			if bucket then
				for _, other in ipairs(bucket) do
					if not checked[other] then
						checked[other] = true
						if other.part.ClassName == box.part.ClassName and aabbIdentical(box, other, checkDuplicateTol) then
							return true
						end
					end
				end
			end
		end
	end
	for _, k in ipairs(keys) do
		if not spatialGrid[k] then
			spatialGrid[k] = {}
		end
		table.insert(spatialGrid[k], box)
	end
	return false
end

local function _isVolumeFree(minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number): boolean
	local testBox = { minX = minX, maxX = maxX, minY = minY, maxY = maxY, minZ = minZ, maxZ = maxZ }
	for _, k in ipairs(getGridKeys(testBox)) do
		local bucket = spatialGrid[k]
		if bucket then
			for _, other in ipairs(bucket) do
				if aabbIntersects(testBox, other, 0.1) then
					return false
				end
			end
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- 2. EXACT DICTIONARY CLEANUP (NO BROAD SUBSTRING MATCHING)
--------------------------------------------------------------------------------
local f00 = targetMap:FindFirstChild("00_Sealed_Arena_Boundary_And_Perimeter")
local f01 = targetMap:FindFirstChild("01_OpenWorld_Baseplate_And_Cityscape")
local f02 = targetMap:FindFirstChild("02_Showcase_Spawn_Terminals_And_Vehicles")
local _f03 = targetMap:FindFirstChild("03_Mid_Carousel_And_FerrisWheel")
local _f04 = targetMap:FindFirstChild("04_North_Lane_Arcade_And_BumperDome")
local f05 = targetMap:FindFirstChild("05_South_Lane_Coaster_And_Boardwalk")
local f06 = targetMap:FindFirstChild("06_Detailed_Tactical_Cover_And_Props")

for _, generatedName in ipairs({
	"07_Symmetrical_MidCover_And_Vehicles",
	"08_Tactical_Callouts_And_Objectives",
	"Arena_Precision_Floor",
	"Arena_MasterFloor_System",
	"Arena_3D_Vehicles",
}) do
	local old = targetMap:FindFirstChild(generatedName, true)
	if old then
		old:Destroy()
	end
end

safeRun("RemoveTargetPracticesAndOOB", function()
	if f05 then
		for _, exactBooth in ipairs({ "Carnival_Alpha_RingToss_Booth", "Carnival_Bravo_Shooting_Booth" }) do
			local b = f05:FindFirstChild(exactBooth)
			if b then
				b:Destroy()
				stats.deletedTargetProps += 1
			end
		end
	end

	if f01 then
		local keepF01: { [string]: boolean } = {
			["Underpass_Floor"] = true,
			["Underpass_3DWall_North"] = true,
			["Underpass_3DWall_South"] = true,
			["Underpass_EndWall_West"] = true,
			["Underpass_EndWall_East"] = true,
			["Underpass_Stairs_Alpha"] = true,
			["Underpass_Stairs_Bravo"] = true,
		}
		for _, child in ipairs(f01:GetChildren()) do
			if not keepF01[child.Name] and string.sub(child.Name, 1, 21) ~= "Underpass_HazardLight" then
				child:Destroy()
				stats.deletedOOB += 1
			end
		end
	end

	if f06 then
		for _, exactTree in ipairs({ "OvergrownTree_8", "OvergrownTree_9", "OvergrownTree_10", "OvergrownTree_11" }) do
			local t = f06:FindFirstChild(exactTree)
			if t then
				t:Destroy()
				stats.deletedOOB += 1
			end
		end
	end

	if f02 then
		for _, exactVeh in ipairs({
			"Alpha_Showcase_TransitBus",
			"Bravo_Showcase_TransitBus",
			"Alpha_Showcase_PoliceCruiser",
			"Bravo_Showcase_PoliceCruiser",
			"Alpha_Showcase_CityTaxi",
			"Bravo_Showcase_CityTaxi",
		}) do
			local v = f02:FindFirstChild(exactVeh)
			if v then
				v:Destroy()
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- 3. COLLISION, RAYCAST (CanQuery), TOP-PRESERVING SNAP & O(1) DEDUPLICATION
--------------------------------------------------------------------------------
local RELIEF_PREFIXES = {
	"BrickRelief_",
	"Plaster_",
	"Pilaster_Flute_",
	"Dentil_",
	"Conduit_",
	"Junction_Box",
	"Box_LED",
	"Dado_Rail",
}

local function isExplicitWallRelief(name: string): boolean
	for _, prefix in ipairs(RELIEF_PREFIXES) do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

safeRun("SanitizeGeometryAndCollision", function()
	for _, inst in ipairs(targetMap:GetDescendants()) do
		if inst:IsA("BasePart") then
			local name = inst.Name
			local inPerim = (f00 ~= nil and inst:IsDescendantOf(f00))

			if inPerim then
				if
					string.sub(name, 1, 10) == "IronPicket"
					or string.sub(name, 1, 11) == "PicketSpike"
					or string.sub(name, 1, 16) == "Perim_Pillar_Orb"
				then
					inst.CanCollide = false
					inst.CanTouch = false
					inst.CanQuery = false
					inst.CastShadow = false
					stats.shadowCulledMicroParts += 1
				end
				continue
			end

			inst.Anchored = true
			inst.TopSurface = Enum.SurfaceType.Smooth
			inst.BottomSurface = Enum.SurfaceType.Smooth

			if inst.Material == Enum.Material.Glass or string.find(name, "Glass") ~= nil or string.find(name, "Window") ~= nil then
				inst.CanCollide = true
				inst.CanQuery = true
				inst.CastShadow = false
				CollectionService:AddTag(inst, "WindowGlass")
				inst:SetAttribute("PenetrationMultiplier", 0.75)
				stats.taggedWindows += 1
			end

			if isExplicitWallRelief(name) then
				inst.CanCollide = false
				inst.CanTouch = false
				inst.CanQuery = false
				inst.CastShadow = false
				CollectionService:AddTag(inst, "WallRelief")
				stats.taggedReliefs += 1
			end

			if inst.Size.Magnitude < 2.5 then
				inst.CastShadow = false
				stats.shadowCulledMicroParts += 1
			end

			if inst.CanCollide and math.abs(inst.CFrame.UpVector.Y) > 0.999 and not inst:GetAttribute("GroundSnapped") then
				local aabb = getPartAABB(inst, 0)
				if aabb.minY > -0.8 and aabb.minY < 0.6 and math.abs(aabb.minY) > 0.005 and aabb.maxY > 3.0 then
					local fixedTopY = aabb.maxY
					local newHeight = fixedTopY
					local newCenterY = fixedTopY * 0.5
					inst.Size = Vector3.new(inst.Size.X, newHeight, inst.Size.Z)
					inst.CFrame = CFrame.new(inst.Position.X, newCenterY, inst.Position.Z) * inst.CFrame.Rotation
					inst:SetAttribute("GroundSnapped", true)
					stats.resizedGroundWalls += 1
				end
			end

			local box = getPartAABB(inst, 0)
			if checkAndInsertSpatial(box, 0.08) then
				inst:Destroy()
				stats.deletedDuplicates += 1
				continue
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- 4. TAGGED ZERO-GAP FLOOR, ROAD DETAIL PROPS & SMOOTH STAIRS
--------------------------------------------------------------------------------
local function makeTaggedPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	mat: Enum.Material,
	col: Color3,
	canCollide: boolean,
	tag: string?,
	trans: number?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = canCollide
	p.CanTouch = canCollide
	p.CanQuery = canCollide
	p.CastShadow = canCollide and ((trans or 0) < 0.5)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = mat
	p.Color = col
	p.Transparency = trans or 0
	p.Size = size
	p.CFrame = cf
	if tag then
		CollectionService:AddTag(p, tag)
	end
	p.Parent = parent
	if canCollide then
		checkAndInsertSpatial(getPartAABB(p, 0), nil)
	end
	return p
end

local function makeTaggedWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	mat: Enum.Material,
	col: Color3,
	canCollide: boolean,
	tag: string?,
	trans: number?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.CanCollide = canCollide
	w.CanTouch = canCollide
	w.CanQuery = canCollide
	w.CastShadow = canCollide and ((trans or 0) < 0.5)
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Material = mat
	w.Color = col
	w.Transparency = trans or 0
	w.Size = size
	w.CFrame = cf
	if tag then
		CollectionService:AddTag(w, tag)
	end
	w.Parent = parent
	return w
end

safeRun("BuildTaggedFloorAndDetailProps", function()
	local floorFolder = Instance.new("Folder")
	floorFolder.Name = "Arena_Precision_Floor"
	floorFolder.Parent = f01 or targetMap

	local plazaCol = Color3.fromRGB(126, 124, 120)
	local roadCol = Color3.fromRGB(58, 60, 64)

	makeTaggedPart(floorFolder, "Floor_North_Plaza", Vector3.new(328, 2, 92.0), CFrame.new(0, -1, -68.0), Enum.Material.Concrete, plazaCol, true, "MapFloor")
	makeTaggedPart(floorFolder, "Floor_South_Boardwalk", Vector3.new(328, 2, 92.0), CFrame.new(0, -1, 68.0), Enum.Material.Concrete, plazaCol, true, "MapFloor")
	makeTaggedPart(floorFolder, "Road_North_Lane", Vector3.new(328, 2, 16.5), CFrame.new(0, -1, -13.75), Enum.Material.Asphalt, roadCol, true, "MapFloor")
	makeTaggedPart(floorFolder, "Road_South_Lane", Vector3.new(328, 2, 16.5), CFrame.new(0, -1, 13.75), Enum.Material.Asphalt, roadCol, true, "MapFloor")
	makeTaggedPart(floorFolder, "Road_West_Outer", Vector3.new(114.6, 2, 11.0), CFrame.new(-106.7, -1, 0), Enum.Material.Asphalt, roadCol, true, "MapFloor")
	makeTaggedPart(floorFolder, "Road_East_Outer", Vector3.new(114.6, 2, 11.0), CFrame.new(106.7, -1, 0), Enum.Material.Asphalt, roadCol, true, "MapFloor")
	makeTaggedPart(floorFolder, "Road_Center_Bridge", Vector3.new(67.2, 1.0, 11.0), CFrame.new(0, -0.5, 0), Enum.Material.Cobblestone, Color3.fromRGB(108, 104, 98), true, "MapFloor")

	for _, signX in ipairs({ -1, 1 }) do
		makeTaggedPart(floorFolder, "TrenchParapet_N_" .. signX, Vector3.new(16.2, 3.2, 0.7), CFrame.new(signX * 41.5, 1.6, -5.85), Enum.Material.Concrete, plazaCol, true, "TacticalCover")
		makeTaggedPart(floorFolder, "TrenchParapet_S_" .. signX, Vector3.new(16.2, 3.2, 0.7), CFrame.new(signX * 41.5, 1.6, 5.85), Enum.Material.Concrete, plazaCol, true, "TacticalCover")
		makeTaggedPart(floorFolder, "TrenchParapet_Outer_" .. signX, Vector3.new(0.7, 3.2, 12.4), CFrame.new(signX * 49.75, 1.6, 0), Enum.Material.Concrete, plazaCol, true, "TacticalCover")
	end

	for _, cx in ipairs({ -102, -56, 56, 102 }) do
		for z = -18, 18, 4.5 do
			makeTaggedPart(floorFolder, "CrosswalkStripe", Vector3.new(6.0, 0.02, 1.8), CFrame.new(cx, 0.005, z), Enum.Material.Concrete, Color3.fromRGB(212, 208, 198), false, "DetailProp")
		end
	end

	for _, mhPos in ipairs({ Vector3.new(-74, 0.01, -12), Vector3.new(74, 0.01, 12), Vector3.new(-22, 0.01, 14), Vector3.new(22, 0.01, -14) }) do
		local mh = makeTaggedPart(
			floorFolder,
			"ManholeCover",
			Vector3.new(0.06, 3.2, 3.2),
			CFrame.new(mhPos) * CFrame.Angles(0, 0, math.pi * 0.5),
			Enum.Material.DiamondPlate,
			Color3.fromRGB(62, 58, 54),
			false,
			"DetailProp",
			0,
			Enum.PartType.Cylinder
		)
		mh.CastShadow = false
	end

	for _, pud in ipairs({
		{ pos = Vector3.new(-88, 0.004, -8), sz = Vector3.new(0.01, 7.5, 5.2) },
		{ pos = Vector3.new(88, 0.004, 8), sz = Vector3.new(0.01, 7.5, 5.2) },
		{ pos = Vector3.new(-38, 0.004, 15), sz = Vector3.new(0.01, 6.0, 4.5) },
		{ pos = Vector3.new(38, 0.004, -15), sz = Vector3.new(0.01, 6.0, 4.5) },
	}) do
		local p = makeTaggedPart(
			floorFolder,
			"RainPuddle",
			pud.sz,
			CFrame.new(pud.pos) * CFrame.Angles(0, 0, math.pi * 0.5),
			Enum.Material.Glass,
			Color3.fromRGB(78, 88, 98),
			false,
			"DetailProp",
			0.35,
			Enum.PartType.Cylinder
		)
		p.Reflectance = 0.65
		p.CastShadow = false
	end
end)

--------------------------------------------------------------------------------
-- 5. SYMMETRICAL 5V5 COVER & MULTI-VARIANT 3D VEHICLE GENERATOR (180° MIRRORED)
--------------------------------------------------------------------------------
local symFolder = Instance.new("Folder")
symFolder.Name = "07_Symmetrical_MidCover_And_Vehicles"
symFolder.Parent = targetMap

local function mirrorCF180(cf: CFrame): CFrame
	return CFrame.new(-cf.Position.X, cf.Position.Y, -cf.Position.Z) * CFrame.Angles(0, math.pi, 0) * cf.Rotation
end

local function spawnSymmetricalVehiclePair(baseName: string, variant: string, alphaGroundCF: CFrame, alphaColor: Color3, bravoColor: Color3)
	local configs = {
		{ suffix = "Alpha", cf = alphaGroundCF, col = alphaColor },
		{ suffix = "Bravo", cf = mirrorCF180(alphaGroundCF), col = bravoColor },
	}

	for _, cfg in ipairs(configs) do
		local m = Instance.new("Model")
		m.Name = string.format("%s_%s_%s", baseName, variant, cfg.suffix)
		CollectionService:AddTag(m, "InteractiveVehicle")
		CollectionService:AddTag(m, "Vaultable")
		CollectionService:AddTag(m, "TacticalCover")

		local isVan = (variant == "Van")
		local isHatch = (variant == "Hatchback")
		local isTaxi = (variant == "Taxi")

		local length = isVan and 17.6 or (isHatch and 13.4 or 15.6)
		local width = isVan and 7.2 or 6.6
		local height = isVan and 7.2 or 5.0

		m:SetAttribute("VehicleVariant", variant)
		m:SetAttribute("VaultHeight", height)
		m:SetAttribute("MaxHealth", isVan and 600 or 400)
		m:SetAttribute("Health", isVan and 600 or 400)
		m:SetAttribute("AlarmTriggered", false)

		local o = cfg.cf
		local trimCol = Color3.fromRGB(32, 35, 40)
		local glassCol = Color3.fromRGB(40, 50, 60)

		local hull = makeTaggedPart(
			m,
			"VehicleHull",
			Vector3.new(width, height, length),
			o * CFrame.new(0, height * 0.5, 0),
			Enum.Material.SmoothPlastic,
			cfg.col,
			true,
			"InteractiveVehicle",
			1.0
		)
		m.PrimaryPart = hull

		local alarm = Instance.new("Sound")
		alarm.Name = "CarAlarmSound"
		alarm.SoundId = AssetRegistry.Audio.Environment.CarAlarmSound
		alarm.Volume = 0.8
		alarm.RollOffMaxDistance = 85
		alarm.Looped = true
		alarm.Parent = hull

		makeTaggedPart(m, "ChassisPan", Vector3.new(width - 0.5, 0.5, length - 0.8), o * CFrame.new(0, 1.05, 0), Enum.Material.Metal, trimCol, false, nil)

		if isVan then
			makeTaggedPart(m, "Van_CargoBox", Vector3.new(width, 4.6, 12.6), o * CFrame.new(0, 3.6, 2.1), Enum.Material.Metal, cfg.col, false, nil)
			makeTaggedPart(m, "Van_CabLower", Vector3.new(width - 0.2, 2.2, 4.6), o * CFrame.new(0, 2.4, -6.5), Enum.Material.Metal, cfg.col, false, nil)
			makeTaggedWedge(m, "Van_HoodSlope", Vector3.new(width - 0.2, 1.2, 2.4), o * CFrame.new(0, 4.1, -7.6), Enum.Material.Metal, cfg.col, false, nil)
			makeTaggedWedge(m, "Van_Windshield", Vector3.new(width - 0.6, 2.0, 2.2), o * CFrame.new(0, 4.9, -5.3), Enum.Material.Glass, glassCol, false, "WindowGlass", 0.3)
			makeTaggedPart(m, "Van_CabGlass", Vector3.new(width - 0.5, 2.0, 2.2), o * CFrame.new(0, 4.9, -3.1), Enum.Material.Glass, glassCol, false, "WindowGlass", 0.3)
		else
			local trunkLen = isHatch and 1.4 or 3.4
			local centerZ = isHatch and 0.9 or 0.2
			makeTaggedPart(m, "Body_Center", Vector3.new(width, 1.9, 7.6), o * CFrame.new(0, 2.15, centerZ), Enum.Material.Metal, cfg.col, false, nil)
			makeTaggedPart(m, "Body_Hood", Vector3.new(width - 0.2, 1.65, 4.2), o * CFrame.new(0, 2.02, -5.5), Enum.Material.Metal, cfg.col, false, nil)
			makeTaggedWedge(m, "Hood_Slope", Vector3.new(width - 0.2, 0.25, 4.2), o * CFrame.new(0, 2.97, -5.5), Enum.Material.Metal, cfg.col, false, nil)
			if not isHatch then
				makeTaggedPart(m, "Body_Trunk", Vector3.new(width - 0.2, 1.75, trunkLen), o * CFrame.new(0, 2.07, 5.7), Enum.Material.Metal, cfg.col, false, nil)
			end
			makeTaggedPart(m, "Cabin_Glass", Vector3.new(width - 0.8, 1.65, 4.6), o * CFrame.new(0, 3.92, centerZ), Enum.Material.Glass, glassCol, false, "WindowGlass", 0.35)
			makeTaggedPart(m, "Cabin_Roof", Vector3.new(width - 0.7, 0.22, 4.8), o * CFrame.new(0, 4.86, centerZ), Enum.Material.Metal, cfg.col, false, nil)
			makeTaggedWedge(m, "Windshield", Vector3.new(width - 0.8, 1.65, 2.1), o * CFrame.new(0, 3.92, centerZ - 3.35), Enum.Material.Glass, glassCol, false, "WindowGlass", 0.35)
			makeTaggedWedge(
				m,
				"RearWindow",
				Vector3.new(width - 0.8, 1.65, 1.8),
				o * CFrame.new(0, 3.92, centerZ + 3.2) * CFrame.Angles(0, math.pi, 0),
				Enum.Material.Glass,
				glassCol,
				false,
				"WindowGlass",
				0.35
			)
			if isTaxi then
				local signPart = makeTaggedPart(
					m,
					"TaxiRoofSign",
					Vector3.new(2.2, 0.5, 0.8),
					o * CFrame.new(0, 5.2, centerZ),
					Enum.Material.SmoothPlastic,
					Color3.fromRGB(235, 190, 48),
					false,
					nil
				)
				signPart.CastShadow = false
			end
		end

		local halfL = length * 0.5
		local halfW = width * 0.5
		local microParts = {
			makeTaggedPart(m, "Bumper_F", Vector3.new(width + 0.1, 0.85, 0.65), o * CFrame.new(0, 1.4, -halfL + 0.2), Enum.Material.SmoothPlastic, trimCol, false, nil),
			makeTaggedPart(m, "Bumper_R", Vector3.new(width + 0.1, 0.85, 0.65), o * CFrame.new(0, 1.4, halfL - 0.2), Enum.Material.SmoothPlastic, trimCol, false, nil),
			makeTaggedPart(m, "LicensePlate_F", Vector3.new(1.4, 0.65, 0.08), o * CFrame.new(0, 1.4, -halfL - 0.12), Enum.Material.Metal, Color3.fromRGB(235, 232, 220), false, nil),
			makeTaggedPart(m, "LicensePlate_R", Vector3.new(1.4, 0.65, 0.08), o * CFrame.new(0, 1.4, halfL + 0.12), Enum.Material.Metal, Color3.fromRGB(235, 232, 220), false, nil),
			makeTaggedPart(m, "DoorSeam_L", Vector3.new(0.06, 1.75, 0.08), o * CFrame.new(-halfW - 0.01, 2.15, -0.4), Enum.Material.SmoothPlastic, trimCol, false, nil),
			makeTaggedPart(m, "DoorSeam_R", Vector3.new(0.06, 1.75, 0.08), o * CFrame.new(halfW + 0.01, 2.15, -0.4), Enum.Material.SmoothPlastic, trimCol, false, nil),
			makeTaggedPart(m, "Mirror_L", Vector3.new(0.55, 0.35, 0.4), o * CFrame.new(-halfW - 0.2, 3.1, -2.4), Enum.Material.Metal, cfg.col, false, nil),
			makeTaggedPart(m, "Mirror_R", Vector3.new(0.55, 0.35, 0.4), o * CFrame.new(halfW + 0.2, 3.1, -2.4), Enum.Material.Metal, cfg.col, false, nil),
			makeTaggedPart(m, "Headlight_L", Vector3.new(1.1, 0.45, 0.12), o * CFrame.new(-halfW + 0.9, 2.2, -halfL + 0.05), Enum.Material.Glass, Color3.fromRGB(238, 242, 246), false, nil, 0.1),
			makeTaggedPart(m, "Headlight_R", Vector3.new(1.1, 0.45, 0.12), o * CFrame.new(halfW - 0.9, 2.2, -halfL + 0.05), Enum.Material.Glass, Color3.fromRGB(238, 242, 246), false, nil, 0.1),
			makeTaggedPart(m, "Taillight_L", Vector3.new(1.2, 0.45, 0.12), o * CFrame.new(-halfW + 0.9, 2.3, halfL - 0.05), Enum.Material.Glass, Color3.fromRGB(168, 34, 34), false, nil, 0.1),
			makeTaggedPart(m, "Taillight_R", Vector3.new(1.2, 0.45, 0.12), o * CFrame.new(halfW - 0.9, 2.3, halfL - 0.05), Enum.Material.Glass, Color3.fromRGB(168, 34, 34), false, nil, 0.1),
		}
		for _, mp in ipairs(microParts) do
			mp.CastShadow = false
		end

		local wheelZ = halfL - 3.2
		for _, w in ipairs({ { -halfW + 0.15, -wheelZ, -1 }, { halfW - 0.15, -wheelZ, 1 }, { -halfW + 0.15, wheelZ, -1 }, { halfW - 0.15, wheelZ, 1 } }) do
			local tire = makeTaggedPart(
				m,
				"Tire",
				Vector3.new(0.95, 2.6, 2.6),
				o * CFrame.new(w[1], 1.3, w[2]) * CFrame.Angles(0, 0, math.pi * 0.5),
				Enum.Material.SmoothPlastic,
				Color3.fromRGB(24, 26, 28),
				false,
				nil,
				0,
				Enum.PartType.Cylinder
			)
			local rim = makeTaggedPart(
				m,
				"Rim",
				Vector3.new(0.92, 1.6, 1.6),
				o * CFrame.new(w[1] + w[3] * 0.05, 1.3, w[2]) * CFrame.Angles(0, 0, math.pi * 0.5),
				Enum.Material.Metal,
				Color3.fromRGB(180, 185, 192),
				false,
				nil,
				0,
				Enum.PartType.Cylinder
			)
			tire.CastShadow = false
			rim.CastShadow = false
		end

		m.Parent = symFolder
		stats.mirroredPropsSpawned += 1
	end
end

local function spawnSymmetricalBusStopAndCover(alphaCF: CFrame)
	for _, cfg in ipairs({ { suffix = "Alpha", cf = alphaCF }, { suffix = "Bravo", cf = mirrorCF180(alphaCF) } }) do
		local m = Instance.new("Model")
		m.Name = "MidRoad_BusStopShelter_" .. cfg.suffix
		CollectionService:AddTag(m, "TacticalCover")
		local o = cfg.cf
		local frameCol = Color3.fromRGB(45, 48, 54)

		makeTaggedPart(m, "Shelter_Roof", Vector3.new(14.0, 0.5, 5.5), o * CFrame.new(0, 8.75, 0), Enum.Material.Metal, frameCol, true, "TacticalCover")
		makeTaggedPart(m, "Post_L", Vector3.new(0.5, 8.5, 0.5), o * CFrame.new(-6.5, 4.25, -2.2), Enum.Material.Metal, frameCol, true, "TacticalCover")
		makeTaggedPart(m, "Post_R", Vector3.new(0.5, 8.5, 0.5), o * CFrame.new(6.5, 4.25, -2.2), Enum.Material.Metal, frameCol, true, "TacticalCover")
		makeTaggedPart(m, "Post_Center", Vector3.new(0.5, 8.5, 0.5), o * CFrame.new(0, 4.25, -2.2), Enum.Material.Metal, frameCol, true, "TacticalCover")

		makeTaggedPart(m, "Shelter_Glass_L", Vector3.new(6.0, 7.2, 0.2), o * CFrame.new(-3.25, 4.2, -2.2), Enum.Material.Glass, Color3.fromRGB(175, 198, 212), true, "WindowGlass", 0.5)
		makeTaggedPart(m, "Shelter_Glass_R", Vector3.new(6.0, 7.2, 0.2), o * CFrame.new(3.25, 4.2, -2.2), Enum.Material.Glass, Color3.fromRGB(175, 198, 212), true, "WindowGlass", 0.5)
		makeTaggedPart(m, "Shelter_AdPanel_Side", Vector3.new(0.4, 7.6, 4.8), o * CFrame.new(-6.6, 4.2, 0), Enum.Material.Metal, Color3.fromRGB(58, 62, 68), true, "TacticalCover")

		makeTaggedPart(m, "Shelter_Bench", Vector3.new(8.0, 0.4, 1.8), o * CFrame.new(1.5, 1.8, -1.0), Enum.Material.WoodPlanks, Color3.fromRGB(122, 88, 58), true, "TacticalCover")

		local lightBar = makeTaggedPart(
			m,
			"Shelter_LightDiffuser",
			Vector3.new(8.0, 0.15, 0.8),
			o * CFrame.new(0, 8.42, 0),
			Enum.Material.Glass,
			Color3.fromRGB(252, 246, 234),
			false,
			nil,
			0.15
		)
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Color = Color3.fromRGB(255, 245, 228)
		sl.Brightness = 1.2
		sl.Range = 18
		sl.Shadows = false
		sl.Parent = lightBar
		stats.lightsCreated += 1

		m.Parent = symFolder
		stats.mirroredPropsSpawned += 1
	end
end

local function spawnSymmetricalPlanterBarrier(name: string, alphaCF: CFrame)
	for _, cfg in ipairs({ { suffix = "Alpha", cf = alphaCF }, { suffix = "Bravo", cf = mirrorCF180(alphaCF) } }) do
		local m = Instance.new("Model")
		m.Name = name .. "_" .. cfg.suffix
		CollectionService:AddTag(m, "TacticalCover")
		local o = cfg.cf

		makeTaggedPart(m, "Planter_ConcreteWall", Vector3.new(11.0, 3.2, 3.6), o * CFrame.new(0, 1.6, 0), Enum.Material.Concrete, Color3.fromRGB(134, 130, 124), true, "TacticalCover")
		makeTaggedPart(m, "Planter_Soil", Vector3.new(10.2, 0.2, 2.8), o * CFrame.new(0, 3.15, 0), Enum.Material.Ground, Color3.fromRGB(72, 56, 44), false, nil)
		makeTaggedPart(m, "Planter_Hedge", Vector3.new(9.6, 1.4, 2.2), o * CFrame.new(0, 3.8, 0), Enum.Material.Grass, Color3.fromRGB(68, 96, 62), false, nil)

		for _, bx in ipairs({ -7.2, 7.2 }) do
			local bol = makeTaggedPart(
				m,
				"SteelBollard",
				Vector3.new(3.4, 0.8, 0.8),
				o * CFrame.new(bx, 1.7, 0) * CFrame.Angles(0, 0, math.pi * 0.5),
				Enum.Material.Metal,
				Color3.fromRGB(48, 52, 58),
				true,
				"TacticalCover",
				0,
				Enum.PartType.Cylinder
			)
			bol.CastShadow = false
		end

		m.Parent = symFolder
		stats.mirroredPropsSpawned += 1
	end
end

safeRun("SpawnSymmetrical5v5Layout", function()
	spawnSymmetricalVehiclePair("MidLane_CoverVan", "Van", CFrame.new(-44, 0, -14) * CFrame.Angles(0, math.rad(78), 0), Color3.fromRGB(218, 222, 226), Color3.fromRGB(218, 222, 226))
	spawnSymmetricalVehiclePair("Roadway_Cruiser", "Sedan", CFrame.new(-88, 0, 14) * CFrame.Angles(0, math.rad(102), 0), Color3.fromRGB(46, 58, 74), Color3.fromRGB(74, 48, 46))
	spawnSymmetricalVehiclePair("Plaza_Compact", "Hatchback", CFrame.new(-112, 0, -34) * CFrame.Angles(0, math.rad(22), 0), Color3.fromRGB(82, 92, 86), Color3.fromRGB(92, 84, 76))
	spawnSymmetricalVehiclePair("Boardwalk_Cab", "Taxi", CFrame.new(-64, 0, 36) * CFrame.Angles(0, math.rad(65), 0), Color3.fromRGB(218, 174, 48), Color3.fromRGB(218, 174, 48))

	spawnSymmetricalBusStopAndCover(CFrame.new(-68, 0, -21.5))
	spawnSymmetricalPlanterBarrier("MidRoad_CrouchPlanter", CFrame.new(-18, 0, 15.5) * CFrame.Angles(0, math.rad(-12), 0))
end)

--------------------------------------------------------------------------------
-- 6. SOFT INTERIOR & STREETLAMP LIGHTING + SUNLIGHT PRIMARY SOURCE
--------------------------------------------------------------------------------
local function attachSoftLight(parentPart: BasePart, lightType: string, color: Color3, brightness: number, range: number, shadows: boolean)
	local l = Instance.new(lightType) :: Light
	l.Name = "NaturalSoftLight"
	l.Color = color
	l.Brightness = brightness
	l.Shadows = shadows
	if l:IsA("PointLight") then
		l.Range = range
	elseif l:IsA("SurfaceLight") then
		l.Range = range
		l.Face = Enum.NormalId.Bottom
		l.Angle = 115
	elseif l:IsA("SpotLight") then
		l.Range = range
		l.Face = Enum.NormalId.Bottom
		l.Angle = 115
	end
	l.Parent = parentPart
	stats.lightsCreated += 1
end

safeRun("ConfigureNaturalAndInteriorLighting", function()
	for _, inst in ipairs(targetMap:GetDescendants()) do
		if (inst:IsA("SpotLight") or inst:IsA("PointLight")) and inst.Name ~= "NaturalSoftLight" then
			inst:Destroy()
		elseif inst:IsA("TextLabel") then
			inst.TextColor3 = Color3.fromRGB(242, 236, 224)
		elseif inst:IsA("BasePart") then
			if inst.Material == Enum.Material.Neon or inst.Material == Enum.Material.ForceField then
				if string.find(inst.Name, "Globe") or string.find(inst.Name, "Light") or string.find(inst.Name, "Tube") then
					inst.Material = Enum.Material.Glass
					inst.Color = Color3.fromRGB(248, 242, 228)
					attachSoftLight(inst, "PointLight", Color3.fromRGB(255, 240, 214), 1.15, 22, false)
				else
					inst.Material = Enum.Material.SmoothPlastic
					local h, s, v = inst.Color:ToHSV()
					inst.Color = Color3.fromHSV(h, math.min(s, 0.22), math.clamp(v, 0.35, 0.78))
				end
			end
		end
	end

	local interiorZones = {
		{ pos = Vector3.new(-64, 22.5, -82), range = 34, bright = 1.35 },
		{ pos = Vector3.new(-64, 10.8, -90), range = 26, bright = 1.25 },
		{ pos = Vector3.new(64, 22.5, -82), range = 34, bright = 1.35 },
		{ pos = Vector3.new(64, 10.8, -90), range = 26, bright = 1.25 },
		{ pos = Vector3.new(-74, 12.8, 60), range = 28, bright = 1.35 },
		{ pos = Vector3.new(74, 12.8, 60), range = 28, bright = 1.35 },
		{ pos = Vector3.new(0, 18.5, 0), range = 30, bright = 1.20 },
		{ pos = Vector3.new(0, 15.0, -82), range = 32, bright = 1.25 },
	}
	for i, iz in ipairs(interiorZones) do
		local fixture = makeTaggedPart(
			symFolder,
			"InteriorFixture_" .. i,
			Vector3.new(3.6, 0.2, 1.4),
			CFrame.new(iz.pos),
			Enum.Material.Glass,
			Color3.fromRGB(252, 246, 236),
			false,
			nil,
			0.15
		)
		fixture.CastShadow = false
		attachSoftLight(fixture, "SurfaceLight", Color3.fromRGB(255, 246, 232), iz.bright, iz.range, true)
	end

	pcall(function()
		Lighting.Technology = Enum.Technology.Future
		MaterialService.Use2022Materials = true
	end)

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	Lighting.Brightness = 3.2
	Lighting.ClockTime = 14.8
	Lighting.GeographicLatitude = 36.0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.EnvironmentDiffuseScale = 1.0
	Lighting.EnvironmentSpecularScale = 1.0
	Lighting.OutdoorAmbient = Color3.fromRGB(126, 134, 146)
	Lighting.Ambient = Color3.fromRGB(84, 90, 98)
	Lighting.ExposureCompensation = 0.05

	local sky = Instance.new("Sky")
	sky.Name = "NaturalDaylightSky"
	sky.SunAngularSize = 11
	sky.Parent = Lighting

	local atmo = Instance.new("Atmosphere")
	atmo.Name = "NaturalAtmosphere"
	atmo.Density = 0.24
	atmo.Offset = 0.2
	atmo.Color = Color3.fromRGB(202, 214, 228)
	atmo.Decay = Color3.fromRGB(112, 120, 132)
	atmo.Glare = 0.06
	atmo.Haze = 1.1
	atmo.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "NaturalColorGrading"
	cc.Contrast = 0.06
	cc.Saturation = -0.03
	cc.TintColor = Color3.fromRGB(255, 252, 247)
	cc.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "NaturalSpecularBloom"
	bloom.Intensity = 0.12
	bloom.Threshold = 2.4
	bloom.Size = 24
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Name = "NaturalSunRays"
	rays.Intensity = 0.04
	rays.Spread = 0.4
	rays.Parent = Lighting
end)

--------------------------------------------------------------------------------
-- 7. TACTICAL CALLOUT ZONES & SPAWN PROTECTION VOLUMES
--------------------------------------------------------------------------------
safeRun("BuildCalloutAndSpawnProtectionZones", function()
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = "08_Tactical_Callouts_And_Objectives"
	zoneFolder.Parent = targetMap

	local calloutDefs: { { name: string, pos: Vector3, size: Vector3, spawnTeam: string? } } = {
		{ name = "Alpha Metro Terminal", pos = Vector3.new(-146, 10, 0), size = Vector3.new(32, 20, 86), spawnTeam = "Alpha" },
		{ name = "Bravo Pier Station", pos = Vector3.new(146, 10, 0), size = Vector3.new(32, 20, 86), spawnTeam = "Bravo" },
		{ name = "Mid Carousel Rotunda", pos = Vector3.new(0, 12, 0), size = Vector3.new(48, 24, 44), spawnTeam = nil },
		{ name = "Underpass Trench", pos = Vector3.new(0, -5, 0), size = Vector3.new(96, 10, 24), spawnTeam = nil },
		{ name = "North Starlight Arcade (Alpha)", pos = Vector3.new(-64, 12, -82), size = Vector3.new(46, 24, 46), spawnTeam = nil },
		{ name = "North Starlight Arcade (Bravo)", pos = Vector3.new(64, 12, -82), size = Vector3.new(46, 24, 46), spawnTeam = nil },
		{ name = "North Bumper Dome", pos = Vector3.new(0, 10, -82), size = Vector3.new(44, 20, 44), spawnTeam = nil },
		{ name = "South Coaster Boardwalk", pos = Vector3.new(0, 10, 86), size = Vector3.new(110, 20, 36), spawnTeam = nil },
		{ name = "Alpha Coaster Diner", pos = Vector3.new(-74, 8, 60), size = Vector3.new(34, 16, 24), spawnTeam = nil },
		{ name = "Bravo Pier Diner", pos = Vector3.new(74, 8, 60), size = Vector3.new(34, 16, 24), spawnTeam = nil },
	}

	for _, cd in ipairs(calloutDefs) do
		local z = makeTaggedPart(
			zoneFolder,
			"Zone_" .. cd.name,
			cd.size,
			CFrame.new(cd.pos),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(255, 255, 255),
			false,
			"CalloutZone",
			1.0
		)
		z:SetAttribute("CalloutName", cd.name)
		if cd.spawnTeam then
			CollectionService:AddTag(z, "SpawnProtection")
			z:SetAttribute("ProtectedTeam", cd.spawnTeam)
		end
	end
end)

pcall(function()
	ChangeHistoryService:SetWaypoint("After_PhantomMidway_V2_AuditFix")
end)

print(
	string.format(
		"[MapRefactor V2 Audit] Deleted OOB: %d | Deleted Target Booths: %d | Deleted Duplicates: %d | Resized Ground Walls: %d | Tagged Windows: %d | Tagged Reliefs: %d | Soft Lights Added: %d | Symmetrical Props/Cars Spawned: %d | Shadow-Culled Micro-Parts: %d | Errors: %d",
		stats.deletedOOB,
		stats.deletedTargetProps,
		stats.deletedDuplicates,
		stats.resizedGroundWalls,
		stats.taggedWindows,
		stats.taggedReliefs,
		stats.lightsCreated,
		stats.mirroredPropsSpawned,
		stats.shadowCulledMicroParts,
		stats.errors
	)
)
