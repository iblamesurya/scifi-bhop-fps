--!strict
-- src/shared/configs/EconomyConfig.luau
-- Pillar 4: Shared read-only configuration for the Kinetic Match & Progression Economy.
-- Zero hardcoded rbxassetid:// strings; all audio and sprite references map to AssetRegistry keys.

export type ItemCategory = "Primary" | "Secondary" | "Armor" | "Utility"

export type EconomyItemDefinition = {
	Id: number, -- u8 (1..255) for binary buffer serialization
	CodeKey: string, -- Matches WeaponData / AssetRegistry lookup key
	DisplayName: string,
	Category: ItemCategory,
	Cost: number, -- Tactical Match Credits
	PermanentUnlockFluxCost: number, -- Persistent Account Flux Shards (0 = unlocked by default)
	KillAwardMultiplier: number, -- Multiplier applied to base kill reward (e.g., 1.5x for SMGs)
	ArmorPoints: number?, -- Only for Category == "Armor"
	UtilityBitIndex: number?, -- 0..7 bit index for Category == "Utility"
	AssetIconKey: string, -- Key in src/shared/configs/AssetRegistry.luau
	Description: string,
}

export type ReasonCodeType = {
	RoundStart: number,
	KillStandard: number,
	KillOverdrive: number,
	KillHyperdrive: number,
	Assist: number,
	PurchaseSuccess: number,
	PurchaseDenied: number,
	SellRefund: number,
	RoundWin: number,
	RoundLoss: number,
	ObjectiveBonus: number,
}

export type ActionTypeMap = {
	BuyItem: number,
	SellRefundItem: number,
	RequestFullSync: number,
	UnlockPermanentItem: number,
}

local ActionTypes: ActionTypeMap = table.freeze({
	BuyItem = 1,
	SellRefundItem = 2,
	RequestFullSync = 3,
	UnlockPermanentItem = 4,
})

local ReasonCodes: ReasonCodeType = table.freeze({
	RoundStart = 1,
	KillStandard = 2,
	KillOverdrive = 3,
	KillHyperdrive = 4,
	Assist = 5,
	PurchaseSuccess = 6,
	PurchaseDenied = 7,
	SellRefund = 8,
	RoundWin = 9,
	RoundLoss = 10,
	ObjectiveBonus = 11,
})

