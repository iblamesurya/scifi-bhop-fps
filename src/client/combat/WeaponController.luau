--!strict
-- Input state machine, client raycast, 28-byte buffer sender

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local WeaponData = require(ReplicatedStorage:WaitForChild("Shared").configs.WeaponData)
local ShotPacket = require(ReplicatedStorage:WaitForChild("Shared").network.ShotPacket)

type WeaponState = "Idle" | "Firing" | "Reloading" | "Inspecting"

local WeaponController = {}

local localPlayer: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera
local shotEvent: RemoteEvent = ReplicatedStorage:WaitForChild("ShotEvent") :: RemoteEvent

local currentWeaponId: string = "pulse_rifle"
local currentState: WeaponState = "Idle"
local currentAmmo: number = 30
local lastFireTick: number = 0
local isFiring: boolean = false

-- Public state
WeaponController.IsFiring = false
WeaponController.IsReloading = false
WeaponController.IsADS = false
WeaponController.CurrentAmmo = 30
WeaponController.OnFired = {} :: { (origin: Vector3, direction: Vector3, hitResult: RaycastResult?) -> () }

local rayParams: RaycastParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function WeaponController.init(): ()
	local stats = WeaponData[currentWeaponId]
	currentAmmo = stats.MagazineSize

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean): ()
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isFiring = true
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			WeaponController.IsADS = true
		end
		if input.KeyCode == Enum.KeyCode.R and currentState == "Idle" then
			WeaponController.reload()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, _processed: boolean): ()
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isFiring = false
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			WeaponController.IsADS = false
		end
	end)
end

function WeaponController.update(_dt: number): ()
	if currentState == "Reloading" or currentState == "Inspecting" then
		return
	end

	local stats = WeaponData[currentWeaponId]
	local fireInterval: number = 60 / stats.FireRateRPM

	if isFiring and currentAmmo > 0 then
		local now: number = tick()
		if (now - lastFireTick) >= fireInterval then
			lastFireTick = now
			WeaponController.fireShot(stats)
		end
		currentState = "Firing"
	else
		currentState = "Idle"
	end

	if currentAmmo <= 0 and isFiring then
		WeaponController.reload()
	end

	WeaponController.IsFiring = isFiring and currentAmmo > 0
	WeaponController.CurrentAmmo = currentAmmo
end

function WeaponController.fireShot(stats: WeaponData.WeaponStats): ()
	currentAmmo -= 1

	local character: Model? = localPlayer.Character
	if not character then
		return
	end

	rayParams.FilterDescendantsInstances = { character }
	local origin: Vector3 = camera.CFrame.Position
	local direction: Vector3 = camera.CFrame.LookVector * stats.MaxRange

	-- Client-side raycast for instant visual feedback
	local result: RaycastResult? = workspace:Raycast(origin, direction, rayParams)

	-- Send binary buffer to server
	local camCF: CFrame = camera.CFrame
	local pitch: number = math.asin(-camCF.LookVector.Y)
	local yaw: number = math.atan2(camCF.LookVector.X, -camCF.LookVector.Z)
	local timestamp: number = workspace:GetServerTimeNow()

	local packet: buffer = ShotPacket.write(timestamp, origin, pitch, yaw)
	shotEvent:FireServer(packet)

	-- Notify listeners for VFX/audio
	for _, callback in WeaponController.OnFired do
		task.spawn(callback, origin, direction, result)
	end
end

function WeaponController.reload(): ()
	if currentState == "Reloading" then
		return
	end

	local stats = WeaponData[currentWeaponId]
	if currentAmmo >= stats.MagazineSize then
		return
	end

	currentState = "Reloading"
	WeaponController.IsReloading = true

	task.delay(stats.ReloadTime, function(): ()
		currentAmmo = stats.MagazineSize
		currentState = "Idle"
		WeaponController.IsReloading = false
		WeaponController.CurrentAmmo = currentAmmo
	end)
end

return WeaponController
