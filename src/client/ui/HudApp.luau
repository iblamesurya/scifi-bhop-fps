--!strict
--[[
	HudApp.luau
	Minimalist glassmorphic sci-fi in-game HUD:
	- Bottom-center Speedometer (00.0 STUDS/S in Enum.Font.Code, shifts #00F0FF -> #FF6E00 above 45 studs/s)
	- Bottom-right Minimalist Ammo & Weapon Card reading live state from WeaponController
	- Bottom-left Health Bar tracking LocalPlayer.Character.Humanoid.Health
	- Top-right KILLS / DEATHS / PEAK SPEED mini-telemetry badge
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local clientRoot = script.Parent.Parent

local MovementController = require(clientRoot:WaitForChild("movement"):WaitForChild("MovementController")) :: any
local WeaponController = require(clientRoot:WaitForChild("combat"):WaitForChild("WeaponController")) :: any
local CrosshairModule = require(script.Parent:WaitForChild("CrosshairModule"))
local LobbyApp = require(script.Parent:WaitForChild("LobbyApp"))

-- Shared WeaponData lookup
local WeaponData: { [string]: any } = {}
do
	local sharedFolder = ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared", 5)
	if sharedFolder then
		local configs = sharedFolder:FindFirstChild("configs")
		local weaponDataModule = if configs then configs:FindFirstChild("WeaponData") else nil
		if weaponDataModule and weaponDataModule:IsA("ModuleScript") then
			local ok, data = pcall(require, weaponDataModule)
			if ok and type(data) == "table" then
				WeaponData = data
			end
		end
	end
end

-- Shared EconomyClient lookup
local EconomyClient: any = nil
do
	local combatFolder = clientRoot:FindFirstChild("combat")
	local ecModule = if combatFolder then combatFolder:FindFirstChild("EconomyClient") else nil
	if ecModule and ecModule:IsA("ModuleScript") then
		local ok, data = pcall(require, ecModule)
		if ok and type(data) == "table" then
			EconomyClient = data
		end
	end
end

local HudApp = {}

-- Glassmorphic Visual Constants
local CARD_BG_COLOR = Color3.fromRGB(10, 14, 20)
local CARD_BG_TRANSPARENCY = 0.35
local COLOR_NEON_CYAN = Color3.fromRGB(0, 240, 255) -- #00F0FF
local COLOR_OVERDRIVE_ORANGE = Color3.fromRGB(255, 110, 0) -- #FF6E00
local COLOR_CRITICAL_RED = Color3.fromRGB(255, 55, 65)
local COLOR_TEXT_PRIMARY = Color3.fromRGB(235, 248, 255)
local COLOR_TEXT_MUTED = Color3.fromRGB(130, 155, 175)

local OVERDRIVE_SPEED_THRESHOLD = 45.0
local MAX_SPEED_BAR_REFERENCE = 80.0

local DEFAULT_WEAPON_META: { [string]: { DisplayName: string, MagazineSize: number } } = {
	VORTEX_SMG = { DisplayName = "VORTEX SMG", MagazineSize = 30 },
	HELIOS_RAIL = { DisplayName = "HELIOS RAIL", MagazineSize = 5 },
}

-- Internal UI References
local isInitialized = false
local hudGui: ScreenGui? = nil

-- Speedometer Refs
local speedTextLabel: TextLabel? = nil
local speedStateLabel: TextLabel? = nil
local speedFillBar: Frame? = nil
local speedStroke: UIStroke? = nil

-- Health Refs
local healthValueLabel: TextLabel? = nil
local healthFillBar: Frame? = nil
local healthStroke: UIStroke? = nil

-- Ammo & Weapon Refs
local weaponNameLabel: TextLabel? = nil
local ammoCurrentLabel: TextLabel? = nil
local ammoMaxLabel: TextLabel? = nil
local ammoFillBar: Frame? = nil
local ammoStroke: UIStroke? = nil

-- Top-Right Telemetry Badge Refs
local killsValueLabel: TextLabel? = nil
local deathsValueLabel: TextLabel? = nil
local peakSpeedValueLabel: TextLabel? = nil
local telemetryStroke: UIStroke? = nil

-- Top-Right Economy Badge Refs
local creditsValueLabel: TextLabel? = nil
local armorValueLabel: TextLabel? = nil
local fluxValueLabel: TextLabel? = nil
local buyPhaseBadgeLabel: TextLabel? = nil
local economyStroke: UIStroke? = nil

-- Interactive Staged Onboarding Refs (@adamdoesrobloxx retention fix)
local onboardingCard: Frame? = nil
local onboardingTextLabel: TextLabel? = nil
local onboardingStroke: UIStroke? = nil
local onboardingStage = 1 -- 1: Bhop > 45, 2: Slide [C/Ctrl], 3: Scope [RMB] + Fire [LMB], 4: Completed
local onboardingCompletedTime = 0

-- Moment-of-Death / Low-HP Instant Re-Arm Banner (@yelik.dev shop psychology)
local reviveOfferBanner: Frame? = nil

-- @motionbykrit Game Feel & Juice: Pre-allocated Floating Damage Number Pool + Smooth Bar Lerping
type FloatingDamageEntry = {
	Label: TextLabel,
	Scale: UIScale,
	WorldPos: Vector3,
	StartTime: number,
	Active: boolean,
}
local DAMAGE_POOL_SIZE = 12
local damageNumberPool: { FloatingDamageEntry } = table.create(DAMAGE_POOL_SIZE)
local damagePoolCursor = 0
local smoothHealthRatio = 1.0
local smoothSpeedRatio = 0.0
local lastKnownKills = 0
local killsBumpScale: UIScale? = nil

local humanoidConnections: { RBXScriptConnection } = {}

local function createGlassCard(
	name: string,
	parent: Instance,
	size: UDim2,
	position: UDim2,
	anchorPoint: Vector2
): (Frame, UIStroke)
	local card = Instance.new("Frame")
	card.Name = name
	card.Size = size
	card.Position = position
	card.AnchorPoint = anchorPoint
	card.BackgroundColor3 = CARD_BG_COLOR
	card.BackgroundTransparency = CARD_BG_TRANSPARENCY
	card.BorderSizePixel = 0
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_NEON_CYAN
	stroke.Thickness = 1
	stroke.Transparency = 0.25
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	return card, stroke
end

local function readPlanarSpeed(): number
	if type(MovementController) == "table" then
		if type(MovementController.CurrentPlanarSpeed) == "number" then
			return MovementController.CurrentPlanarSpeed
		elseif type(MovementController.GetPlanarSpeed) == "function" then
			local ok, speed = pcall(MovementController.GetPlanarSpeed)
			if ok and type(speed) == "number" then
				return speed
			end
		end
	end
	return 0
end

local function readWeaponTelemetry(): (string, number, number, boolean)
	local weaponId = "VORTEX_SMG"
	local currentAmmo: number? = nil
	local maxAmmo: number? = nil
	local isReloading = false

	if type(WeaponController) == "table" then
		local rawId = WeaponController.CurrentWeaponId
			or WeaponController.EquippedWeaponId
			or WeaponController.CurrentWeapon
			or WeaponController.WeaponId
		if type(rawId) == "string" and #rawId > 0 then
			weaponId = rawId
		elseif type(WeaponController.GetEquippedWeapon) == "function" then
			local ok, res = pcall(WeaponController.GetEquippedWeapon)
			if ok and type(res) == "string" and #res > 0 then
				weaponId = res
			end
		end

		if type(WeaponController.CurrentAmmo) == "number" then
			currentAmmo = WeaponController.CurrentAmmo
		elseif type(WeaponController.Ammo) == "number" then
			currentAmmo = WeaponController.Ammo
		elseif type(WeaponController.GetAmmo) == "function" then
			local ok, cur, max = pcall(WeaponController.GetAmmo)
			if ok and type(cur) == "number" then
				currentAmmo = cur
				if type(max) == "number" then
					maxAmmo = max
				end
			end
		end

		if type(WeaponController.MaxAmmo) == "number" then
			maxAmmo = WeaponController.MaxAmmo
		elseif type(WeaponController.MagazineSize) == "number" then
			maxAmmo = WeaponController.MagazineSize
		end

		if type(WeaponController.IsReloading) == "boolean" then
			isReloading = WeaponController.IsReloading
		elseif type(WeaponController.IsReloading) == "function" then
			local ok, rel = pcall(WeaponController.IsReloading)
			if ok and type(rel) == "boolean" then
				isReloading = rel
			end
		end
	end

	local attrWeapon = LocalPlayer:GetAttribute("EquippedWeapon") or LocalPlayer:GetAttribute("SelectedWeapon")
	if type(attrWeapon) == "string" and #attrWeapon > 0 and weaponId == "VORTEX_SMG" then
		weaponId = attrWeapon
	end

	local configEntry = WeaponData[weaponId] or (WeaponData.Weapons and WeaponData.Weapons[weaponId])
	local fallbackMeta = DEFAULT_WEAPON_META[weaponId] or { DisplayName = weaponId, MagazineSize = 30 }

	local resolvedMax = maxAmmo
		or (
			if type(configEntry) == "table"
				then (configEntry.MagazineSize or configEntry.MaxAmmo or configEntry.AmmoCapacity)
				else nil
		)
		or fallbackMeta.MagazineSize

	local resolvedCurrent = currentAmmo or resolvedMax
	local displayName = (
		if type(configEntry) == "table" and type(configEntry.DisplayName or configEntry.Name) == "string"
			then (configEntry.DisplayName or configEntry.Name)
			else fallbackMeta.DisplayName
	)

	return string.upper(displayName),
		math.max(0, math.floor(resolvedCurrent)),
		math.max(1, math.floor(resolvedMax)),
		isReloading
end

local function updateHealthDisplay(health: number, maxHealth: number)
	local safeMax = if maxHealth > 0 then maxHealth else 100
	local clampedHealth = math.clamp(health, 0, safeMax)
	local ratio = clampedHealth / safeMax
	local isLow = ratio <= 0.35
	local accentColor = if isLow then COLOR_CRITICAL_RED else COLOR_NEON_CYAN

	if healthValueLabel then
		healthValueLabel.Text = string.format("%03d", math.ceil(clampedHealth))
		healthValueLabel.TextColor3 = if isLow then COLOR_CRITICAL_RED else COLOR_TEXT_PRIMARY
	end
	if healthFillBar then
		-- @motionbykrit: Colour states Green -> Yellow/Orange -> Red & smooth bar animation
		local stateColor = if ratio <= 0.30
			then COLOR_CRITICAL_RED
			elseif ratio <= 0.65 then COLOR_OVERDRIVE_ORANGE
			else COLOR_NEON_CYAN
		smoothHealthRatio = smoothHealthRatio + (ratio - smoothHealthRatio) * 0.28
		healthFillBar.Size = UDim2.fromScale(smoothHealthRatio, 1)
		healthFillBar.BackgroundColor3 = stateColor
	end
	if healthStroke then
		healthStroke.Color = accentColor
	end
end

function HudApp.SpawnFloatingDamageNumber(worldPos: Vector3, damage: number, isHeadshot: boolean)
	if #damageNumberPool == 0 then
		return
	end
	damagePoolCursor = (damagePoolCursor % DAMAGE_POOL_SIZE) + 1
	local slot = damageNumberPool[damagePoolCursor]
	if not slot then
		return
	end
	slot.WorldPos = worldPos + Vector3.new((math.random() - 0.5) * 0.9, 0.6, (math.random() - 0.5) * 0.9)
	slot.StartTime = os.clock()
	slot.Active = true
	slot.Label.Text = if isHeadshot then string.format("%d!", math.round(damage)) else tostring(math.round(damage))
	slot.Label.TextColor3 = if isHeadshot then COLOR_OVERDRIVE_ORANGE else Color3.new(1, 1, 1)
	slot.Label.TextSize = math.clamp(14 + math.floor(damage / 10), 15, 28)
	slot.Label.TextTransparency = 0
	slot.Label.TextStrokeTransparency = 0.15
	slot.Scale.Scale = 1.35
	slot.Label.Visible = true
end

local function updateTopRightTelemetryBadge()
	local rawKills = LocalPlayer:GetAttribute("Kills")
	local rawDeaths = LocalPlayer:GetAttribute("Deaths")
	local rawTopSpeed = LocalPlayer:GetAttribute("TopBhopSpeed")

	local kills = if type(rawKills) == "number" then math.max(0, math.floor(rawKills)) else 0
	local deaths = if type(rawDeaths) == "number" then math.max(0, math.floor(rawDeaths)) else 0
	local topSpeed = if type(rawTopSpeed) == "number" then math.max(0, rawTopSpeed) else 0.0

	local planarSpeed = readPlanarSpeed()
	if planarSpeed > topSpeed then
		topSpeed = planarSpeed
	end

	local isOverdrivePeak = topSpeed > OVERDRIVE_SPEED_THRESHOLD

	if killsValueLabel then
		killsValueLabel.Text = string.format("%02d", kills)
		if kills > lastKnownKills and killsBumpScale then
			killsBumpScale.Scale = 1.38
		end
		lastKnownKills = kills
	end
	if killsBumpScale and killsBumpScale.Scale > 1.001 then
		killsBumpScale.Scale = 1.0 + (killsBumpScale.Scale - 1.0) * 0.82
	end
	if deathsValueLabel then
		deathsValueLabel.Text = string.format("%02d", deaths)
	end
	if peakSpeedValueLabel then
		peakSpeedValueLabel.Text = string.format("%04.1f", topSpeed)
		peakSpeedValueLabel.TextColor3 = if isOverdrivePeak then COLOR_OVERDRIVE_ORANGE else COLOR_NEON_CYAN
	end
	if telemetryStroke then
		telemetryStroke.Color = if isOverdrivePeak then COLOR_OVERDRIVE_ORANGE else COLOR_NEON_CYAN
	end
end

local function updateEconomyDisplay()
	local credits = 800
	local armor = 0
	local flux = 0
	local buyOpen = false

	if EconomyClient then
		credits = EconomyClient.GetCredits()
		armor, _ = EconomyClient.GetArmor()
		flux = EconomyClient.GetFlux()
		buyOpen = EconomyClient.IsBuyPhaseOpen()
	else
		local rawCredits = LocalPlayer:GetAttribute("MatchCredits")
		if type(rawCredits) == "number" then
			credits = rawCredits
		end
		local rawArmor = LocalPlayer:GetAttribute("ArmorPoints")
		if type(rawArmor) == "number" then
			armor = rawArmor
		end
	end

	if creditsValueLabel then
		creditsValueLabel.Text = string.format("$%04d", credits)
	end
	if armorValueLabel then
		armorValueLabel.Text = if armor > 0 then string.format("%02d AP", armor) else "-- AP"
		armorValueLabel.TextColor3 = if armor > 0 then COLOR_NEON_CYAN else COLOR_TEXT_MUTED
	end
	if fluxValueLabel then
		fluxValueLabel.Text = string.format("%d FLUX", flux)
	end
	if buyPhaseBadgeLabel then
		buyPhaseBadgeLabel.Visible = buyOpen
	end
end

local function bindCharacter(character: Model?)
	for _, conn in ipairs(humanoidConnections) do
		conn:Disconnect()
	end
	table.clear(humanoidConnections)

	if not character then
		updateHealthDisplay(100, 100)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid and humanoid:IsA("Humanoid") then
		updateHealthDisplay(humanoid.Health, humanoid.MaxHealth)
		table.insert(
			humanoidConnections,
			humanoid.HealthChanged:Connect(function(newHealth: number)
				updateHealthDisplay(newHealth, humanoid.MaxHealth)
			end)
		)
	end
end

local function updateHudTelemetry()
	-- 1. Speedometer Update
	local speed = readPlanarSpeed()
	local isOverdrive = speed > OVERDRIVE_SPEED_THRESHOLD
	local speedAccent = if isOverdrive then COLOR_OVERDRIVE_ORANGE else COLOR_NEON_CYAN

	if speedTextLabel then
		speedTextLabel.Text = string.format("%04.1f STUDS/S", speed)
		speedTextLabel.TextColor3 = speedAccent
	end
	if speedStateLabel then
		speedStateLabel.Text = if isOverdrive then "OVERDRIVE // BHOP VELOCITY" else "TELEMETRY // PLANAR VELOCITY"
		speedStateLabel.TextColor3 = if isOverdrive then COLOR_OVERDRIVE_ORANGE else COLOR_TEXT_MUTED
	end
	if speedFillBar then
		local fillRatio = math.clamp(speed / MAX_SPEED_BAR_REFERENCE, 0, 1)
		smoothSpeedRatio = smoothSpeedRatio + (fillRatio - smoothSpeedRatio) * 0.25
		speedFillBar.Size = UDim2.fromScale(smoothSpeedRatio, 1)
		speedFillBar.BackgroundColor3 = speedAccent
	end
	if speedStroke then
		speedStroke.Color = speedAccent
	end

	-- @motionbykrit: Update floating 3D -> 2D damage numbers (pop in, float up, fade out)
	local cam = workspace.CurrentCamera
	local now = os.clock()
	if cam then
		for i = 1, #damageNumberPool do
			local slot = damageNumberPool[i]
			if slot and slot.Active then
				local age = now - slot.StartTime
				if age >= 0.55 then
					slot.Active = false
					slot.Label.Visible = false
				else
					local progress = age / 0.55
					local screenPt, onScreen = cam:WorldToViewportPoint(slot.WorldPos + Vector3.new(0, progress * 2.2, 0))
					if onScreen and screenPt.Z > 0 then
						slot.Label.Position = UDim2.fromOffset(screenPt.X, screenPt.Y - (progress * 26))
						slot.Label.TextTransparency = progress * progress
						slot.Label.TextStrokeTransparency = 0.15 + (progress * 0.85)
						slot.Scale.Scale = 1.0 + (slot.Scale.Scale - 1.0) * 0.78
						slot.Label.Visible = true
					else
						slot.Label.Visible = false
					end
				end
			end
		end
	end

	-- 2. Ammo & Weapon Update
	local weaponName, curAmmo, maxAmmo, isReloading = readWeaponTelemetry()
	local ammoRatio = math.clamp(curAmmo / math.max(1, maxAmmo), 0, 1)
	local isLowAmmo = (ammoRatio <= 0.25) or isReloading
	local ammoAccent = if isReloading
		then COLOR_OVERDRIVE_ORANGE
		elseif isLowAmmo then COLOR_CRITICAL_RED
		else COLOR_NEON_CYAN

	if weaponNameLabel then
		weaponNameLabel.Text = if isReloading then weaponName .. " // RELOADING" else weaponName
		weaponNameLabel.TextColor3 = if isReloading then COLOR_OVERDRIVE_ORANGE else COLOR_NEON_CYAN
	end
	if ammoCurrentLabel then
		ammoCurrentLabel.Text = string.format("%02d", curAmmo)
		ammoCurrentLabel.TextColor3 = if isLowAmmo then ammoAccent else COLOR_TEXT_PRIMARY
	end
	if ammoMaxLabel then
		ammoMaxLabel.Text = string.format("/ %02d", maxAmmo)
	end
	if ammoFillBar then
		ammoFillBar.Size = UDim2.fromScale(ammoRatio, 1)
		ammoFillBar.BackgroundColor3 = ammoAccent
	end
	if ammoStroke then
		ammoStroke.Color = ammoAccent
	end

	-- 3. Top-Right Kills / Deaths / Peak Speed Telemetry
	updateTopRightTelemetryBadge()

	-- 4. Live Character Health Sync & Moment-of-Death Re-Arm Prompt (@yelik.dev)
	local character = LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			updateHealthDisplay(humanoid.Health, humanoid.MaxHealth)
			if reviveOfferBanner then
				reviveOfferBanner.Visible = (humanoid.Health <= 35)
			end
		end
	end

	-- 5. Interactive Staged Onboarding Tracker (@adamdoesrobloxx retention fix: <0.25s reactive stages)
	if onboardingCard and onboardingTextLabel and onboardingStroke then
		if onboardingStage == 1 then
			if speed >= OVERDRIVE_SPEED_THRESHOLD then
				onboardingStage = 2
				onboardingTextLabel.Text = "STAGE 2/3 // PRESS [C] OR [CTRL] AT SPEED TO SLIDE-BOOST"
				onboardingStroke.Color = COLOR_OVERDRIVE_ORANGE
			end
		elseif onboardingStage == 2 then
			if UserInputService:IsKeyDown(Enum.KeyCode.C) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				onboardingStage = 3
				onboardingTextLabel.Text = "STAGE 3/3 // HOLD [RMB] TO SCOPE & [LMB] TO ENGAGE TARGETS"
				onboardingStroke.Color = COLOR_NEON_CYAN
			end
		elseif onboardingStage == 3 then
			if
				UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
				and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			then
				onboardingStage = 4
				onboardingCompletedTime = os.clock()
				onboardingTextLabel.Text = "ONBOARDING COMPLETE // OVERDRIVE SYSTEMS UNLOCKED (+200 CR)"
				onboardingStroke.Color = Color3.fromRGB(46, 213, 115)
			end
		elseif onboardingStage == 4 then
			if (os.clock() - onboardingCompletedTime) > 1.8 then
				onboardingCard.Visible = false
			end
		end
	end

	-- 6. Live Economy & Armor Telemetry
	updateEconomyDisplay()
end

function HudApp.SetVisible(visible: boolean)
	if hudGui then
		hudGui.Enabled = visible
	end
end

function HudApp.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SciFiHudGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 5
	screenGui.Parent = playerGui
	hudGui = screenGui

	-- Initialize Crosshair inside HUD ScreenGui
	CrosshairModule.Init(screenGui)

	-- Register CrosshairModule.TriggerHitmarker & Floating Damage Numbers into WeaponController
	if type(WeaponController) == "table" then
		local existingHook = WeaponController.OnHitConfirmed
		if existingHook == nil then
			WeaponController.OnHitConfirmed = CrosshairModule.TriggerHitmarker
		elseif typeof(existingHook) == "Instance" and existingHook:IsA("BindableEvent") then
			existingHook.Event:Connect(CrosshairModule.TriggerHitmarker)
		elseif type(existingHook) == "table" and type(existingHook.Connect) == "function" then
			existingHook:Connect(CrosshairModule.TriggerHitmarker)
		end

		if type(WeaponController.OnDamageNumberRequested) == "table" then
			table.insert(WeaponController.OnDamageNumberRequested, HudApp.SpawnFloatingDamageNumber)
		end
	end

	-- Pre-allocate 12 Floating Damage Number labels (@motionbykrit: zero Instance.new during combat)
	table.clear(damageNumberPool)
	for i = 1, DAMAGE_POOL_SIZE do
		local dmgLbl = Instance.new("TextLabel")
		dmgLbl.Name = string.format("FloatingDmg_%02d", i)
		dmgLbl.BackgroundTransparency = 1
		dmgLbl.AnchorPoint = Vector2.new(0.5, 0.5)
		dmgLbl.Size = UDim2.fromOffset(90, 30)
		dmgLbl.Font = Enum.Font.Code
		dmgLbl.Text = "28"
		dmgLbl.TextSize = 18
		dmgLbl.TextColor3 = Color3.new(1, 1, 1)
		dmgLbl.TextStrokeColor3 = Color3.fromRGB(8, 12, 18)
		dmgLbl.TextStrokeTransparency = 0.15
		dmgLbl.Visible = false
		dmgLbl.ZIndex = 20
		dmgLbl.Parent = screenGui

		local uiscale = Instance.new("UIScale")
		uiscale.Scale = 1.0
		uiscale.Parent = dmgLbl

		damageNumberPool[i] = {
			Label = dmgLbl,
			Scale = uiscale,
			WorldPos = Vector3.zero,
			StartTime = 0,
			Active = false,
		}
	end

	-- =========================================================================
	-- 1. TOP-RIGHT MINI-TELEMETRY BADGE (KILLS / DEATHS / PEAK SPEED)
	-- =========================================================================
	local telemetryCard, tStroke = createGlassCard(
		"TelemetryBadgeCard",
		screenGui,
		UDim2.fromOffset(276, 54),
		UDim2.new(1, -32, 0, 24),
		Vector2.new(1, 0)
	)
	telemetryStroke = tStroke

	local killsHeader = Instance.new("TextLabel")
	killsHeader.Name = "KillsHeader"
	killsHeader.BackgroundTransparency = 1
	killsHeader.Position = UDim2.fromOffset(14, 7)
	killsHeader.Size = UDim2.fromOffset(64, 13)
	killsHeader.Font = Enum.Font.Code
	killsHeader.Text = "KILLS"
	killsHeader.TextSize = 11
	killsHeader.TextColor3 = COLOR_TEXT_MUTED
	killsHeader.TextXAlignment = Enum.TextXAlignment.Left
	killsHeader.Parent = telemetryCard

	local killsVal = Instance.new("TextLabel")
	killsVal.Name = "KillsValue"
	killsVal.BackgroundTransparency = 1
	killsVal.Position = UDim2.fromOffset(14, 22)
	killsVal.Size = UDim2.fromOffset(64, 24)
	killsVal.Font = Enum.Font.Code
	killsVal.Text = "00"
	killsVal.TextSize = 20
	killsVal.TextColor3 = COLOR_TEXT_PRIMARY
	killsVal.TextXAlignment = Enum.TextXAlignment.Left
	killsVal.Parent = telemetryCard
	killsValueLabel = killsVal

	local kScale = Instance.new("UIScale")
	kScale.Scale = 1.0
	kScale.Parent = killsVal
	killsBumpScale = kScale

	local deathsHeader = Instance.new("TextLabel")
	deathsHeader.Name = "DeathsHeader"
	deathsHeader.BackgroundTransparency = 1
	deathsHeader.Position = UDim2.fromOffset(92, 7)
	deathsHeader.Size = UDim2.fromOffset(64, 13)
	deathsHeader.Font = Enum.Font.Code
	deathsHeader.Text = "DEATHS"
	deathsHeader.TextSize = 11
	deathsHeader.TextColor3 = COLOR_TEXT_MUTED
	deathsHeader.TextXAlignment = Enum.TextXAlignment.Left
	deathsHeader.Parent = telemetryCard

	local deathsVal = Instance.new("TextLabel")
	deathsVal.Name = "DeathsValue"
	deathsVal.BackgroundTransparency = 1
	deathsVal.Position = UDim2.fromOffset(92, 22)
	deathsVal.Size = UDim2.fromOffset(64, 24)
	deathsVal.Font = Enum.Font.Code
	deathsVal.Text = "00"
	deathsVal.TextSize = 20
	deathsVal.TextColor3 = COLOR_TEXT_PRIMARY
	deathsVal.TextXAlignment = Enum.TextXAlignment.Left
	deathsVal.Parent = telemetryCard
	deathsValueLabel = deathsVal

	local peakHeader = Instance.new("TextLabel")
	peakHeader.Name = "PeakHeader"
	peakHeader.BackgroundTransparency = 1
	peakHeader.Position = UDim2.new(1, -110, 0, 7)
	peakHeader.Size = UDim2.fromOffset(96, 13)
	peakHeader.Font = Enum.Font.Code
	peakHeader.Text = "PEAK STUDS/S"
	peakHeader.TextSize = 11
	peakHeader.TextColor3 = COLOR_TEXT_MUTED
	peakHeader.TextXAlignment = Enum.TextXAlignment.Right
	peakHeader.Parent = telemetryCard

	local peakVal = Instance.new("TextLabel")
	peakVal.Name = "PeakSpeedValue"
	peakVal.BackgroundTransparency = 1
	peakVal.Position = UDim2.new(1, -110, 0, 22)
	peakVal.Size = UDim2.fromOffset(96, 24)
	peakVal.Font = Enum.Font.Code
	peakVal.Text = "00.0"
	peakVal.TextSize = 20
	peakVal.TextColor3 = COLOR_NEON_CYAN
	peakVal.TextXAlignment = Enum.TextXAlignment.Right
	peakVal.Parent = telemetryCard
	peakSpeedValueLabel = peakVal

	-- =========================================================================
	-- 1B. TOP-RIGHT ECONOMY & SHIELD BADGE (MATCH CREDITS / EXO-SHIELD / FLUX)
	-- =========================================================================
	local economyCard, eStroke = createGlassCard(
		"EconomyBadgeCard",
		screenGui,
		UDim2.fromOffset(276, 44),
		UDim2.new(1, -32, 0, 84),
		Vector2.new(1, 0)
	)
	economyStroke = eStroke

	local credHeader = Instance.new("TextLabel")
	credHeader.Name = "CreditsHeader"
	credHeader.BackgroundTransparency = 1
	credHeader.Position = UDim2.fromOffset(14, 5)
	credHeader.Size = UDim2.fromOffset(70, 12)
	credHeader.Font = Enum.Font.Code
	credHeader.Text = "CREDITS"
	credHeader.TextSize = 10
	credHeader.TextColor3 = COLOR_TEXT_MUTED
	credHeader.TextXAlignment = Enum.TextXAlignment.Left
	credHeader.Parent = economyCard

	local credVal = Instance.new("TextLabel")
	credVal.Name = "CreditsValue"
	credVal.BackgroundTransparency = 1
	credVal.Position = UDim2.fromOffset(14, 18)
	credVal.Size = UDim2.fromOffset(70, 20)
	credVal.Font = Enum.Font.Code
	credVal.Text = "$0800"
	credVal.TextSize = 16
	credVal.TextColor3 = COLOR_NEON_CYAN
	credVal.TextXAlignment = Enum.TextXAlignment.Left
	credVal.Parent = economyCard
	creditsValueLabel = credVal

	local armorHeader = Instance.new("TextLabel")
	armorHeader.Name = "ArmorHeader"
	armorHeader.BackgroundTransparency = 1
	armorHeader.Position = UDim2.fromOffset(92, 5)
	armorHeader.Size = UDim2.fromOffset(70, 12)
	armorHeader.Font = Enum.Font.Code
	armorHeader.Text = "EXO-SHIELD"
	armorHeader.TextSize = 10
	armorHeader.TextColor3 = COLOR_TEXT_MUTED
	armorHeader.TextXAlignment = Enum.TextXAlignment.Left
	armorHeader.Parent = economyCard

	local armorVal = Instance.new("TextLabel")
	armorVal.Name = "ArmorValue"
	armorVal.BackgroundTransparency = 1
	armorVal.Position = UDim2.fromOffset(92, 18)
	armorVal.Size = UDim2.fromOffset(70, 20)
	armorVal.Font = Enum.Font.Code
	armorVal.Text = "-- AP"
	armorVal.TextSize = 16
	armorVal.TextColor3 = COLOR_TEXT_MUTED
	armorVal.TextXAlignment = Enum.TextXAlignment.Left
	armorVal.Parent = economyCard
	armorValueLabel = armorVal

	local fluxHeader = Instance.new("TextLabel")
	fluxHeader.Name = "FluxHeader"
	fluxHeader.BackgroundTransparency = 1
	fluxHeader.Position = UDim2.new(1, -94, 0, 5)
	fluxHeader.Size = UDim2.fromOffset(80, 12)
	fluxHeader.Font = Enum.Font.Code
	fluxHeader.Text = "ACCOUNT FLUX"
	fluxHeader.TextSize = 10
	fluxHeader.TextColor3 = COLOR_TEXT_MUTED
	fluxHeader.TextXAlignment = Enum.TextXAlignment.Right
	fluxHeader.Parent = economyCard

	local fluxVal = Instance.new("TextLabel")
	fluxVal.Name = "FluxValue"
	fluxVal.BackgroundTransparency = 1
	fluxVal.Position = UDim2.new(1, -94, 0, 18)
	fluxVal.Size = UDim2.fromOffset(80, 20)
	fluxVal.Font = Enum.Font.Code
	fluxVal.Text = "00 FLUX"
	fluxVal.TextSize = 16
	fluxVal.TextColor3 = COLOR_TEXT_PRIMARY
	fluxVal.TextXAlignment = Enum.TextXAlignment.Right
	fluxVal.Parent = economyCard
	fluxValueLabel = fluxVal

	local buyBadge = Instance.new("TextLabel")
	buyBadge.Name = "BuyPhaseBadge"
	buyBadge.BackgroundTransparency = 0.2
	buyBadge.BackgroundColor3 = Color3.fromRGB(15, 25, 38)
	buyBadge.Position = UDim2.new(1, -32, 0, 134)
	buyBadge.Size = UDim2.fromOffset(276, 22)
	buyBadge.AnchorPoint = Vector2.new(1, 0)
	buyBadge.Font = Enum.Font.Code
	buyBadge.Text = "BUY PHASE ACTIVE // PRESS [B] OR [M]"
	buyBadge.TextSize = 11
	buyBadge.TextColor3 = COLOR_OVERDRIVE_ORANGE
	buyBadge.Visible = false
	buyBadge.Parent = screenGui

	local buyBadgeCorner = Instance.new("UICorner")
	buyBadgeCorner.CornerRadius = UDim.new(0, 4)
	buyBadgeCorner.Parent = buyBadge

	local buyBadgeStroke = Instance.new("UIStroke")
	buyBadgeStroke.Color = COLOR_OVERDRIVE_ORANGE
	buyBadgeStroke.Thickness = 1
	buyBadgeStroke.Transparency = 0.4
	buyBadgeStroke.Parent = buyBadge
	buyPhaseBadgeLabel = buyBadge

	-- =========================================================================
	-- 2. BOTTOM-CENTER GLASSMORPHIC SPEEDOMETER
	-- =========================================================================
	local speedCard, sStroke = createGlassCard(
		"SpeedometerCard",
		screenGui,
		UDim2.fromOffset(250, 66),
		UDim2.new(0.5, 0, 1, -28),
		Vector2.new(0.5, 1)
	)
	speedStroke = sStroke

	local sState = Instance.new("TextLabel")
	sState.Name = "StateLabel"
	sState.BackgroundTransparency = 1
	sState.Position = UDim2.fromOffset(12, 6)
	sState.Size = UDim2.new(1, -24, 0, 14)
	sState.Font = Enum.Font.Code
	sState.Text = "TELEMETRY // PLANAR VELOCITY"
	sState.TextSize = 11
	sState.TextColor3 = COLOR_TEXT_MUTED
	sState.TextXAlignment = Enum.TextXAlignment.Center
	sState.Parent = speedCard
	speedStateLabel = sState

	local sValue = Instance.new("TextLabel")
	sValue.Name = "SpeedValue"
	sValue.BackgroundTransparency = 1
	sValue.Position = UDim2.fromOffset(12, 20)
	sValue.Size = UDim2.new(1, -24, 0, 28)
	sValue.Font = Enum.Font.Code
	sValue.Text = "00.0 STUDS/S"
	sValue.TextSize = 22
	sValue.TextColor3 = COLOR_NEON_CYAN
	sValue.TextXAlignment = Enum.TextXAlignment.Center
	sValue.Parent = speedCard
	speedTextLabel = sValue

	local sBarBg = Instance.new("Frame")
	sBarBg.Name = "VelocityBarBg"
	sBarBg.Position = UDim2.new(0, 12, 1, -10)
	sBarBg.Size = UDim2.new(1, -24, 0, 4)
	sBarBg.BackgroundColor3 = Color3.fromRGB(25, 34, 48)
	sBarBg.BorderSizePixel = 0
	sBarBg.Parent = speedCard

	local sBarFill = Instance.new("Frame")
	sBarFill.Name = "Fill"
	sBarFill.Size = UDim2.fromScale(0, 1)
	sBarFill.BackgroundColor3 = COLOR_NEON_CYAN
	sBarFill.BorderSizePixel = 0
	sBarFill.Parent = sBarBg
	speedFillBar = sBarFill

	-- =========================================================================
	-- 3. BOTTOM-LEFT HEALTH BAR CARD
	-- =========================================================================
	local healthCard, hStroke = createGlassCard(
		"HealthCard",
		screenGui,
		UDim2.fromOffset(230, 68),
		UDim2.new(0, 32, 1, -28),
		Vector2.new(0, 1)
	)
	healthStroke = hStroke

	local hTitle = Instance.new("TextLabel")
	hTitle.Name = "Header"
	hTitle.BackgroundTransparency = 1
	hTitle.Position = UDim2.fromOffset(14, 8)
	hTitle.Size = UDim2.fromOffset(110, 14)
	hTitle.Font = Enum.Font.Code
	hTitle.Text = "VITALS // INTEGRITY"
	hTitle.TextSize = 11
	hTitle.TextColor3 = COLOR_TEXT_MUTED
	hTitle.TextXAlignment = Enum.TextXAlignment.Left
	hTitle.Parent = healthCard

	local hVal = Instance.new("TextLabel")
	hVal.Name = "HealthValue"
	hVal.BackgroundTransparency = 1
	hVal.Position = UDim2.fromOffset(14, 22)
	hVal.Size = UDim2.fromOffset(90, 26)
	hVal.Font = Enum.Font.Code
	hVal.Text = "100"
	hVal.TextSize = 24
	hVal.TextColor3 = COLOR_TEXT_PRIMARY
	hVal.TextXAlignment = Enum.TextXAlignment.Left
	hVal.Parent = healthCard
	healthValueLabel = hVal

	local hUnit = Instance.new("TextLabel")
	hUnit.Name = "UnitLabel"
	hUnit.BackgroundTransparency = 1
	hUnit.Position = UDim2.new(1, -64, 0, 28)
	hUnit.Size = UDim2.fromOffset(50, 18)
	hUnit.Font = Enum.Font.Code
	hUnit.Text = "HP"
	hUnit.TextSize = 14
	hUnit.TextColor3 = COLOR_NEON_CYAN
	hUnit.TextXAlignment = Enum.TextXAlignment.Right
	hUnit.Parent = healthCard

	local hBarBg = Instance.new("Frame")
	hBarBg.Name = "HealthBarBg"
	hBarBg.Position = UDim2.new(0, 14, 1, -12)
	hBarBg.Size = UDim2.new(1, -28, 0, 5)
	hBarBg.BackgroundColor3 = Color3.fromRGB(25, 34, 48)
	hBarBg.BorderSizePixel = 0
	hBarBg.Parent = healthCard

	local hBarFill = Instance.new("Frame")
	hBarFill.Name = "Fill"
	hBarFill.Size = UDim2.fromScale(1, 1)
	hBarFill.BackgroundColor3 = COLOR_NEON_CYAN
	hBarFill.BorderSizePixel = 0
	hBarFill.Parent = hBarBg
	healthFillBar = hBarFill

	-- =========================================================================
	-- 4. BOTTOM-RIGHT MINIMALIST AMMO & WEAPON CARD
	-- =========================================================================
	local ammoCard, aStroke = createGlassCard(
		"AmmoWeaponCard",
		screenGui,
		UDim2.fromOffset(230, 68),
		UDim2.new(1, -32, 1, -28),
		Vector2.new(1, 1)
	)
	ammoStroke = aStroke

	local wLabel = Instance.new("TextLabel")
	wLabel.Name = "WeaponName"
	wLabel.BackgroundTransparency = 1
	wLabel.Position = UDim2.fromOffset(14, 8)
	wLabel.Size = UDim2.new(1, -28, 0, 14)
	wLabel.Font = Enum.Font.Code
	wLabel.Text = "VORTEX SMG"
	wLabel.TextSize = 12
	wLabel.TextColor3 = COLOR_NEON_CYAN
	wLabel.TextXAlignment = Enum.TextXAlignment.Right
	wLabel.Parent = ammoCard
	weaponNameLabel = wLabel

	local aCur = Instance.new("TextLabel")
	aCur.Name = "CurrentAmmo"
	aCur.BackgroundTransparency = 1
	aCur.Position = UDim2.new(1, -135, 0, 22)
	aCur.Size = UDim2.fromOffset(65, 26)
	aCur.Font = Enum.Font.Code
	aCur.Text = "30"
	aCur.TextSize = 24
	aCur.TextColor3 = COLOR_TEXT_PRIMARY
	aCur.TextXAlignment = Enum.TextXAlignment.Right
	aCur.Parent = ammoCard
	ammoCurrentLabel = aCur

	local aMax = Instance.new("TextLabel")
	aMax.Name = "MaxAmmo"
	aMax.BackgroundTransparency = 1
	aMax.Position = UDim2.new(1, -66, 0, 27)
	aMax.Size = UDim2.fromOffset(52, 20)
	aMax.Font = Enum.Font.Code
	aMax.Text = "/ 30"
	aMax.TextSize = 15
	aMax.TextColor3 = COLOR_TEXT_MUTED
	aMax.TextXAlignment = Enum.TextXAlignment.Left
	aMax.Parent = ammoCard
	ammoMaxLabel = aMax

	local aBarBg = Instance.new("Frame")
	aBarBg.Name = "AmmoBarBg"
	aBarBg.Position = UDim2.new(0, 14, 1, -12)
	aBarBg.Size = UDim2.new(1, -28, 0, 5)
	aBarBg.BackgroundColor3 = Color3.fromRGB(25, 34, 48)
	aBarBg.BorderSizePixel = 0
	aBarBg.Parent = ammoCard

	local aBarFill = Instance.new("Frame")
	aBarFill.Name = "Fill"
	aBarFill.Size = UDim2.fromScale(1, 1)
	aBarFill.BackgroundColor3 = COLOR_NEON_CYAN
	aBarFill.BorderSizePixel = 0
	aBarFill.Parent = aBarBg
	ammoFillBar = aBarFill

	-- =========================================================================
	-- 5. INTERACTIVE 3-STAGE ONBOARDING TRACKER (@adamdoesrobloxx retention fix)
	-- =========================================================================
	local obCard, obStroke = createGlassCard(
		"InteractiveOnboardingCard",
		screenGui,
		UDim2.fromOffset(440, 32),
		UDim2.new(0.5, 0, 0, 22),
		Vector2.new(0.5, 0)
	)
	onboardingCard = obCard
	onboardingStroke = obStroke

	local obLabel = Instance.new("TextLabel")
	obLabel.Name = "OnboardingGoalText"
	obLabel.BackgroundTransparency = 1
	obLabel.Size = UDim2.fromScale(1, 1)
	obLabel.Font = Enum.Font.Code
	obLabel.Text = "STAGE 1/3 // HOLD [SPACE] + STRAFE [A/D] TO HIT 45 STUDS/S"
	obLabel.TextSize = 12
	obLabel.TextColor3 = COLOR_TEXT_PRIMARY
	obLabel.Parent = obCard
	onboardingTextLabel = obLabel

	-- =========================================================================
	-- 6. MOMENT-OF-DEATH / CRITICAL HP INSTANT RE-ARM BANNER (@yelik.dev)
	-- =========================================================================
	local revCard, revStroke = createGlassCard(
		"InstantReviveOfferBanner",
		screenGui,
		UDim2.fromOffset(420, 34),
		UDim2.new(0.5, 0, 1, -104),
		Vector2.new(0.5, 1)
	)
	revStroke.Color = COLOR_OVERDRIVE_ORANGE
	revCard.Visible = false
	reviveOfferBanner = revCard

	local revLabel = Instance.new("TextLabel")
	revLabel.Name = "ReviveOfferText"
	revLabel.BackgroundTransparency = 1
	revLabel.Size = UDim2.fromScale(1, 1)
	revLabel.Font = Enum.Font.Code
	revLabel.Text = "CRITICAL VITALS // PRESS [B] INSTANT EXO-SHIELD RE-ARM ($400 CR / 49 R$ STARTER)"
	revLabel.TextSize = 11
	revLabel.TextColor3 = COLOR_OVERDRIVE_ORANGE
	revLabel.Parent = revCard

	-- Character & Attribute Telemetry Connections
	if LocalPlayer.Character then
		bindCharacter(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(bindCharacter)

	LocalPlayer:GetAttributeChangedSignal("Kills"):Connect(updateTopRightTelemetryBadge)
	LocalPlayer:GetAttributeChangedSignal("Deaths"):Connect(updateTopRightTelemetryBadge)
	LocalPlayer:GetAttributeChangedSignal("TopBhopSpeed"):Connect(updateTopRightTelemetryBadge)
	updateTopRightTelemetryBadge()

	if EconomyClient and type(EconomyClient.OnStateChanged) == "table" then
		table.insert(EconomyClient.OnStateChanged, function()
			updateEconomyDisplay()
		end)
	end
	LocalPlayer:GetAttributeChangedSignal("ArmorPoints"):Connect(updateEconomyDisplay)
	LocalPlayer:GetAttributeChangedSignal("MatchCredits"):Connect(updateEconomyDisplay)
	updateEconomyDisplay()

	RunService.RenderStepped:Connect(updateHudTelemetry)

	-- Sync visibility with Arena attribute & ensure LobbyApp is initialized
	local function syncArenaVisibility()
		HudApp.SetVisible(true)
	end
	LocalPlayer:GetAttributeChangedSignal("InArena"):Connect(syncArenaVisibility)
	syncArenaVisibility()

	LobbyApp.Init()
end

return HudApp
