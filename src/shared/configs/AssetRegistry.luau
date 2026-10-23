--!strict
--[[
	AssetRegistry.luau
	Centralized read-only registry for audio IDs, UI sprite IDs, VFX prefabs, and 3D models.
	Provides safe procedural dummy fallbacks whenever .rbxm files in ReplicatedStorage.Assets.Models
	or ReplicatedStorage.Graphics.VFXPrefabs are not yet present.
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
		PulseRifle = "rbxassetid://0",
		Railgun = "rbxassetid://0",
		PlasmaShotgun = "rbxassetid://0",
		IonSidearm = "rbxassetid://0",
	}),
})

local NetworkEvents = table.freeze({
	ShotFired = "ShotFired",
	ShotReplicated = "ShotReplicated",
	HitConfirmed = "HitConfirmed",
	StanceChanged = "StanceChanged",
	WeaponEquipped = "WeaponEquipped",
	ReloadRequested = "ReloadRequested",
})

local function createProceduralViewmodel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(0.5, 0.5, 0.5)
	rootPart.Transparency = 1
	rootPart.Anchored = true
	rootPart.CanCollide = false
	rootPart.CanQuery = false
	rootPart.CanTouch = false
	rootPart.Parent = model

	local receiver = Instance.new("Part")
	receiver.Name = "Receiver"
	receiver.Size = Vector3.new(0.35, 0.45, 1.8)
	receiver.Color = Color3.fromRGB(35, 42, 55)
	receiver.Material = Enum.Material.Metal
	receiver.Anchored = false
	receiver.CanCollide = false
	receiver.CanQuery = false
	receiver.CanTouch = false
	receiver.CFrame = rootPart.CFrame * CFrame.new(0.45, -0.4, -1.1)
	receiver.Parent = model

	local barrel = Instance.new("Part")
	barrel.Name = "Muzzle"
	barrel.Size = Vector3.new(0.18, 0.18, 0.8)
	barrel.Color = Color3.fromRGB(0, 220, 255)
	barrel.Material = Enum.Material.Neon
	barrel.Anchored = false
	barrel.CanCollide = false
	barrel.CanQuery = false
	barrel.CanTouch = false
	barrel.CFrame = receiver.CFrame * CFrame.new(0, 0.1, -1.1)
	barrel.Parent = model

	local muzzleAttachment = Instance.new("Attachment")
	muzzleAttachment.Name = "MuzzleAttachment"
	muzzleAttachment.Position = Vector3.new(0, 0, -0.4)
	muzzleAttachment.Parent = barrel

	local rootToReceiver = Instance.new("Motor6D")
	rootToReceiver.Name = "ReceiverJoint"
	rootToReceiver.Part0 = rootPart
	rootToReceiver.Part1 = receiver
	rootToReceiver.C0 = CFrame.new(0.45, -0.4, -1.1)
	rootToReceiver.Parent = rootPart

	local receiverToBarrel = Instance.new("WeldConstraint")
	receiverToBarrel.Part0 = receiver
	receiverToBarrel.Part1 = barrel
	receiverToBarrel.Parent = receiver

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

local AssetRegistry = {
	Audio = Audio,
	UISprites = UISprites,
	NetworkEvents = NetworkEvents,

	GetViewmodel = function(viewmodelKey: string): Model
		local template = findAssetInstance("Viewmodels", viewmodelKey)
		if template then
			return template:Clone()
		end
		return createProceduralViewmodel(viewmodelKey)
	end,

	GetWorldmodel = function(worldmodelKey: string): Model
		local template = findAssetInstance("Worldmodels", worldmodelKey)
		if template then
			return template:Clone()
		end
		return createProceduralWorldmodel(worldmodelKey)
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
