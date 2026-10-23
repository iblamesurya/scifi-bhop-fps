--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponData = require(Shared:WaitForChild("configs"):WaitForChild("WeaponData"))
local ShotPacket = require(Shared:WaitForChild("network"):WaitForChild("ShotPacket"))

local TracerPool = require(script.Parent:WaitForChild("TracerPool"))
local ViewmodelController = require(script.Parent.Parent:WaitForChild("viewmodel"):WaitForChild("ViewmodelController"))

local LOCAL_PLAYER = Players.LocalPlayer
local DEFAULT_WEAPON_ID = "VORTEX_SMG"

type WeaponStats = {
	Id: string?,
	WeaponId: number?,
	MaxAmmo: number?,
	MagazineSize: number?,
	ReloadTime: number?,
	FireRate: number?,
	FireInterval: number?,
	Automatic: boolean?,
	MaxRange: number?,
	Range: number?,
	RecoilKick: Vector3?,
	IsOverdrive: boolean?,
}

local FALLBACK_WEAPON_STATS: { [string]: WeaponStats } = {
	VORTEX_SMG = {
		Id = "VORTEX_SMG",
		WeaponId = 1,
		MaxAmmo = 30,
		MagazineSize = 30,
		ReloadTime = 1.35,
		FireRate = 12,
		Automatic = true,
		MaxRange = 600,
		RecoilKick = Vector3.new(0.04, 0.01, 0.18),
		IsOverdrive = false,
	},
	HELIOS_RAIL = {
		Id = "HELIOS_RAIL",
		WeaponId = 2,
		MaxAmmo = 5,
		MagazineSize = 5,
		ReloadTime = 2.1,
		FireRate = 0.85,
		Automatic = false,
		MaxRange = 1200,
		RecoilKick = Vector3.new(0.16, 0.03, 0.55),
		IsOverdrive = true,
	},
}

local WeaponController = {
	CurrentWeaponId = DEFAULT_WEAPON_ID,
	CurrentAmmo = 30,
	MaxAmmo = 30,
	IsReloading = false,
	OnHitConfirmed = {} :: { (isHeadshot: boolean) -> () },
	OnWeaponFired = {} :: { () -> () },
}

local isInitialized = false
local isTriggerHeld = false
local lastFireTimestamp = 0
local reloadStateToken = 0
local fireWeaponRemote: Instance? = nil

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local filterInstances: { Instance } = table.create(4)

local function getWeaponStats(weaponId: string): WeaponStats
	local dataTable = WeaponData :: any
	if type(dataTable) == "table" then
		if type(dataTable.GetWeapon) == "function" then
			local result = dataTable.GetWeapon(weaponId)
			if result then
				return result
			end
		end
		if type(dataTable.Weapons) == "table" and dataTable.Weapons[weaponId] then
			return dataTable.Weapons[weaponId]
		end
		if dataTable[weaponId] then
			return dataTable[weaponId]
		end
	end

	return FALLBACK_WEAPON_STATS[weaponId] or FALLBACK_WEAPON_STATS[DEFAULT_WEAPON_ID]
end

local function getMaxAmmo(stats: WeaponStats): number
	return stats.MaxAmmo or stats.MagazineSize or 30
end

local function getReloadTime(stats: WeaponStats): number
	return stats.ReloadTime or 1.5
end

local function getMaxRange(stats: WeaponStats): number
	return stats.MaxRange or stats.Range or 800
end

local function getFireInterval(stats: WeaponStats): number
	if stats.FireInterval and stats.FireInterval > 0 then
		return stats.FireInterval
	end

	local fireRate = stats.FireRate
	if fireRate and fireRate > 0 then
		if fireRate > 40 then
			return 60 / fireRate
		end
		return 1 / fireRate
	end

	return 0.1
end

local function isWeaponAutomatic(weaponId: string, stats: WeaponStats): boolean
	if stats.Automatic ~= nil then
		return stats.Automatic
	end
	return weaponId == "VORTEX_SMG"
end

local function getNumericWeaponId(weaponId: string, stats: WeaponStats): number
	if stats.WeaponId then
		return stats.WeaponId
	end
	return if weaponId == "HELIOS_RAIL" then 2 else 1
end

