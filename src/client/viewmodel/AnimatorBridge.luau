--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type TrackName = "Idle" | "Equip" | "Reload"

type AnimEntry = {
	Id: string,
	Priority: Enum.AnimationPriority,
	FadeTime: number,
	Speed: number,
}

type WeaponAnimSet = {
	Idle: AnimEntry,
	Equip: AnimEntry,
	Reload: AnimEntry,
	[string]: AnimEntry,
}

local FALLBACK_VIEWMODEL_ANIMS: { [string]: WeaponAnimSet } = table.freeze({
	VORTEX_SMG = table.freeze({
		Idle = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Idle,
			FadeTime = 0.15,
			Speed = 1.0,
		}),
		Equip = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.08,
			Speed = 1.25,
		}),
		Reload = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action2,
			FadeTime = 0.12,
			Speed = 1.0,
		}),
	}),
	HELIOS_RAIL = table.freeze({
		Idle = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Idle,
			FadeTime = 0.18,
			Speed = 0.9,
		}),
		Equip = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.12,
			Speed = 0.95,
		}),
		Reload = table.freeze({
			Id = "rbxassetid://0",
			Priority = Enum.AnimationPriority.Action2,
			FadeTime = 0.15,
			Speed = 0.85,
		}),
	}),
})

local function resolveViewmodelAnims(): { [string]: WeaponAnimSet }
	local animsFolder = ReplicatedStorage:FindFirstChild("Animations")
		or ReplicatedStorage:FindFirstChild("AnimationRegistry")
	if animsFolder then
		local vmModule = if animsFolder:IsA("ModuleScript")
			then animsFolder:FindFirstChild("ViewmodelAnims") or animsFolder
			else animsFolder:FindFirstChild("ViewmodelAnims", true)
		if vmModule and vmModule:IsA("ModuleScript") then
			local ok, result = pcall(require, vmModule)
			if ok and type(result) == "table" then
				if result.ViewmodelAnims then
					return result.ViewmodelAnims :: { [string]: WeaponAnimSet }
				end
				return result :: { [string]: WeaponAnimSet }
			end
		end
	end
	return FALLBACK_VIEWMODEL_ANIMS
end

local ViewmodelAnims = resolveViewmodelAnims()

local AnimatorBridge = {}

local currentAnimator: Animator? = nil
local currentWeaponId: string? = nil
local loadedTracks: { [string]: AnimationTrack } = {}
local trackConfigs: { [string]: AnimEntry } = {}
local animInstances: { Animation } = {}

local function getOrCreateAnimator(viewmodel: Model): Animator
	local existingAnimator = viewmodel:FindFirstChildWhichIsA("Animator", true)
	if existingAnimator then
		return existingAnimator
	end

	local controller = viewmodel:FindFirstChildWhichIsA("AnimationController")
	if not controller then
		local newController = Instance.new("AnimationController")
		newController.Name = "AnimationController"
		newController.Parent = viewmodel
		controller = newController
	end

	local animator = Instance.new("Animator")
	animator.Name = "Animator"
	animator.Parent = controller
	return animator
end

local function isUsableAssetId(assetId: string): boolean
	return assetId ~= "" and assetId ~= "rbxassetid://0" and assetId ~= "0"
end

function AnimatorBridge.StopAll()
	for _, track in loadedTracks do
		if track.IsPlaying then
			pcall(function()
				track:Stop(0.1)
			end)
		end
		pcall(function()
			track:Destroy()
		end)
	end
	table.clear(loadedTracks)
	table.clear(trackConfigs)

	for _, anim in animInstances do
		anim:Destroy()
	end
	table.clear(animInstances)
end

function AnimatorBridge.BindRig(viewmodel: Model, weaponId: string)
	AnimatorBridge.StopAll()

	currentWeaponId = weaponId
	local animator = getOrCreateAnimator(viewmodel)
	currentAnimator = animator

	local animSet = ViewmodelAnims[weaponId] or ViewmodelAnims.VORTEX_SMG
	if not animSet then
		return
	end

	local trackNames: { TrackName } = { "Idle", "Equip", "Reload" }
	for _, name in trackNames do
		local entry = animSet[name]
		if entry then
			trackConfigs[name] = entry
			if isUsableAssetId(entry.Id) then
				local anim = Instance.new("Animation")
				anim.Name = `{weaponId}_{name}`
				anim.AnimationId = entry.Id
				table.insert(animInstances, anim)

				local ok, trackOrErr = pcall(function()
					return animator:LoadAnimation(anim)
				end)
				if ok and trackOrErr then
					trackOrErr.Priority = entry.Priority
					trackOrErr.Looped = (name == "Idle")
					loadedTracks[name] = trackOrErr
				end
			end
		end
	end
end

function AnimatorBridge.PlayTrack(trackName: TrackName)
	local config = trackConfigs[trackName]
	local track = loadedTracks[trackName]
	if not track or not config then
		return
	end

	if trackName ~= "Idle" then
		for name, otherTrack in loadedTracks do
			if name ~= "Idle" and name ~= trackName and otherTrack.IsPlaying then
				pcall(function()
					otherTrack:Stop(config.FadeTime)
				end)
			end
		end
	end

	pcall(function()
		track.Priority = config.Priority
		track:Play(config.FadeTime, 1.0, config.Speed)
	end)
end

return table.freeze(AnimatorBridge)
