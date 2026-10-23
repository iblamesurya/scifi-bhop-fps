--!strict
-- AnimationTrack loader for viewmodel Motor6Ds

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationRegistry = require(ReplicatedStorage:WaitForChild("Animations"))

local AnimatorBridge = {}

local animationController: AnimationController? = nil
local loadedTracks: { [string]: AnimationTrack } = {}
local currentWeaponId: string = ""

function AnimatorBridge.loadAnimations(viewmodel: Model, weaponId: string): ()
	-- Clean up old controller
	if animationController then
		for _, track: AnimationTrack in loadedTracks do
			track:Stop(0)
			track:Destroy()
		end
		table.clear(loadedTracks)
		animationController:Destroy()
	end

	currentWeaponId = weaponId

	-- Create AnimationController on the viewmodel
	local controller: AnimationController = Instance.new("AnimationController")
	controller.Parent = viewmodel
	animationController = controller

	-- Load tracks from registry
	local animNames: { string } = { "Idle", "Equip", "Fire", "Reload", "Inspect" }
	for _, animName: string in animNames do
		local animData = AnimationRegistry.getViewmodelAnim(weaponId, animName)
		if animData.Id == "rbxassetid://0" then
			continue
		end
		local animation: Animation = Instance.new("Animation")
		animation.AnimationId = animData.Id
		local track: AnimationTrack = controller:LoadAnimation(animation)
		track.Priority = animData.Priority
		track.Looped = animData.Looped
		loadedTracks[animName] = track
	end
end

function AnimatorBridge.play(trackName: string, fadeTime: number?): ()
	local track: AnimationTrack? = loadedTracks[trackName]
	if track then
		local animData = AnimationRegistry.getViewmodelAnim(currentWeaponId, trackName)
		track:Play(fadeTime or animData.FadeTime)
	end
end

function AnimatorBridge.stop(trackName: string, fadeTime: number?): ()
	local track: AnimationTrack? = loadedTracks[trackName]
	if track then
		track:Stop(fadeTime or 0.1)
	end
end

function AnimatorBridge.stopAll(fadeTime: number?): ()
	for _, track: AnimationTrack in loadedTracks do
		track:Stop(fadeTime or 0.1)
	end
end

function AnimatorBridge.isPlaying(trackName: string): boolean
	local track: AnimationTrack? = loadedTracks[trackName]
	if track then
		return track.IsPlaying
	end
	return false
end

return AnimatorBridge