local function fireWeaponListeners()
	for i = 1, #WeaponController.OnWeaponFired do
		local callback = WeaponController.OnWeaponFired[i]
		if callback then
			callback()
		end
	end
end

local function fireHitListeners(isHeadshot: boolean)
	for i = 1, #WeaponController.OnHitConfirmed do
		local callback = WeaponController.OnHitConfirmed[i]
		if callback then
			callback(isHeadshot)
		end
	end
end

local function evaluateHitResult(rayResult: RaycastResult?): (boolean, boolean)
	if not rayResult or not rayResult.Instance then
		return false, false
	end

	local hitPart = rayResult.Instance
	local model = hitPart:FindFirstAncestorOfClass("Model")
	if not model then
		return false, false
	end

	if LOCAL_PLAYER and model == LOCAL_PLAYER.Character then
		return false, false
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hasHitboxTag = hitPart:GetAttribute("IsHitbox") == true or model:GetAttribute("IsTarget") == true
	if not humanoid and not hasHitboxTag then
		return false, false
	end

	if humanoid and humanoid.Health <= 0 then
		return false, false
	end

	local partName = string.lower(hitPart.Name)
	local isHeadshot = partName == "head" or string.find(partName, "head", 1, true) ~= nil
	return true, isHeadshot
end

local function encodeShotBuffer(
	origin: Vector3,
	direction: Vector3,
	hitPosition: Vector3,
	timestamp: number,
	weaponId: string,
	numericWeaponId: number
): buffer
	local encodeFn = (ShotPacket :: any).Encode
	local arity = debug.info(encodeFn, "a")

	if arity == 1 then
		return encodeFn({
			Origin = origin,
			Direction = direction,
			HitPosition = hitPosition,
			Timestamp = timestamp,
			ClientTimestamp = timestamp,
			WeaponId = numericWeaponId,
			WeaponName = weaponId,
			origin = origin,
			direction = direction,
			hitPosition = hitPosition,
			timestamp = timestamp,
			clientTimestamp = timestamp,
			weaponId = numericWeaponId,
		})
	end

	local ok, encoded = pcall(encodeFn, origin, direction, timestamp, numericWeaponId)
	if ok and type(encoded) == "buffer" then
		return encoded
	end

	return encodeFn({
		Origin = origin,
		Direction = direction,
		HitPosition = hitPosition,
		Timestamp = timestamp,
		WeaponId = numericWeaponId,
	})
end

local function sendShotBuffer(packetBuffer: buffer)
	local remote = fireWeaponRemote
	if not remote then
		return
	end

	if remote:IsA("RemoteEvent") then
		remote:FireServer(packetBuffer)
	elseif remote:IsA("UnreliableRemoteEvent") then
		remote:FireServer(packetBuffer)
	end
end

local function startReload()
	if WeaponController.IsReloading then
		return
	end

	if WeaponController.CurrentAmmo >= WeaponController.MaxAmmo then
		return
	end

	local stats = getWeaponStats(WeaponController.CurrentWeaponId)
	local reloadDuration = getReloadTime(stats)

	WeaponController.IsReloading = true
	reloadStateToken += 1
	local activeToken = reloadStateToken

	task.delay(reloadDuration, function()
		if reloadStateToken ~= activeToken or not WeaponController.IsReloading then
			return
		end

		WeaponController.CurrentAmmo = WeaponController.MaxAmmo
		WeaponController.IsReloading = false
	end)
end