local ItemsList: { EconomyItemDefinition } = {
	-- SECONDARIES (u8 IDs: 1..9)
	{
		Id = 1,
		CodeKey = "wpn_pulse_pistol",
		DisplayName = "K-14 Pulse Pistol",
		Category = "Secondary",
		Cost = 0,
		PermanentUnlockFluxCost = 0,
		KillAwardMultiplier = 1.0,
		AssetIconKey = "Sprite_Wpn_PulsePistol",
		Description = "Standard-issue semi-automatic energy sidearm with zero movement penalty.",
	},
	{
		Id = 2,
		CodeKey = "wpn_burst_machine_pistol",
		DisplayName = "Tachyon Auto-9",
		Category = "Secondary",
		Cost = 500,
		PermanentUnlockFluxCost = 400,
		KillAwardMultiplier = 1.0,
		AssetIconKey = "Sprite_Wpn_TachyonAuto9",
		Description = "High-cadence 3-round burst machine pistol built for close-range air-strafing.",
	},
	{
		Id = 3,
		CodeKey = "wpn_ion_revolver",
		DisplayName = "V8 Ion Handcannon",
		Category = "Secondary",
		Cost = 800,
		PermanentUnlockFluxCost = 750,
		KillAwardMultiplier = 1.0,
		AssetIconKey = "Sprite_Wpn_IonRevolver",
		Description = "Heavy precision sidearm capable of 1-tap headshot eliminations at medium range.",
	},

	-- PRIMARIES: SMGS & SHOTGUNS (u8 IDs: 10..19)
	{
		Id = 10,
		CodeKey = "wpn_vector_smg",
		DisplayName = "VX-9 Kinetic SMG",
		Category = "Primary",
		Cost = 1450,
		PermanentUnlockFluxCost = 0,
		KillAwardMultiplier = 1.5,
		AssetIconKey = "Sprite_Wpn_VectorSMG",
		Description = "1000 RPM submachine gun with tight hipfire spread during bunny-hop chains.",
	},
	{
		Id = 11,
		CodeKey = "wpn_scatter_shotgun",
		DisplayName = "Arc Flak Shotgun",
		Category = "Primary",
		Cost = 1750,
		PermanentUnlockFluxCost = 900,
		KillAwardMultiplier = 1.5,
		AssetIconKey = "Sprite_Wpn_ScatterShotgun",
		Description = "ionized pellet scattergun optimized for high-velocity slide-hop entry picks.",
	},

	-- PRIMARIES: RIFLES (u8 IDs: 20..29)
	{
		Id = 20,
		CodeKey = "wpn_cobalt_carbine",
		DisplayName = "M4A-Cobalt Carbine",
		Category = "Primary",
		Cost = 2700,
		PermanentUnlockFluxCost = 0,
		KillAwardMultiplier = 1.0,
		AssetIconKey = "Sprite_Wpn_CobaltCarbine",
		Description = "Low-recoil suppressed plasma carbine with rapid spring recovery.",
	},
	{
		Id = 21,
		CodeKey = "wpn_vandal_rail_rifle",
		DisplayName = "HV-77 Rail Rifle",
		Category = "Primary",
		Cost = 2900,
		PermanentUnlockFluxCost = 1200,
		KillAwardMultiplier = 1.0,
		AssetIconKey = "Sprite_Wpn_VandalRailRifle",
		Description = "High-caliber electromagnetic rifle with lethal headshot damage at any distance.",
	},

	-- PRIMARIES: SNIPERS (u8 IDs: 30..39)
	{
		Id = 30,
		CodeKey = "wpn_helix_sniper",
		DisplayName = "Helix Linear Railgun",
		Category = "Primary",
		Cost = 4700,
		PermanentUnlockFluxCost = 2500,
		KillAwardMultiplier = 0.5,
		AssetIconKey = "Sprite_Wpn_HelixSniper",
		Description = "Instantaneous hitscan railgun that rewards high-risk investment.",
	},

	-- EXO-ARMOR (u8 IDs: 40..49)
	{
		Id = 40,
		CodeKey = "armor_light_exo",
		DisplayName = "Light Exo-Shield (+25 AP)",
		Category = "Armor",
		Cost = 400,
		PermanentUnlockFluxCost = 0,
		KillAwardMultiplier = 1.0,
		ArmorPoints = 25,
		AssetIconKey = "Sprite_Armor_LightExo",
		Description = "Absorbs 66% of incoming kinetic damage up to 25 shield capacity.",
	},
	{
		Id = 41,
		CodeKey = "armor_heavy_exo",
		DisplayName = "Overdrive Exo-Shield (+50 AP)",
		Category = "Armor",
		Cost = 1000,
		PermanentUnlockFluxCost = 0,
		KillAwardMultiplier = 1.0,
		ArmorPoints = 50,
		AssetIconKey = "Sprite_Armor_HeavyExo",
		Description = "Maximum 50 AP kinetic barrier with zero movement speed penalty.",
	},

	-- TACTICAL UTILITY (u8 IDs: 50..59)
	{
		Id = 50,
		CodeKey = "util_impulse_grenade",
		DisplayName = "Bhop Impulse Satchel",
		Category = "Utility",
		Cost = 200,
		PermanentUnlockFluxCost = 0,
		KillAwardMultiplier = 1.0,
		UtilityBitIndex = 0,
		AssetIconKey = "Sprite_Util_ImpulseGrenade",
		Description = "Detonates for instant radial knockback to kickstart 85 studs/s bunny-hop chains.",
	},
	{
		Id = 51,
		CodeKey = "util_arc_cell",
		DisplayName = "Arc Disrupter Cell",
		Category = "Utility",
		Cost = 250,
		PermanentUnlockFluxCost = 300,
		KillAwardMultiplier = 1.0,
		UtilityBitIndex = 1,
		AssetIconKey = "Sprite_Util_ArcCell",
		Description = "Temporarily scrambles enemy HUD telemetry and strips 15 Exo-Shield AP.",
	},
	{
		Id = 52,
		CodeKey = "util_phase_stim",
		DisplayName = "Kinetic Phase Injector",
		Category = "Utility",
		Cost = 300,
		PermanentUnlockFluxCost = 600,
		KillAwardMultiplier = 1.0,
		UtilityBitIndex = 2,
		AssetIconKey = "Sprite_Util_PhaseStim",
		Description = "Boosts air-accelerate response by 15% and triggers instant health regen on kill.",
	},
}

