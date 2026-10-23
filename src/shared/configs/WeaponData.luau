--!strict
-- Read-only weapon stats: RPM, damage, headshot mult, recoil kick

export type WeaponStats = {
	Name: string,
	FireRateRPM: number,
	Damage: number,
	HeadshotMultiplier: number,
	MaxRange: number,
	MagazineSize: number,
	ReloadTime: number,
	RecoilKick: Vector3,
	SpreadBase: number,
	SpreadMoving: number,
	TracerSpeed: number,
	PelletCount: number,
}

export type WeaponDataType = { [string]: WeaponStats }

local WeaponData: WeaponDataType = table.freeze({
	pulse_rifle = table.freeze({
		Name = "Pulse Rifle",
		FireRateRPM = 600,
		Damage = 22,
		HeadshotMultiplier = 2.5,
		MaxRange = 500,
		MagazineSize = 30,
		ReloadTime = 2.2,
		RecoilKick = Vector3.new(1.8, 0.4, 0.3),
		SpreadBase = 0.015,
		SpreadMoving = 0.035,
		TracerSpeed = 800,
		PelletCount = 1,
	}),
	scatter_blaster = table.freeze({
		Name = "Scatter Blaster",
		FireRateRPM = 90,
		Damage = 9,
		HeadshotMultiplier = 1.5,
		MaxRange = 120,
		MagazineSize = 6,
		ReloadTime = 2.8,
		RecoilKick = Vector3.new(4.5, 1.2, 1.0),
		SpreadBase = 0.08,
		SpreadMoving = 0.12,
		TracerSpeed = 600,
		PelletCount = 8,
	}),
})

return WeaponData
