--!strict
-- Server-authoritative magazine ammo and reload cooldown tracking

local WeaponData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").configs.WeaponData)

export type PlayerLoadout = {
	WeaponId: string,
	CurrentAmmo: number,
	IsReloading: boolean,
}

local LoadoutService = {}

local playerLoadouts: { [Player]: PlayerLoadout } = {}

function LoadoutService.init(): ()
	-- No-op; players are initialized via initPlayer
end

function LoadoutService.initPlayer(player: Player): ()
	local defaultWeapon: string = "pulse_rifle"
	local stats = WeaponData[defaultWeapon]
	playerLoadouts[player] = {
		WeaponId = defaultWeapon,
		CurrentAmmo = stats.MagazineSize,
		IsReloading = false,
	}
end

function LoadoutService.removePlayer(player: Player): ()
	playerLoadouts[player] = nil
end

function LoadoutService.consumeAmmo(player: Player): boolean
	local loadout: PlayerLoadout? = playerLoadouts[player]
	if not loadout then
		return false
	end
	if loadout.IsReloading then
		return false
	end
	if loadout.CurrentAmmo <= 0 then
		return false
	end
	loadout.CurrentAmmo -= 1
	return true
end

function LoadoutService.startReload(player: Player): ()
	local loadout: PlayerLoadout? = playerLoadouts[player]
	if not loadout then
		return
	end
	if loadout.IsReloading then
		return
	end

	local stats = WeaponData[loadout.WeaponId]
	if not stats then
		return
	end

	loadout.IsReloading = true
	task.delay(stats.ReloadTime, function(): ()
		local currentLoadout: PlayerLoadout? = playerLoadouts[player]
		if currentLoadout and currentLoadout.IsReloading then
			currentLoadout.CurrentAmmo = stats.MagazineSize
			currentLoadout.IsReloading = false
		end
	end)
end

function LoadoutService.getAmmo(player: Player): number
	local loadout: PlayerLoadout? = playerLoadouts[player]
	if not loadout then
		return 0
	end
	return loadout.CurrentAmmo
end

function LoadoutService.getCurrentWeapon(player: Player): string
	local loadout: PlayerLoadout? = playerLoadouts[player]
	if not loadout then
		return "pulse_rifle"
	end
	return loadout.WeaponId
end

return LoadoutService
