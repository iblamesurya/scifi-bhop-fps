--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HitboxHistory = require(script.Parent.HitboxHistory)
local ShotPacket = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("network"):WaitForChild("ShotPacket"))
local WeaponData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("configs"):WaitForChild("WeaponData"))

local CombatValidator = {}

local fireEvent: RemoteEvent
local hitConfirmEvent: RemoteEvent

type WeaponState = {
	ammo: number,
	lastShotTime: number,
	reloadEndTime: number,
}

type PlayerCombatState = {
	weapons: { [string]: WeaponState },
}

local playerStates: { [Player]: PlayerCombatState } = {}

function CombatValidator.Init()
	fireEvent = ReplicatedStorage:FindFirstChild("FireWeaponBuffer") :: RemoteEvent
	if not fireEvent then
		fireEvent = Instance.new("RemoteEvent")
		fireEvent.Name = "FireWeaponBuffer"
		fireEvent.Parent = ReplicatedStorage
	end

	hitConfirmEvent = ReplicatedStorage:FindFirstChild("HitConfirmEvent") :: RemoteEvent
	if not hitConfirmEvent then
		hitConfirmEvent = Instance.new("RemoteEvent")
		hitConfirmEvent.Name = "HitConfirmEvent"
		hitConfirmEvent.Parent = ReplicatedStorage
	end

	Players.PlayerAdded:Connect(function(player)
		local weaponsState = {}
		for weaponName, data in pairs(WeaponData) do
			if type(data) == "table" and data.MagazineSize then
				weaponsState[weaponName] = {
					ammo = data.MagazineSize,
					lastShotTime = 0,
					reloadEndTime = 0,
				}
			end
		end
		playerStates[player] = {
			weapons = weaponsState,
		}
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)

	fireEvent.OnServerEvent:Connect(function(shooter: Player, payload: any)
		if not payload or typeof(payload) ~= "buffer" then
			return
		end

		local success, packet = pcall(function()
			return ShotPacket.Decode(payload)
		end)

		if not success or not packet then
			return
		end

		local char = shooter.Character
		if not char then
			return
		end
		local head = char:FindFirstChild("Head")
		if not head or not head:IsA("BasePart") then
			return
		end

		-- Verify origin is within 14 studs of shooterHead.Position
		local origin = packet.origin or packet.Origin
		if not origin then
			return
		end
		if (origin - head.Position).Magnitude > 14 then
			return
		end

		local weaponName = packet.weaponName or packet.WeaponName or "AssaultRifle"
		local weaponConfig = WeaponData[weaponName]
		if not weaponConfig then
			return
		end

		local pState = playerStates[shooter]
		if not pState then
			return
		end
		local wState = pState.weapons[weaponName]
		if not wState then
			return
		end

		local now = Workspace:GetServerTimeNow()

		-- Check reload status
		if now < wState.reloadEndTime then
			return
		end

		-- Check RPM interval
		local rpm = weaponConfig.RPM or 600
		local minInterval = 60 / rpm
		if (now - wState.lastShotTime) < (minInterval * 0.8) then
			return
		end

		-- Check ammo
		if wState.ammo <= 0 then
			return
		end

		wState.ammo -= 1
		wState.lastShotTime = now

		-- Rewind hitboxes to target timestamp
		local targetTimestamp = packet.timestamp or packet.Timestamp or now
		local restoreFn = HitboxHistory.RewindToTimestamp(shooter, targetTimestamp)

		-- Execute server raycast
		local direction = packet.direction or packet.Direction
		local range = weaponConfig.Range or 10000
		if not direction then
			restoreFn()
			return
		end

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { char }
		raycastParams.IgnoreWater = true

		local rayResult = Workspace:Raycast(origin, direction.Unit * range, raycastParams)

		-- Restore hitboxes immediately
		restoreFn()

		-- Apply damage and confirm hit
		if rayResult and rayResult.Instance then
			local hitPart = rayResult.Instance
			local hitModel = hitPart:FindFirstAncestorOfClass("Model")
			if hitModel then
				local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					local damage = weaponConfig.Damage or 25
					if hitPart.Name == "Head" then
						damage *= (weaponConfig.HeadshotMultiplier or 2.0)
					end

					humanoid:TakeDamage(damage)

					hitConfirmEvent:FireClient(shooter, {
						hitPosition = rayResult.Position,
						hitPart = hitPart,
						isHeadshot = (hitPart.Name == "Head"),
						damage = damage,
					})
				end
			end
		end
	end)
end

return CombatValidator