local ItemsById: { [number]: EconomyItemDefinition } = {}
local ItemsByKey: { [string]: EconomyItemDefinition } = {}

for _, item in ItemsList do
	local frozenItem = table.freeze(item)
	ItemsById[item.Id] = frozenItem
	ItemsByKey[item.CodeKey] = frozenItem
end

local EconomyConfig = {
	-- Match Credit Caps & Starting Values
	StartingMatchCredits = 800,
	OvertimeStartingCredits = 10000,
	MaxMatchCredits = 16000,
	BuyPhaseDurationSeconds = 20.0,
	RequestRateLimitInterval = 0.08, -- Minimum seconds between client purchase packets

	-- Combat & Velocity Bounty Thresholds (Synced with MovementConfig & HudApp)
	BaseKillReward = 300,
	HeadshotBonusReward = 100,
	AirborneKillBonusReward = 75,
	OverdriveSpeedThreshold = 45.0, -- Matches Section 3.4 Overdrive Neon Orange threshold
	OverdriveKillBonusReward = 150,
	HyperdriveSpeedThreshold = 75.0, -- Near 85 studs/s HardSpeedCap
	HyperdriveKillBonusReward = 250,
	AssistReward = 100,
	AssistDamageThreshold = 40,
	AssistWindowSeconds = 6.0,

	-- Round Outcome Rewards
	RoundWinCredits = 3250,
	ObjectiveActionCredits = 300,
	LossStreakRewards = table.freeze({
		[1] = 1900,
		[2] = 2400,
		[3] = 2900,
		[4] = 3400, -- Caps at 3400 for 4+ consecutive losses
	}),

	-- Persistent Flux Shards (DataStoreService Progression)
	FluxPerStandardKill = 15,
	FluxPerHeadshotBonus = 10,
	FluxPerOverdriveBonus = 20,
	FluxPerHyperdriveBonus = 35,
	FluxPerRoundWin = 50,
	FluxPerRoundLoss = 25,

	-- Armor Absorption Constants
	ArmorAbsorptionRatio = 0.66, -- 66% of incoming damage absorbed by Exo-Shield
	ArmorDurabilityCostPerDamage = 0.5, -- 1 AP consumed per 2 raw damage absorbed
	
	-- Sound & UI Asset Keys (Queried via src/shared/configs/AssetRegistry.luau)
	AudioKeys = table.freeze({
		PurchaseSuccess = "SFX_UI_PurchaseConfirm",
		PurchaseDenied = "SFX_UI_PurchaseDenied",
		SellRefund = "SFX_UI_ItemRefund",
		OverdriveBounty = "SFX_HUD_OverdriveKillBounty",
	}),

	-- UI Palette Constants (Matches Section 3.4 HudApp Glassmorphic Spec)
	Palette = table.freeze({
		SurfaceDarkSlate = Color3.fromRGB(10, 14, 20),
		SurfaceCard = Color3.fromRGB(16, 22, 32),
		SurfaceTransparency = 0.35,
		NeonCyan = Color3.fromRGB(0, 240, 255), -- #00F0FF Standard Telemetry
		OverdriveOrange = Color3.fromRGB(255, 110, 0), -- #FF6E00 Overdrive (>45 studs/s)
		SuccessGreen = Color3.fromRGB(46, 213, 115),
		DangerRed = Color3.fromRGB(255, 71, 87),
		TextPrimary = Color3.fromRGB(240, 246, 252),
		TextMuted = Color3.fromRGB(139, 148, 158),
	}),

	ActionTypes = ActionTypes,
	ReasonCodes = ReasonCodes,
	ItemsList = table.freeze(ItemsList),
	ItemsById = table.freeze(ItemsById),
	ItemsByKey = table.freeze(ItemsByKey),
}

return table.freeze(EconomyConfig)
