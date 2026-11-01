--!strict
--[[
	LobbyApp.luau
	Sleek glassmorphic sci-fi pre-spawn Lobby / Loadout overlay.
	- Active when LocalPlayer:GetAttribute("InArena") ~= true or toggled via M / B keybind
	- Weapon selection: VORTEX_SMG or HELIOS_RAIL (dynamically synced with WeaponData.luau)
	- "Competitive 240FPS Mode" toggle
	- Live Top Server B-Hop Speed Records board reading player:GetAttribute("TopBhopSpeed")
	- "DEPLOY TO ARENA" button firing ReplicatedStorage:WaitForChild("RequestDeploy"):FireServer(selectedWeaponId)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local clientRoot = script.Parent.Parent

local MovementController = require(clientRoot:WaitForChild("movement"):WaitForChild("MovementController")) :: any

-- Shared WeaponData module lookup
local WeaponData: { [string]: any } = {}
do
	local sharedFolder = ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared", 5)
	if sharedFolder then
		local configs = sharedFolder:FindFirstChild("configs")
		local weaponDataModule = if configs then configs:FindFirstChild("WeaponData") else nil
		if weaponDataModule and weaponDataModule:IsA("ModuleScript") then
			local ok, mod = pcall(require, weaponDataModule)
			if ok and type(mod) == "table" then
				WeaponData = mod
			end
		end
	end
end

-- Optional GraphicsController & WeaponController bridges
local GraphicsController: any = nil
do
	local graphicsFolder = clientRoot:FindFirstChild("graphics")
	local gcModule = if graphicsFolder then graphicsFolder:FindFirstChild("GraphicsController") else nil
	if gcModule and gcModule:IsA("ModuleScript") then
		local ok, mod = pcall(require, gcModule)
		if ok then
			GraphicsController = mod
		end
	end
end

local WeaponController: any = nil
do
	local combatFolder = clientRoot:FindFirstChild("combat")
	local wcModule = if combatFolder then combatFolder:FindFirstChild("WeaponController") else nil
	if wcModule and wcModule:IsA("ModuleScript") then
		local ok, mod = pcall(require, wcModule)
		if ok then
			WeaponController = mod
		end
	end
end

local EconomyClient: any = nil
do
	local combatFolder = clientRoot:FindFirstChild("combat")
	local ecModule = if combatFolder then combatFolder:FindFirstChild("EconomyClient") else nil
	if ecModule and ecModule:IsA("ModuleScript") then
		local ok, mod = pcall(require, ecModule)
		if ok then
			EconomyClient = mod
		end
	end
end

local LobbyApp = {}

-- Palette & Styling Constants
local BG_OVERLAY_COLOR = Color3.fromRGB(6, 9, 14)
local CARD_BG_COLOR = Color3.fromRGB(10, 14, 20)
local CARD_TRANSPARENCY = 0.35
local COLOR_NEON_CYAN = Color3.fromRGB(0, 240, 255) -- #00F0FF
local COLOR_OVERDRIVE_ORANGE = Color3.fromRGB(255, 110, 0) -- #FF6E00
local COLOR_TEXT_MAIN = Color3.fromRGB(235, 248, 255)
local COLOR_TEXT_SUB = Color3.fromRGB(135, 160, 180)
local COLOR_BORDER_IDLE = Color3.fromRGB(45, 65, 85)

type WeaponOption = {
	Id: string,
	Title: string,
	Class: string,
	DefaultDmg: number,
	DefaultHs: number,
	DefaultRpm: number,
	DefaultMag: number,
	Description: string,
}

local WEAPON_OPTIONS: { WeaponOption } = {
	{
		Id = "M4A1_Carbine",
		Title = "[3] M4A1 SOPMOD II",
		Class = "ASSAULT RIFLE // 5.56MM NATO AUTO",
		DefaultDmg = 28,
		DefaultHs = 51,
		DefaultRpm = 780,
		DefaultMag = 30,
		Description = "CNC octagonal forged carbine with EOTech EXPS3, G33 magnifier, and forward-curved PMAG.",
	},
	{
		Id = "MP5_Tactical",
		Title = "[4] HK MP5A3 TACTICAL",
		Class = "SUBMACHINE GUN // 9MM ROLLER-DELAYED",
		DefaultDmg = 21,
		DefaultHs = 34,
		DefaultRpm = 920,
		DefaultMag = 35,
		Description = "High-cadence suppressed CQC submachine gun with Aimpoint T2 and low-recoil air-strafe tracking.",
	},
	{
		Id = "AWM_Sniper",
		Title = "[5] AWM L115A3 .338",
		Class = "SNIPER RIFLE // .338 LAPUA MAGNUM",
		DefaultDmg = 105,
		DefaultHs = 262,
		DefaultRpm = 46,
		DefaultMag = 5,
		Description = "Accuracy International olive-drab chassis sniper with Schmidt & Bender PM II 8x optic.",
	},
	{
		Id = "M1014_Shotgun",
		Title = "[6] BENELLI M1014",
		Class = "COMBAT SHOTGUN // 12-GAUGE 8-PELLET",
		DefaultDmg = 16,
		DefaultHs = 25,
		DefaultRpm = 115,
		DefaultMag = 8,
		Description = "Semi-auto breacher shotgun with Trijicon RMR co-witnessed ghost rings and shell saddle.",
	},
	{
		Id = "M249_MachineGun",
		Title = "[7] FN M249 PARA SAW",
		Class = "LIGHT MACHINE GUN // 100-RD BELT",
		DefaultDmg = 31,
		DefaultHs = 54,
		DefaultRpm = 820,
		DefaultMag = 100,
		Description = "Sustained-fire squad automatic weapon with 100-round disintegrating brass link box.",
	},
	{
		Id = "G19X_Pistol",
		Title = "[8] GLOCK-19X MOS",
		Class = "SIDEARM PISTOL // 9MM COMPENSATED",
		DefaultDmg = 26,
		DefaultHs = 52,
		DefaultRpm = 420,
		DefaultMag = 19,
		Description = "Coyote tan custom sidearm with gold TiN match barrel, agency compensator, and RMR.",
	},
	{
		Id = "M67_Frag",
		Title = "[9] M67 FRAG GRENADE",
		Class = "ORDNANCE // COMP-B FRAGMENTATION",
		DefaultDmg = 135,
		DefaultHs = 135,
		DefaultRpm = 45,
		DefaultMag = 1,
		Description = "Spheroidal steel fragmentation grenade with M213 delay fuze and safety spoon.",
	},
	{
		Id = "KABAR_Knife",
		Title = "[0] KA-BAR USMC 1217",
		Class = "MELEE BLADE // 1095 CRO-VAN BOWIE",
		DefaultDmg = 55,
		DefaultHs = 110,
		DefaultRpm = 135,
		DefaultMag = 1,
		Description = "Stacked leather washer fighting knife with clip-point needle tip and blood fuller.",
	},
	{
		Id = "Tactical_Bat",
		Title = "[-] TACTICAL SLUGGER",
		Class = "HEAVY MELEE // BARBED WIRE & CLEAVER",
		DefaultDmg = 78,
		DefaultHs = 136,
		DefaultRpm = 75,
		DefaultMag = 1,
		Description = "Lathe-turned ash wood bat reinforced with steel collars, cleaver fins, and barbed wire.",
	},
	{
		Id = "VORTEX_SMG",
		Title = "[1] VORTEX_SMG",
		Class = "PLASMA SUBMACHINE GUN // CQC-VELOCITY",
		DefaultDmg = 18,
		DefaultHs = 36,
		DefaultRpm = 720,
		DefaultMag = 30,
		Description = "High-cadence plasma repeater engineered for aggressive mid-air tracking at 45+ studs/s.",
	},
	{
		Id = "HELIOS_RAIL",
		Title = "[2] HELIOS_RAIL",
		Class = "LINEAR ACCELERATOR RAILGUN // PRECISION",
		DefaultDmg = 95,
		DefaultHs = 237,
		DefaultRpm = 51,
		DefaultMag = 5,
		Description = "Instantaneous hyper-velocity slug projector rewarding pinpoint flick accuracy while B-hopping.",
	},
}

local FALLBACK_RECORDS = {
	{ Name = "AERO_VALKYRIE", Speed = 74.8 },
	{ Name = "PHANTOM_HZ", Speed = 68.4 },
	{ Name = "NEXUS_STRIDER", Speed = 63.1 },
	{ Name = "VORTEX_ZERO", Speed = 58.9 },
	{ Name = "KINETIC_PULSE", Speed = 52.5 },
}

-- State
local isInitialized = false
local lobbyGui: ScreenGui? = nil
local deployBtnRef: TextButton? = nil
local selectedWeaponId = "M4A1_Carbine"
local competitive240Mode = false
local manualOverlayOpen = false
local localPeakSpeed = 0.0

local weaponCardRefs: { [string]: { Card: Frame, Stroke: UIStroke, Badge: TextLabel, StatsLabel: TextLabel } } = {}
local recordRowLabels: { TextLabel } = {}
local toggleStrokeRef: UIStroke? = nil
local toggleStateLabelRef: TextLabel? = nil
local subtitleLabelRef: TextLabel? = nil

local function buildWeaponStatsText(option: WeaponOption): string
	local entry = WeaponData[option.Id] or (WeaponData.Weapons and WeaponData.Weapons[option.Id])
	local dmg = option.DefaultDmg
	local hs = option.DefaultHs
	local rpm = option.DefaultRpm
	local mag = option.DefaultMag

	if type(entry) == "table" then
		local rawDmg = entry.BaseDamage or entry.Damage
		if type(rawDmg) == "number" then
			dmg = math.floor(rawDmg)
		end

		if type(entry.HeadshotDamage) == "number" then
			hs = math.floor(entry.HeadshotDamage)
		elseif type(entry.HeadshotMultiplier) == "number" then
			hs = math.floor(dmg * entry.HeadshotMultiplier)
		end

		if type(entry.FireRateRPM) == "number" then
			rpm = math.round(entry.FireRateRPM)
		elseif type(entry.RPM) == "number" then
			rpm = math.round(entry.RPM)
		elseif type(entry.FireInterval) == "number" and entry.FireInterval > 0 then
			rpm = math.round(60 / entry.FireInterval)
		elseif type(entry.FireCooldown) == "number" and entry.FireCooldown > 0 then
			rpm = math.round(60 / entry.FireCooldown)
		elseif type(entry.FireRate) == "number" and entry.FireRate > 0 then
			rpm = if entry.FireRate > 25 then math.round(entry.FireRate) else math.round(60 / entry.FireRate)
		end

		local rawMag = entry.MagazineSize or entry.MaxAmmo or entry.AmmoCapacity
		if type(rawMag) == "number" then
			mag = math.floor(rawMag)
		end
	end

	return string.format("DMG: %d (%d HS) | ROF: %d RPM | MAG: %02d", dmg, hs, rpm, mag)
end

local function styleGlassPanel(frame: GuiObject, strokeColor: Color3, strokeThickness: number?): UIStroke
	frame.BackgroundColor3 = CARD_BG_COLOR
	frame.BackgroundTransparency = CARD_TRANSPARENCY
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Thickness = strokeThickness or 1
	stroke.Transparency = 0.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	return stroke
end

local function updateWeaponSelectionVisuals()
	for _, option in ipairs(WEAPON_OPTIONS) do
		local refs = weaponCardRefs[option.Id]
		if refs then
			local isSelected = (option.Id == selectedWeaponId)
			refs.Stroke.Color = if isSelected then COLOR_NEON_CYAN else COLOR_BORDER_IDLE
			refs.Stroke.Thickness = if isSelected then 2 else 1
			refs.Card.BackgroundTransparency = if isSelected then 0.2 else CARD_TRANSPARENCY
			refs.Badge.Text = if isSelected then "SELECTED // ACTIVE" else "CLICK TO EQUIP"
			refs.Badge.TextColor3 = if isSelected then COLOR_NEON_CYAN else COLOR_TEXT_SUB
			refs.StatsLabel.Text = buildWeaponStatsText(option)
		end
	end

	LocalPlayer:SetAttribute("SelectedWeapon", selectedWeaponId)
	if type(WeaponController) == "table" and type(WeaponController.EquipWeapon) == "function" then
		pcall(WeaponController.EquipWeapon, selectedWeaponId)
	end
end

local function applyCompetitiveMode(enabled: boolean)
	competitive240Mode = enabled
	LocalPlayer:SetAttribute("Competitive240FPSMode", enabled)

	if toggleStrokeRef then
		toggleStrokeRef.Color = if enabled then COLOR_OVERDRIVE_ORANGE else COLOR_BORDER_IDLE
		toggleStrokeRef.Thickness = if enabled then 2 else 1
	end
	if toggleStateLabelRef then
		toggleStateLabelRef.Text = if enabled then "Competitive 240FPS Mode: ON" else "Competitive 240FPS Mode: OFF"
		toggleStateLabelRef.TextColor3 = if enabled then COLOR_OVERDRIVE_ORANGE else COLOR_TEXT_MAIN
	end

	if type(GraphicsController) == "table" then
		local tierName = if enabled then "COMPETITIVE_240FPS" else "HIGH_FIDELITY"
		if type(GraphicsController.SetCompetitiveMode) == "function" then
			pcall(GraphicsController.SetCompetitiveMode, enabled)
		elseif type(GraphicsController.SetQualityTier) == "function" then
			pcall(GraphicsController.SetQualityTier, tierName)
		elseif type(GraphicsController.ApplyTier) == "function" then
			pcall(GraphicsController.ApplyTier, tierName)
		end
	end
end

local function refreshSpeedRecords()
	if type(MovementController) == "table" and type(MovementController.CurrentPlanarSpeed) == "number" then
		if MovementController.CurrentPlanarSpeed > localPeakSpeed then
			localPeakSpeed = MovementController.CurrentPlanarSpeed
		end
	end

	local entries: { { Name: string, Speed: number } } = {}
	local seenNames: { [string]: boolean } = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local attrSpeed = player:GetAttribute("TopBhopSpeed")
			or player:GetAttribute("PeakSpeed")
			or player:GetAttribute("TopSpeed")
			or player:GetAttribute("BestBhopSpeed")
			or player:GetAttribute("MaxSpeed")
		local speedVal = if type(attrSpeed) == "number" then attrSpeed else 0
		if player == LocalPlayer and localPeakSpeed > speedVal then
			speedVal = localPeakSpeed
		end
		if speedVal > 0 then
			table.insert(entries, { Name = string.upper(player.Name), Speed = speedVal })
			seenNames[string.upper(player.Name)] = true
		end
	end

	for _, fallback in ipairs(FALLBACK_RECORDS) do
		if not seenNames[fallback.Name] then
			table.insert(entries, { Name = fallback.Name, Speed = fallback.Speed })
		end
	end

	table.sort(entries, function(a, b)
		return a.Speed > b.Speed
	end)

	for i, rowLabel in ipairs(recordRowLabels) do
		local record = entries[i]
		if record then
			local isOverdrive = record.Speed > 45.0
			rowLabel.Text = string.format("#%d  %-16s %04.1f STUDS/S", i, record.Name, record.Speed)
			rowLabel.TextColor3 = if i == 1
				then COLOR_OVERDRIVE_ORANGE
				elseif isOverdrive then COLOR_NEON_CYAN
				else COLOR_TEXT_MAIN
		end
	end
end

local function refreshEconomySubtitle()
	if not subtitleLabelRef then
		return
	end
	local credits = 800
	local flux = 0
	local armor = 0
	if EconomyClient and type(EconomyClient.GetCredits) == "function" then
		credits = EconomyClient.GetCredits()
		flux = EconomyClient.GetFlux()
		armor, _ = EconomyClient.GetArmor()
	else
		local rawCreds = LocalPlayer:GetAttribute("MatchCredits")
		if type(rawCreds) == "number" then
			credits = rawCreds
		end
		local rawAP = LocalPlayer:GetAttribute("ArmorPoints")
		if type(rawAP) == "number" then
			armor = rawAP
		end
	end
	subtitleLabelRef.Text = string.format(
		"CREDITS: $%04d | FLUX: %d | SHIELD: %02d AP // TOGGLE [KEYBIND: M / B]",
		credits,
		flux,
		armor
	)
end

local function syncLobbyState()
	local showLobby = manualOverlayOpen

	LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

	if lobbyGui then
		lobbyGui.Enabled = showLobby
	end
	if deployBtnRef then
		deployBtnRef.Modal = showLobby
		local inArena = LocalPlayer:GetAttribute("InArena") == true
		deployBtnRef.Text = if inArena then "REDEPLOY TO PHANTOM MIDWAY 5v5" else "DEPLOY TO PHANTOM MIDWAY 5v5"
	end

	if showLobby then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		updateWeaponSelectionVisuals()
		refreshSpeedRecords()
		refreshEconomySubtitle()
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
end

local function handleDeployClicked()
	manualOverlayOpen = false
	syncLobbyState()

	local requestDeploy = ReplicatedStorage:WaitForChild("RequestDeploy", 5)
	if requestDeploy and requestDeploy:IsA("RemoteEvent") then
		requestDeploy:FireServer(selectedWeaponId)
	end
end

function LobbyApp.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SciFiLobbyGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 20
	screenGui.Parent = playerGui
	lobbyGui = screenGui

	-- Dim Glassmorphic Backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Name = "LobbyBackdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = BG_OVERLAY_COLOR
	backdrop.BackgroundTransparency = 0.25
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screenGui

	-- Main Centered Container
	local mainPanel = Instance.new("Frame")
	mainPanel.Name = "MainContainer"
	mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	mainPanel.Position = UDim2.fromScale(0.5, 0.5)
	mainPanel.Size = UDim2.fromOffset(820, 470)
	mainPanel.Parent = backdrop
	styleGlassPanel(mainPanel, COLOR_NEON_CYAN, 1)

	-- Header Banner
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "HeaderTitle"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(24, 18)
	titleLabel.Size = UDim2.new(1, -48, 0, 26)
	titleLabel.Font = Enum.Font.Code
	titleLabel.Text = "ORBITAL DROP // TACTICAL LOADOUT & TELEMETRY"
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = COLOR_NEON_CYAN
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = mainPanel

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "HeaderSubtitle"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromOffset(24, 44)
	subtitleLabel.Size = UDim2.new(1, -48, 0, 16)
	subtitleLabel.Font = Enum.Font.Code
	subtitleLabel.Text = "SELECT PRIMARY ARMAMENT, CONFIGURE 240HZ PIPELINE, AND DEPLOY [KEYBIND: M / B]"
	subtitleLabel.TextSize = 12
	subtitleLabel.TextColor3 = COLOR_TEXT_SUB
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = mainPanel
	subtitleLabelRef = subtitleLabel
	refreshEconomySubtitle()

	-- =========================================================================
	-- LEFT COLUMN: 9-WEAPON CAD ARSENAL + STARTER SELECTOR (SCROLLABLE)
	-- =========================================================================
	local loadoutHeader = Instance.new("TextLabel")
	loadoutHeader.Name = "LoadoutHeader"
	loadoutHeader.BackgroundTransparency = 1
	loadoutHeader.Position = UDim2.fromOffset(24, 76)
	loadoutHeader.Size = UDim2.fromOffset(440, 18)
	loadoutHeader.Font = Enum.Font.Code
	loadoutHeader.Text = "ARSENAL WEAPON SUITE SELECT (SCROLL // KEYS 1-9, 0, -, H=SKIN)"
	loadoutHeader.TextSize = 12
	loadoutHeader.TextColor3 = COLOR_TEXT_MAIN
	loadoutHeader.TextXAlignment = Enum.TextXAlignment.Left
	loadoutHeader.Parent = mainPanel

	local weaponScroll = Instance.new("ScrollingFrame")
	weaponScroll.Name = "WeaponScrollList"
	weaponScroll.Position = UDim2.fromOffset(24, 100)
	weaponScroll.Size = UDim2.fromOffset(456, 252)
	weaponScroll.BackgroundTransparency = 1
	weaponScroll.BorderSizePixel = 0
	weaponScroll.ScrollBarThickness = 5
	weaponScroll.ScrollBarImageColor3 = COLOR_NEON_CYAN
	weaponScroll.CanvasSize = UDim2.fromOffset(0, #WEAPON_OPTIONS * 102)
	weaponScroll.Parent = mainPanel

	for idx, weapon in ipairs(WEAPON_OPTIONS) do
		local yOffset = (idx - 1) * 100
		local card = Instance.new("Frame")
		card.Name = weapon.Id .. "_Card"
		card.Position = UDim2.fromOffset(2, yOffset + 2)
		card.Size = UDim2.fromOffset(442, 92)
		card.Parent = weaponScroll
		local stroke = styleGlassPanel(card, COLOR_BORDER_IDLE, 1)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(14, 6)
		nameLabel.Size = UDim2.fromOffset(260, 20)
		nameLabel.Font = Enum.Font.Code
		nameLabel.Text = weapon.Title
		nameLabel.TextSize = 16
		nameLabel.TextColor3 = COLOR_TEXT_MAIN
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		local badge = Instance.new("TextLabel")
		badge.BackgroundTransparency = 1
		badge.Position = UDim2.new(1, -166, 0, 8)
		badge.Size = UDim2.fromOffset(152, 16)
		badge.Font = Enum.Font.Code
		badge.Text = "CLICK TO EQUIP"
		badge.TextSize = 11
		badge.TextColor3 = COLOR_TEXT_SUB
		badge.TextXAlignment = Enum.TextXAlignment.Right
		badge.Parent = card

		local classLabel = Instance.new("TextLabel")
		classLabel.BackgroundTransparency = 1
		classLabel.Position = UDim2.fromOffset(14, 26)
		classLabel.Size = UDim2.new(1, -28, 0, 14)
		classLabel.Font = Enum.Font.Code
		classLabel.Text = weapon.Class
		classLabel.TextSize = 10
		classLabel.TextColor3 = COLOR_NEON_CYAN
		classLabel.TextXAlignment = Enum.TextXAlignment.Left
		classLabel.Parent = card

		local statsLabel = Instance.new("TextLabel")
		statsLabel.BackgroundTransparency = 1
		statsLabel.Position = UDim2.fromOffset(14, 42)
		statsLabel.Size = UDim2.new(1, -28, 0, 16)
		statsLabel.Font = Enum.Font.Code
		statsLabel.Text = buildWeaponStatsText(weapon)
		statsLabel.TextSize = 11
		statsLabel.TextColor3 = COLOR_OVERDRIVE_ORANGE
		statsLabel.TextXAlignment = Enum.TextXAlignment.Left
		statsLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.BackgroundTransparency = 1
		descLabel.Position = UDim2.fromOffset(14, 60)
		descLabel.Size = UDim2.new(1, -28, 0, 28)
		descLabel.Font = Enum.Font.Code
		descLabel.Text = weapon.Description
		descLabel.TextWrapped = true
		descLabel.TextSize = 10
		descLabel.TextColor3 = COLOR_TEXT_SUB
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Parent = card

		local cardScale = Instance.new("UIScale")
		cardScale.Scale = 1.0
		cardScale.Parent = card

		local selectBtn = Instance.new("TextButton")
		selectBtn.Name = "Select_" .. weapon.Id
		selectBtn.Size = UDim2.fromScale(1, 1)
		selectBtn.BackgroundTransparency = 1
		selectBtn.Text = ""
		selectBtn.Parent = card

		-- @motionbykrit: Physical cards pop on hover and squash-overshoot on press
		selectBtn.MouseEnter:Connect(function()
			cardScale.Scale = 1.022
		end)
		selectBtn.MouseLeave:Connect(function()
			cardScale.Scale = 1.0
		end)
		selectBtn.MouseButton1Down:Connect(function()
			cardScale.Scale = 0.965
		end)
		selectBtn.MouseButton1Up:Connect(function()
			cardScale.Scale = 1.025
		end)

		selectBtn.Activated:Connect(function()
			selectedWeaponId = weapon.Id
			updateWeaponSelectionVisuals()
		end)

		weaponCardRefs[weapon.Id] = {
			Card = card,
			Stroke = stroke,
			Badge = badge,
			StatsLabel = statsLabel,
		}
	end

	-- =========================================================================
	-- RIGHT COLUMN: TOP SERVER B-HOP SPEED RECORDS & 240FPS MODE TOGGLE
	-- =========================================================================
	local recordsHeader = Instance.new("TextLabel")
	recordsHeader.Name = "RecordsHeader"
	recordsHeader.BackgroundTransparency = 1
	recordsHeader.Position = UDim2.fromOffset(496, 76)
	recordsHeader.Size = UDim2.fromOffset(300, 18)
	recordsHeader.Font = Enum.Font.Code
	recordsHeader.Text = "TOP SERVER B-HOP SPEED RECORDS"
	recordsHeader.TextSize = 13
	recordsHeader.TextColor3 = COLOR_TEXT_MAIN
	recordsHeader.TextXAlignment = Enum.TextXAlignment.Left
	recordsHeader.Parent = mainPanel

	local recordsCard = Instance.new("Frame")
	recordsCard.Name = "RecordsBoard"
	recordsCard.Position = UDim2.fromOffset(496, 100)
	recordsCard.Size = UDim2.fromOffset(300, 114)
	recordsCard.Parent = mainPanel
	styleGlassPanel(recordsCard, COLOR_BORDER_IDLE, 1)

	table.clear(recordRowLabels)
	for i = 1, 5 do
		local row = Instance.new("TextLabel")
		row.Name = string.format("RecordRow_%d", i)
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(14, 6 + (i - 1) * 20)
		row.Size = UDim2.new(1, -28, 0, 18)
		row.Font = Enum.Font.Code
		row.TextSize = 11
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Parent = recordsCard
		table.insert(recordRowLabels, row)
	end

	-- @yelik.dev Shop Psychology: 49 R$ Starter Pack + Decoy vs. Target Pro Pack + 100% Crate Odds
	local bundlesCard = Instance.new("Frame")
	bundlesCard.Name = "ShopPsychologyBundlesCard"
	bundlesCard.Position = UDim2.fromOffset(496, 220)
	bundlesCard.Size = UDim2.fromOffset(300, 82)
	bundlesCard.Parent = mainPanel
	styleGlassPanel(bundlesCard, COLOR_OVERDRIVE_ORANGE, 1)

	local starterLine = Instance.new("TextLabel")
	starterLine.Name = "StarterPackLine"
	starterLine.BackgroundTransparency = 1
	starterLine.Position = UDim2.fromOffset(10, 6)
	starterLine.Size = UDim2.new(1, -20, 0, 16)
	starterLine.Font = Enum.Font.Code
	starterLine.Text = "[49 R$] STARTER PACK: +1500 FLUX + OVERDRIVE AURA"
	starterLine.TextSize = 10
	starterLine.TextColor3 = COLOR_NEON_CYAN
	starterLine.TextXAlignment = Enum.TextXAlignment.Left
	starterLine.Parent = bundlesCard

	local decoyVsTargetLine = Instance.new("TextLabel")
	decoyVsTargetLine.Name = "DecoyVsTargetLine"
	decoyVsTargetLine.BackgroundTransparency = 1
	decoyVsTargetLine.Position = UDim2.fromOffset(10, 24)
	decoyVsTargetLine.Size = UDim2.new(1, -20, 0, 30)
	decoyVsTargetLine.Font = Enum.Font.Code
	decoyVsTargetLine.Text = "STANDARD x3 [349 R$]  vs  PRO VAULT x10 [399 R$ // BEST VALUE 3.3X]"
	decoyVsTargetLine.TextWrapped = true
	decoyVsTargetLine.TextSize = 10
	decoyVsTargetLine.TextColor3 = COLOR_OVERDRIVE_ORANGE
	decoyVsTargetLine.TextXAlignment = Enum.TextXAlignment.Left
	decoyVsTargetLine.Parent = bundlesCard

	local oddsDisclosureLine = Instance.new("TextLabel")
	oddsDisclosureLine.Name = "CrateOddsDisclosure"
	oddsDisclosureLine.BackgroundTransparency = 1
	oddsDisclosureLine.Position = UDim2.fromOffset(10, 58)
	oddsDisclosureLine.Size = UDim2.new(1, -20, 0, 18)
	oddsDisclosureLine.Font = Enum.Font.Code
	oddsDisclosureLine.Text = "ODDS (100%): GOLD 5% | VOID 15% | HYPERION 30% | MIL 50%"
	oddsDisclosureLine.TextSize = 9
	oddsDisclosureLine.TextColor3 = COLOR_TEXT_SUB
	oddsDisclosureLine.TextXAlignment = Enum.TextXAlignment.Left
	oddsDisclosureLine.Parent = bundlesCard

	-- Competitive 240FPS Mode Toggle Button
	local fpsToggleBtn = Instance.new("TextButton")
	fpsToggleBtn.Name = "Competitive240Toggle"
	fpsToggleBtn.Position = UDim2.fromOffset(496, 308)
	fpsToggleBtn.Size = UDim2.fromOffset(300, 48)
	fpsToggleBtn.AutoButtonColor = false
	fpsToggleBtn.Text = ""
	fpsToggleBtn.Parent = mainPanel
	toggleStrokeRef = styleGlassPanel(fpsToggleBtn, COLOR_BORDER_IDLE, 1)

	local toggleTitle = Instance.new("TextLabel")
	toggleTitle.Name = "ToggleTitle"
	toggleTitle.BackgroundTransparency = 1
	toggleTitle.Position = UDim2.fromOffset(14, 8)
	toggleTitle.Size = UDim2.new(1, -28, 0, 20)
	toggleTitle.Font = Enum.Font.Code
	toggleTitle.Text = "Competitive 240FPS Mode: OFF"
	toggleTitle.TextSize = 14
	toggleTitle.TextColor3 = COLOR_TEXT_MAIN
	toggleTitle.TextXAlignment = Enum.TextXAlignment.Left
	toggleTitle.Parent = fpsToggleBtn
	toggleStateLabelRef = toggleTitle

	local toggleDesc = Instance.new("TextLabel")
	toggleDesc.Name = "ToggleSubtitle"
	toggleDesc.BackgroundTransparency = 1
	toggleDesc.Position = UDim2.fromOffset(14, 29)
	toggleDesc.Size = UDim2.new(1, -28, 0, 16)
	toggleDesc.Font = Enum.Font.Code
	toggleDesc.Text = "STRIPS POST-FX & SHADOWS FOR MINIMAL FRAME LATENCY"
	toggleDesc.TextSize = 10
	toggleDesc.TextColor3 = COLOR_TEXT_SUB
	toggleDesc.TextXAlignment = Enum.TextXAlignment.Left
	toggleDesc.Parent = fpsToggleBtn

	fpsToggleBtn.Activated:Connect(function()
		applyCompetitiveMode(not competitive240Mode)
	end)

	-- =========================================================================
	-- BOTTOM ACTIONS: DEPLOY TO ARENA & RETURN TO SKY ISLAND LOBBY
	-- =========================================================================
	local deployBtn = Instance.new("TextButton")
	deployBtn.Name = "DeployToArenaButton"
	deployBtn.Position = UDim2.fromOffset(24, 376)
	deployBtn.Size = UDim2.fromOffset(510, 66)
	deployBtn.BackgroundColor3 = Color3.fromRGB(12, 28, 38)
	deployBtn.BackgroundTransparency = 0.15
	deployBtn.Font = Enum.Font.Code
	deployBtn.Text = "DEPLOY TO PHANTOM MIDWAY 5v5"
	deployBtn.TextSize = 20
	deployBtn.TextColor3 = COLOR_NEON_CYAN
	deployBtn.Parent = mainPanel

	local deployCorner = Instance.new("UICorner")
	deployCorner.CornerRadius = UDim.new(0, 6)
	deployCorner.Parent = deployBtn

	local deployStroke = Instance.new("UIStroke")
	deployStroke.Color = COLOR_NEON_CYAN
	deployStroke.Thickness = 2
	deployStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	deployStroke.Parent = deployBtn

	deployBtn.MouseEnter:Connect(function()
		deployStroke.Color = COLOR_OVERDRIVE_ORANGE
		deployBtn.TextColor3 = COLOR_OVERDRIVE_ORANGE
	end)

	deployBtn.MouseLeave:Connect(function()
		deployStroke.Color = COLOR_NEON_CYAN
		deployBtn.TextColor3 = COLOR_NEON_CYAN
	end)

	deployBtn.Activated:Connect(handleDeployClicked)
	deployBtnRef = deployBtn

	local returnLobbyBtn = Instance.new("TextButton")
	returnLobbyBtn.Name = "ReturnToLobbyButton"
	returnLobbyBtn.Position = UDim2.fromOffset(546, 376)
	returnLobbyBtn.Size = UDim2.fromOffset(250, 66)
	returnLobbyBtn.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	returnLobbyBtn.BackgroundTransparency = 0.15
	returnLobbyBtn.Font = Enum.Font.Code
	returnLobbyBtn.Text = "SKY ISLAND LOBBY"
	returnLobbyBtn.TextSize = 18
	returnLobbyBtn.TextColor3 = COLOR_OVERDRIVE_ORANGE
	returnLobbyBtn.Parent = mainPanel

	local returnCorner = Instance.new("UICorner")
	returnCorner.CornerRadius = UDim.new(0, 6)
	returnCorner.Parent = returnLobbyBtn

	local returnStroke = Instance.new("UIStroke")
	returnStroke.Color = COLOR_OVERDRIVE_ORANGE
	returnStroke.Thickness = 1.5
	returnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	returnStroke.Parent = returnLobbyBtn

	returnLobbyBtn.Activated:Connect(function()
		manualOverlayOpen = false
		syncLobbyState()
		local requestDeploy = ReplicatedStorage:WaitForChild("RequestDeploy", 5)
		if requestDeploy and requestDeploy:IsA("RemoteEvent") then
			requestDeploy:FireServer("RETURN_TO_LOBBY")
		end
	end)

	-- Keybind (M or B) to toggle Loadout & Deploy overlay in both Lobby and Arena
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.B then
			manualOverlayOpen = not manualOverlayOpen
			syncLobbyState()
		end
	end)

	-- Initialize defaults & bind reactive listeners
	updateWeaponSelectionVisuals()
	applyCompetitiveMode(false)
	refreshSpeedRecords()

	LocalPlayer:GetAttributeChangedSignal("InArena"):Connect(function()
		if LocalPlayer:GetAttribute("InArena") == true then
			manualOverlayOpen = false
		end
		syncLobbyState()
	end)
	LocalPlayer:GetAttributeChangedSignal("ArmorPoints"):Connect(refreshEconomySubtitle)
	LocalPlayer:GetAttributeChangedSignal("MatchCredits"):Connect(refreshEconomySubtitle)

	if EconomyClient and type(EconomyClient.OnStateChanged) == "table" then
		table.insert(EconomyClient.OnStateChanged, function()
			refreshEconomySubtitle()
		end)
	end

	syncLobbyState()

	RunService.Heartbeat:Connect(function()
		if lobbyGui and lobbyGui.Enabled then
			refreshSpeedRecords()
		elseif type(MovementController) == "table" and type(MovementController.CurrentPlanarSpeed) == "number" then
			if MovementController.CurrentPlanarSpeed > localPeakSpeed then
				localPeakSpeed = MovementController.CurrentPlanarSpeed
			end
		end
	end)
end

return LobbyApp
