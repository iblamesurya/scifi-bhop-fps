--!strict
-- Unpacks 28B shot buffer, rewinds hitboxes, validates, and applies damage

local Players = game:GetService("Players")

local ShotPacket = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").network.ShotPacket)
local WeaponData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").configs.WeaponData)
local HitboxHistory = require(script.Parent.HitboxHistory)
local LoadoutService = require(script.Parent.LoadoutService)

local CombatValidator = {}

local lastFireTime: { [Player]: number } = {}
local MAX_ORIGIN_TOLERANCE: number = 14
local MAX_REWIND_TIME: number = 0.45

local rayParams: RaycastParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function CombatValidator.init(shotEvent: RemoteEvent): ()
	shotEvent.OnServerEvent:Connect(function(player: Player, packet: any): ()
		CombatValidator.processShot(player, packet)
	end)

	Players.PlayerRemoving:Connect(function(player: Player): ()
		lastFireTime[player] = nil
	end)
end

function CombatValidator.processShot(player: Player, packet: any): ()
	-- 1) Verify buffer type and length
	if typeof(packet) ~= "buffer" or buffer.len(packet) ~= 28 then
		return
	end

	local character: Model? = player.Character
	if not character then
		return
	end

	local head: BasePart? = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	-- Decode packet
	local shotData = ShotPacket.read(packet)
	local serverNow: number = workspace:GetServerTimeNow()

	-- Get weapon stats
	local weaponId: string = LoadoutService.getCurrentWeapon(player)
	local stats = WeaponData[weaponId]
	if not stats then
		return
	end

	-- 2) Rate-of-fire check
	local minInterval: number = (60 / stats.FireRateRPM) * 0.88
	local lastTime: number? = lastFireTime[player]
	if lastTime and (serverNow - lastTime) < minInterval then
		return
	end
	lastFireTime[player] = serverNow

	-- 3) Consume ammo server-side
	if not LoadoutService.consumeAmmo(player) then
		return
	end

	-- 4) Origin distance validation
	local originDist: number = (shotData.Origin - head.Position).Magnitude
	if originDist > MAX_ORIGIN_TOLERANCE then
		return
	end

	-- 5) Clamp rewind time
	local rewindTime: number = math.clamp(shotData.Timestamp, serverNow - MAX_REWIND_TIME, serverNow)

	-- 6) Get historical snapshot
	local snapshot = HitboxHistory.getSnapshot(rewindTime)
	if not snapshot then
		return
	end

	-- Build ray direction from pitch/yaw
	local direction: Vector3 = CFrame.fromOrientation(shotData.Pitch, shotData.Yaw, 0).LookVector * stats.MaxRange

	-- 7) Rewind all enemy hitboxes, raycast, restore
	rayParams.FilterDescendantsInstances = { character }

	-- Rewind enemies
	for _, otherPlayer: Player in Players:GetPlayers() do
		if otherPlayer ~= player and otherPlayer.Character then
			HitboxHistory.rewindPlayer(otherPlayer, snapshot)
		end
	end

	-- Perform raycast
	local result: RaycastResult? = workspace:Raycast(shotData.Origin, direction, rayParams)

	-- Restore enemies
	for _, otherPlayer: Player in Players:GetPlayers() do
		if otherPlayer ~= player then
			HitboxHistory.restorePlayer(otherPlayer)
		end
	end

	-- 8) Apply damage if hit
	if result and result.Instance then
		local hitCharacter: Model? = result.Instance:FindFirstAncestorOfClass("Model")
		if hitCharacter then
			local humanoid: Humanoid? = hitCharacter:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local damage: number = stats.Damage * stats.PelletCount
				if result.Instance.Name == "Head" then
					damage *= stats.HeadshotMultiplier
				end
				humanoid:TakeDamage(damage)
			end
		end
	end
end

return CombatValidator
