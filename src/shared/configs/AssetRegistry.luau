--!strict
--[[
	AssetRegistry.luau
	Centralized read-only registry for standardized NetworkEvents, audio IDs, UI sprite IDs,
	and 3D models. Provides procedural fallback rigs matching ViewmodelController's exact
	RootPart -> WeaponMotor/WeaponMesh + AimMotor/AimPart + MuzzleAttachment hierarchy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = table.freeze({
	Movement = table.freeze({
		BhopLand = "rbxassetid://9118823101",
		JumpLaunch = "rbxassetid://9118823101",
		SlideStart = "rbxassetid://9117969892",
		SlideLoop = "rbxassetid://9117969892",
		WindRushLoop = "rbxassetid://9114224721",
		FootstepMetal = "rbxassetid://9118823101",
	}),
	Weapons = table.freeze({
		PulseRifleFire = "rbxassetid://130113322",
		PulseRifleReload = "rbxassetid://130113370",
		RailgunFire = "rbxassetid://169380525",
		RailgunReload = "rbxassetid://130113370",
		PlasmaShotgunFire = "rbxassetid://130113322",
		PlasmaShotgunReload = "rbxassetid://130113370",
		IonSidearmFire = "rbxassetid://130113322",
		IonSidearmReload = "rbxassetid://130113370",
		DryFire = "rbxassetid://130113370",
	}),
	UI = table.freeze({
		HitmarkerBody = "rbxassetid://160432334",
		HitmarkerHeadshot = "rbxassetid://160432334",
		KillConfirm = "rbxassetid://160432334",
		WeaponSwitch = "rbxassetid://130113370",
		SFX_UI_PurchaseConfirm = "rbxassetid://160432334",
		SFX_UI_PurchaseDenied = "rbxassetid://130113370",
		SFX_UI_ItemRefund = "rbxassetid://130113370",
		SFX_HUD_OverdriveKillBounty = "rbxassetid://160432334",
	}),
})

local UISprites = table.freeze({
	Crosshairs = table.freeze({
		CenterDot = "rbxassetid://0",
		BracketTop = "rbxassetid://0",
		BracketBottom = "rbxassetid://0",
		BracketLeft = "rbxassetid://0",
		BracketRight = "rbxassetid://0",
		HitmarkerCross = "rbxassetid://0",
	}),
	WeaponIcons = table.freeze({
		VORTEX_SMG = "rbxassetid://0",
		HELIOS_RAIL = "rbxassetid://0",
		PulseRifle = "rbxassetid://0",
		Railgun = "rbxassetid://0",
		PlasmaShotgun = "rbxassetid://0",
		IonSidearm = "rbxassetid://0",
		Sprite_Wpn_PulsePistol = "rbxassetid://0",
		Sprite_Wpn_TachyonAuto9 = "rbxassetid://0",
		Sprite_Wpn_IonRevolver = "rbxassetid://0",
		Sprite_Wpn_VectorSMG = "rbxassetid://0",
		Sprite_Wpn_ScatterShotgun = "rbxassetid://0",
		Sprite_Wpn_CobaltCarbine = "rbxassetid://0",
		Sprite_Wpn_VandalRailRifle = "rbxassetid://0",
		Sprite_Wpn_HelixSniper = "rbxassetid://0",
		Sprite_Armor_LightExo = "rbxassetid://0",
		Sprite_Armor_HeavyExo = "rbxassetid://0",
		Sprite_Util_ImpulseGrenade = "rbxassetid://0",
		Sprite_Util_ArcCell = "rbxassetid://0",
		Sprite_Util_PhaseStim = "rbxassetid://0",
	}),
})

-- Particle textures used by procedural weapon builders (WeaponBuilder.AddMuzzleEffects)
local Textures = table.freeze({
	MuzzleFlash = "rbxassetid://241650934",
	BarrelSmoke = "rbxassetid://243660364",
})

local NetworkEvents = table.freeze({
	-- Standardized Remote Names
	FireWeaponBuffer = "FireWeaponBuffer",
	ReloadWeaponEvent = "ReloadWeaponEvent",
	HitConfirmEvent = "HitConfirmEvent",
	StanceSyncBuffer = "StanceSyncBuffer",
	RequestDeploy = "RequestDeploy",
	EconomyPacketRemote = "EconomyPacketRemote",

	-- Legacy Aliases
	ShotFired = "FireWeaponBuffer",
	ShotReplicated = "ShotReplicated",
	HitConfirmed = "HitConfirmEvent",
	StanceChanged = "StanceSyncBuffer",
	WeaponEquipped = "WeaponEquipped",
	ReloadRequested = "ReloadWeaponEvent",
})

local function createProceduralViewmodel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name

	local isRailgun = name == "HELIOS_RAIL"
		or name == "RailgunViewmodel"
		or name == "Railgun"

	local meshSize = if isRailgun then Vector3.new(0.32, 0.42, 2.5) else Vector3.new(0.36, 0.44, 1.75)
	local sightHeight = if isRailgun then 0.28 else 0.25
	local accentColor = if isRailgun
		then Color3.fromRGB(255, 140, 35)
		else Color3.fromRGB(0, 225, 255)

	local rootPart = Instance.new("Part")
	rootPart.Name = "RootPart"
	rootPart.Size = Vector3.new(0.5, 0.5, 0.5)
	rootPart.Transparency = 1
	rootPart.Anchored = true
	rootPart.CanCollide = false
	rootPart.CanQuery = false
	rootPart.CanTouch = false
	rootPart.Massless = true
	rootPart.CFrame = CFrame.identity
	rootPart.Parent = model

	local weaponMesh = Instance.new("Part")
	weaponMesh.Name = "WeaponMesh"
	weaponMesh.Size = meshSize
	weaponMesh.Color = Color3.fromRGB(35, 42, 55)
	weaponMesh.Material = Enum.Material.Metal
	weaponMesh.Anchored = true
	weaponMesh.CanCollide = false
	weaponMesh.CanQuery = false
	weaponMesh.CanTouch = false
	weaponMesh.Massless = true
	weaponMesh.CFrame = rootPart.CFrame
	weaponMesh.Parent = model

	local barrelAccent = Instance.new("Part")
	barrelAccent.Name = "BarrelAccent"
	barrelAccent.Size = Vector3.new(meshSize.X * 0.45, meshSize.Y * 0.35, meshSize.Z * 0.85)
	barrelAccent.Color = accentColor
	barrelAccent.Material = Enum.Material.Neon
	barrelAccent.Anchored = true
	barrelAccent.CanCollide = false
	barrelAccent.CanQuery = false
	barrelAccent.CanTouch = false
	barrelAccent.Massless = true
	barrelAccent.CFrame = weaponMesh.CFrame * CFrame.new(0, 0.04, -0.08)
	barrelAccent.Parent = model

	local accentWeld = Instance.new("WeldConstraint")
	accentWeld.Name = "AccentWeld"
	accentWeld.Part0 = weaponMesh
	accentWeld.Part1 = barrelAccent
	accentWeld.Parent = weaponMesh

	local weaponMotor = Instance.new("Motor6D")
	weaponMotor.Name = "WeaponMotor"
	weaponMotor.Part0 = rootPart
	weaponMotor.Part1 = weaponMesh
	weaponMotor.C0 = CFrame.identity
	weaponMotor.C1 = CFrame.identity
	weaponMotor.Parent = rootPart

	local aimPart = Instance.new("Part")
	aimPart.Name = "AimPart"
	aimPart.Size = Vector3.new(0.2, 0.2, 0.2)
	aimPart.Transparency = 1
	aimPart.Anchored = true
	aimPart.CanCollide = false
	aimPart.CanQuery = false
	aimPart.CanTouch = false
	aimPart.Massless = true
	aimPart.CFrame = rootPart.CFrame * CFrame.new(0, sightHeight, 0.15)
	aimPart.Parent = model

	local aimMotor = Instance.new("Motor6D")
	aimMotor.Name = "AimMotor"
	aimMotor.Part0 = rootPart
	aimMotor.Part1 = aimPart
	aimMotor.C0 = CFrame.new(0, sightHeight, 0.15)
	aimMotor.C1 = CFrame.identity
	aimMotor.Parent = rootPart

	local muzzleAttachment = Instance.new("Attachment")
	muzzleAttachment.Name = "MuzzleAttachment"
	muzzleAttachment.Position = Vector3.new(0, 0.04, -weaponMesh.Size.Z * 0.5)
	muzzleAttachment.Parent = weaponMesh

	local animController = Instance.new("AnimationController")
	animController.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = animController

	model.PrimaryPart = rootPart
	return model
end

local function createProceduralWorldmodel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.4, 1.6)
	handle.Color = Color3.fromRGB(45, 50, 65)
	handle.Material = Enum.Material.Metal
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = model

	local muzzleAttachment = Instance.new("Attachment")
	muzzleAttachment.Name = "MuzzleAttachment"
	muzzleAttachment.Position = Vector3.new(0, 0.1, -0.8)
	muzzleAttachment.Parent = handle

	model.PrimaryPart = handle
	return model
end

local function createProceduralCharacterRig(name: string): Model
	local model = Instance.new("Model")
	model.Name = name

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = Color3.fromRGB(50, 65, 90)
	torso.Material = Enum.Material.SmoothPlastic
	torso.CanCollide = true
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Color = Color3.fromRGB(220, 230, 240)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Parent = model

	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "RootJoint"
	rootJoint.Part0 = rootPart
	rootJoint.Part1 = torso
	rootJoint.Parent = rootPart

	local neck = Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = torso
	neck.Part1 = head
	neck.C0 = CFrame.new(0, 1.5, 0)
	neck.Parent = torso

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model

	local animator = Instance.new("Animator")
	animator.Parent = humanoid

	model.PrimaryPart = rootPart
	return model
end

local function findAssetInstance(categoryFolder: string, assetName: string): Model?
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		return nil
	end
	local modelsFolder = assetsFolder:FindFirstChild("Models")
	if not modelsFolder then
		return nil
	end
	local subFolder = modelsFolder:FindFirstChild(categoryFolder)
	if not subFolder then
		return nil
	end
	local found = subFolder:FindFirstChild(assetName)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

-- Procedural CAD arsenal fallback (WeaponBuilder). Required lazily because WeaponBuilder itself
-- requires AssetRegistry for its particle textures.
local function tryBuildArsenalModel(assetKey: string, kind: string): Model?
	local sharedFolder = (script.Parent :: Instance).Parent :: Instance
	local weaponsFolder = sharedFolder:FindFirstChild("weapons")
	local builderModule = if weaponsFolder then weaponsFolder:FindFirstChild("WeaponBuilder") else nil
	if not builderModule or not builderModule:IsA("ModuleScript") then
		return nil
	end

	local ok, builder = pcall(require, builderModule)
	if not ok or type(builder) ~= "table" or not builder.HasWeapon(assetKey) then
		return nil
	end

	local template = builder.GetTemplate(assetKey, kind) :: Model?
	if template then
		return template:Clone()
	end
	return nil
end

local AssetRegistry = {
	Audio = Audio,
	UISprites = UISprites,
	Textures = Textures,
	NetworkEvents = NetworkEvents,

	GetViewmodel = function(viewmodelKey: string): Model
		local template = findAssetInstance("Viewmodels", viewmodelKey)
		if template then
			return template:Clone()
		end
		return tryBuildArsenalModel(viewmodelKey, "Viewmodel") or createProceduralViewmodel(viewmodelKey)
	end,

	GetWorldmodel = function(worldmodelKey: string): Model
		local template = findAssetInstance("Worldmodels", worldmodelKey)
		if template then
			return template:Clone()
		end
		return tryBuildArsenalModel(worldmodelKey, "Worldmodel") or createProceduralWorldmodel(worldmodelKey)
	end,

	GetCharacterRig = function(rigKey: string?): Model
		local targetName = rigKey or "CompetitiveR6"
		local template = findAssetInstance("Characters", targetName)
		if template then
			return template:Clone()
		end
		return createProceduralCharacterRig(targetName)
	end,
}

return table.freeze(AssetRegistry)
