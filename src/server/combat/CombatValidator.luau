--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HitboxHistory = require(script.Parent.HitboxHistory)
local ShotPacket = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("network"):WaitForChild("ShotPacket"))
local WeaponData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("configs"):WaitForChild("WeaponData"))

local successLoadout, LoadoutService = pcall(function()
	return require(script.Parent.LoadoutService)
end)

local CombatValidator = {}

local fireEvent: RemoteEvent
local hitConfirmEvent: RemoteEvent
local reloadEvent: RemoteEvent

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

	reloadEvent = ReplicatedStorage:FindFirstChild("ReloadWeaponEvent") :: RemoteEvent
	if not reloadEvent then
		reloadEvent = Instance.new("RemoteEvent")
		reloadEvent.Name = "ReloadWeaponEvent"
		reloadEvent.Parent = ReplicatedStorage
	end

	local function initPlayerWeapons(player: Player)
		local weaponsState = {}
		for weaponName, data in pairs(WeaponData) do
			if type(data) == "table" and (data.MagazineSize or data.magazineSize) then
				weaponsState[weaponName] = {
					ammo = data.MagazineSize or data.magazineSize or 30,
					lastShotTime = 0,
					reloadEndTime = 0,
				}
			end
		end
		playerStates[player] = {
			weapons = weaponsState,
		}
	end

	Players.PlayerAdded:Connect(function(player)
		initPlayerWeapons(player)
		player.CharacterAdded:Connect(function(char)
			local pState = playerStates[player]
			if pState then
				for weaponName, wState in pairs(pState.weapons) do
					local wConfig = WeaponData[weaponName]
					if wConfig and type(wConfig) == "table" then
						wState.ammo = wConfig.MagazineSize or wConfig.magazineSize or 30
					else
						wState.ammo = 30
					end
					wState.reloadEndTime = 0
				end
			else
				initPlayerWeapons(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)

	reloadEvent.OnServerEvent:Connect(function(shooter: Player)
		local pState = playerStates[shooter]
		if not pState then
			return
		end

		local weaponName = "VORTEX_SMG"
		if successLoadout and LoadoutService and type(LoadoutService.getCurrentWeapon) == "function" then
			local current = LoadoutService.getCurrentWeapon(shooter)
			if current then
				weaponName = current
			end
		end
		if not weaponName or weaponName == "" then
			weaponName = shooter:GetAttribute("SelectedWeapon") or "VORTEX_SMG"
		end

		local weaponConfig = nil
		if type(WeaponData.GetWeapon) == "function" then
			weaponConfig = WeaponData.GetWeapon(weaponName)
		end
		if not weaponConfig then
			weaponConfig = WeaponData[weaponName]
		end
		if not weaponConfig then
			return
		end

		local wState = pState.weapons[weaponName]
		if not wState then
			wState = { ammo = weaponConfig.MagazineSize or 30, lastShotTime = 0, reloadEndTime = 0 }
			pState.weapons[weaponName] = wState
		end

		wState.reloadEndTime = Workspace:GetServerTimeNow() + (weaponConfig.ReloadTime or 1.5)
		wState.ammo = weaponConfig.MagazineSize or weaponConfig.magazineSize or 30
	end)

	fireEvent.OnServerEvent:Connect(function(shooter: Player, payload: any)
		if not payload or typeof(payload) ~= "buffer" then
			return
		end

		local success, isValid, timestamp, origin, direction = pcall(function()
			return ShotPacket.Decode(payload)
		end)

		if not success or not isValid or not timestamp or not origin or not direction then
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

		if (origin - head.Position).Magnitude > 14 then
			return
		end

		local weaponName = "VORTEX_SMG"
		if successLoadout and LoadoutService and type(LoadoutService.getCurrentWeapon) == "function" then
			local current = LoadoutService.getCurrentWeapon(shooter)
			if current then
				weaponName = current
			end
		end
		if not weaponName or weaponName == "" then
			weaponName = shooter:GetAttribute("SelectedWeapon") or "VORTEX_SMG"
		end

		local weaponConfig = nil
		if type(WeaponData.GetWeapon) == "function" then
			weaponConfig = WeaponData.GetWeapon(weaponName)
		end
		if not weaponConfig then
			weaponConfig = WeaponData[weaponName]
		end
		if not weaponConfig then
			return
		end

		local pState = playerStates[shooter]
		if not pState then
			return
		end
		local wState = pState.weapons[weaponName]
		if not wState then
			wState = { ammo = weaponConfig.MagazineSize or 30, lastShotTime = 0, reloadEndTime = 0 }
			pState.weapons[weaponName] = wState
		end

		local now = Workspace:GetServerTimeNow()

		if now < wState.reloadEndTime then
			return
		end

		local rpm = weaponConfig.FireRateRPM or weaponConfig.RPM or 600
		local minInterval = 60 / rpm
		if (now - wState.lastShotTime) < (minInterval * 0.8) then
			return
		end

		if wState.ammo <= 0 then
			return
		end

		wState.ammo -= 1
		wState.lastShotTime = now

		local restoreFn = HitboxHistory.RewindToTimestamp(shooter, timestamp)

		local range = weaponConfig.MaxRange or weaponConfig.Range or 1000

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { char }
		raycastParams.IgnoreWater = true

		local rayResult = Workspace:Raycast(origin, direction.Unit * range, raycastParams)

		restoreFn()

		if rayResult and rayResult.Instance then
			local hitPart = rayResult.Instance
			local hitModel = hitPart:FindFirstAncestorOfClass("Model")
			if hitModel then
				local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					local baseDamage = weaponConfig.BaseDamage or weaponConfig.Damage or 22
					local damage = baseDamage
					if hitPart.Name == "Head" then
						damage *= (weaponConfig.HeadshotMultiplier or 2.0)
					end

					local healthBefore = humanoid.Health
					humanoid:TakeDamage(damage)
					if healthBefore > 0 and humanoid.Health <= 0 then
						local currentKills = (shooter:GetAttribute("Kills") :: number?) or 0
						shooter:SetAttribute("Kills", currentKills + 1)
					end

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