local function attemptFire()
	if WeaponController.IsReloading then
		return
	end

	if WeaponController.CurrentAmmo <= 0 then
		startReload()
		return
	end

	local weaponId = WeaponController.CurrentWeaponId
	local stats = getWeaponStats(weaponId)
	local fireInterval = getFireInterval(stats)

	local now = os.clock()
	if now - lastFireTimestamp < fireInterval then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	lastFireTimestamp = now
	WeaponController.CurrentAmmo = math.max(0, WeaponController.CurrentAmmo - 1)

	-- Update zero-allocation exclusion table for client-predicted raycast
	table.clear(filterInstances)
	if LOCAL_PLAYER and LOCAL_PLAYER.Character then
		table.insert(filterInstances, LOCAL_PLAYER.Character)
	end
	table.insert(filterInstances, camera)
	raycastParams.FilterDescendantsInstances = filterInstances

	local cameraCFrame = camera.CFrame
	local rayOrigin = cameraCFrame.Position
	local aimDirection = cameraCFrame.LookVector
	local maxRange = getMaxRange(stats)

	local rayResult = workspace:Raycast(rayOrigin, aimDirection * maxRange, raycastParams)
	local endPos = if rayResult then rayResult.Position else (rayOrigin + aimDirection * maxRange)

	local muzzlePos = rayOrigin
	if type((ViewmodelController :: any).GetMuzzleWorldPosition) == "function" then
		local resolvedMuzzle = ViewmodelController.GetMuzzleWorldPosition()
		if typeof(resolvedMuzzle) == "Vector3" then
			muzzlePos = resolvedMuzzle
		end
	end

	local isOverdrive = stats.IsOverdrive == true or weaponId == "HELIOS_RAIL"
	TracerPool.SpawnTracer(muzzlePos, endPos, isOverdrive)

	local recoilKick = stats.RecoilKick or Vector3.new(0.05, 0, 0.2)
	if type((ViewmodelController :: any).ApplyRecoilImpulse) == "function" then
		ViewmodelController.ApplyRecoilImpulse(recoilKick)
	end

	local netTimestamp = workspace:GetServerTimeNow()
	local numericWeaponId = getNumericWeaponId(weaponId, stats)
	local packetBuffer = encodeShotBuffer(
		rayOrigin,
		aimDirection,
		endPos,
		netTimestamp,
		weaponId,
		numericWeaponId
	)
	sendShotBuffer(packetBuffer)

	fireWeaponListeners()

	local didHitTarget, isHeadshot = evaluateHitResult(rayResult)
	if didHitTarget then
		fireHitListeners(isHeadshot)
	end

	if WeaponController.CurrentAmmo <= 0 then
		startReload()
	end
end

function WeaponController.SwitchWeapon(weaponId: string)
	if weaponId ~= "VORTEX_SMG" and weaponId ~= "HELIOS_RAIL" then
		local dataTable = WeaponData :: any
		if type(dataTable) ~= "table" or (not dataTable[weaponId] and not (dataTable.Weapons and dataTable.Weapons[weaponId])) then
			return
		end
	end

	reloadStateToken += 1
	WeaponController.IsReloading = false
	WeaponController.CurrentWeaponId = weaponId

	local stats = getWeaponStats(weaponId)
	local maxAmmo = getMaxAmmo(stats)
	WeaponController.MaxAmmo = maxAmmo
	WeaponController.CurrentAmmo = maxAmmo
	lastFireTimestamp = 0

	local vmController = ViewmodelController :: any
	if type(vmController.EquipWeapon) == "function" then
		vmController.EquipWeapon(weaponId)
	elseif type(vmController.SwitchWeapon) == "function" then
		vmController.SwitchWeapon(weaponId)
	elseif type(vmController.SetWeapon) == "function" then
		vmController.SetWeapon(weaponId)
	end
end

function WeaponController.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	TracerPool.Init()
	fireWeaponRemote = ReplicatedStorage:WaitForChild("FireWeaponBuffer")

	local hitConfirmRemote = ReplicatedStorage:FindFirstChild("HitConfirmed")
	if hitConfirmRemote and hitConfirmRemote:IsA("RemoteEvent") then
		hitConfirmRemote.OnClientEvent:Connect(function(isHeadshot: boolean)
			fireHitListeners(isHeadshot == true)
		end)
	end

	WeaponController.SwitchWeapon(DEFAULT_WEAPON_ID)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isTriggerHeld = true
			attemptFire()
		elseif input.KeyCode == Enum.KeyCode.One then
			WeaponController.SwitchWeapon("VORTEX_SMG")
		elseif input.KeyCode == Enum.KeyCode.Two then
			WeaponController.SwitchWeapon("HELIOS_RAIL")
		elseif input.KeyCode == Enum.KeyCode.R then
			startReload()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isTriggerHeld = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not isTriggerHeld then
			return
		end

		local weaponId = WeaponController.CurrentWeaponId
		local stats = getWeaponStats(weaponId)
		if isWeaponAutomatic(weaponId, stats) then
			attemptFire()
		end
	end)
end

return WeaponController