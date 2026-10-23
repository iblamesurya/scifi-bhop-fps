--!strict
--[[
	LobbyApp.luau
	Sleek glassmorphic sci-fi pre-spawn Lobby / Loadout overlay.
	- Active when LocalPlayer:GetAttribute("InArena") ~= true
	- Weapon selection: VORTEX_SMG or HELIOS_RAIL
	- "Competitive 240FPS Mode" toggle
	- Live Top Server B-Hop Speed Records board
	- "DEPLOY TO ARENA" button firing ReplicatedStorage:WaitForChild("RequestDeploy"):FireServer(selectedWeaponId)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local clientRoot = script.Parent.Parent

local MovementController = require(clientRoot:WaitForChild("movement"):WaitForChild("MovementController")) :: any

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
	StatsText: string,
	Description: string,
}

local WEAPON_OPTIONS: { WeaponOption } = {
	{
		Id = "VORTEX_SMG",
		Title = "VORTEX_SMG",
		Class = "PLASMA SUBMACHINE GUN // CQC-VELOCITY",
		StatsText = "DMG: 18 (32 HS)  |  ROF: 900 RPM  |  MAG: 36",
		Description = "High-cadence plasma repeater engineered for aggressive mid-air tracking at 45+ studs/s.",
	},
	{
		Id = "HELIOS_RAIL",
		Title = "HELIOS_RAIL",
		Class = "LINEAR ACCELERATOR RAILGUN // PRECISION",
		StatsText = "DMG: 75 (150 HS) |  ROF: 75 RPM   |  MAG: 05",
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
local selectedWeaponId = "VORTEX_SMG"
local competitive240Mode = false
local localPeakSpeed = 0.0

local weaponCardRefs: { [string]: { Card: Frame, Stroke: UIStroke, Badge: TextLabel } } = {}
local recordRowLabels: { TextLabel } = {}
local toggleStrokeRef: UIStroke? = nil
local toggleStateLabelRef: TextLabel? = nil

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
	for id, refs in pairs(weaponCardRefs) do
		local isSelected = (id == selectedWeaponId)
		refs.Stroke.Color = if isSelected then COLOR_NEON_CYAN else COLOR_BORDER_IDLE
		refs.Stroke.Thickness = if isSelected then 2 else 1
		refs.Card.BackgroundTransparency = if isSelected then 0.2 else CARD_TRANSPARENCY
		refs.Badge.Text = if isSelected then "SELECTED // ACTIVE" else "CLICK TO EQUIP"
		refs.Badge.TextColor3 = if isSelected then COLOR_NEON_CYAN else COLOR_TEXT_SUB
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
		local attrSpeed = player:GetAttribute("PeakSpeed")
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

local function handleDeployClicked()
	local requestDeploy = ReplicatedStorage:WaitForChild("RequestDeploy", 5)
	if requestDeploy and requestDeploy:IsA("RemoteEvent") then
		requestDeploy:FireServer(selectedWeaponId)
	end
end

local function syncLobbyState()
	local inArena = LocalPlayer:GetAttribute("InArena") == true
	local showLobby = not inArena

	if lobbyGui then
		lobbyGui.Enabled = showLobby
	end

	if showLobby then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		refreshSpeedRecords()
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
	subtitleLabel.Text = "SELECT PRIMARY ARMAMENT, CONFIGURE 240HZ PIPELINE, AND DEPLOY TO ARENA"
	subtitleLabel.TextSize = 12
	subtitleLabel.TextColor3 = COLOR_TEXT_SUB
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = mainPanel

	-- =========================================================================
	-- LEFT COLUMN: PRIMARY WEAPON SELECTION (VORTEX_SMG / HELIOS_RAIL)
	-- =========================================================================
	local loadoutHeader = Instance.new("TextLabel")
	loadoutHeader.Name = "LoadoutHeader"
	loadoutHeader.BackgroundTransparency = 1
	loadoutHeader.Position = UDim2.fromOffset(24, 76)
	loadoutHeader.Size = UDim2.fromOffset(440, 18)
	loadoutHeader.Font = Enum.Font.Code
	loadoutHeader.Text = "PRIMARY WEAPON SELECT"
	loadoutHeader.TextSize = 13
	loadoutHeader.TextColor3 = COLOR_TEXT_MAIN
	loadoutHeader.TextXAlignment = Enum.TextXAlignment.Left
	loadoutHeader.Parent = mainPanel

	for idx, weapon in ipairs(WEAPON_OPTIONS) do
		local yOffset = 100 + (idx - 1) * 130
		local card = Instance.new("Frame")
		card.Name = weapon.Id .. "_Card"
		card.Position = UDim2.fromOffset(24, yOffset)
		card.Size = UDim2.fromOffset(450, 118)
		card.Parent = mainPanel
		local stroke = styleGlassPanel(card, COLOR_BORDER_IDLE, 1)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(16, 10)
		nameLabel.Size = UDim2.fromOffset(240, 22)
		nameLabel.Font = Enum.Font.Code
		nameLabel.Text = weapon.Title
		nameLabel.TextSize = 18
		nameLabel.TextColor3 = COLOR_TEXT_MAIN
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		local badge = Instance.new("TextLabel")
		badge.BackgroundTransparency = 1
		badge.Position = UDim2.new(1, -176, 0, 12)
		badge.Size = UDim2.fromOffset(160, 18)
		badge.Font = Enum.Font.Code
		badge.Text = "CLICK TO EQUIP"
		badge.TextSize = 12
		badge.TextColor3 = COLOR_TEXT_SUB
		badge.TextXAlignment = Enum.TextXAlignment.Right
		badge.Parent = card

		local classLabel = Instance.new("TextLabel")
		classLabel.BackgroundTransparency = 1
		classLabel.Position = UDim2.fromOffset(16, 34)
		classLabel.Size = UDim2.new(1, -32, 0, 16)
		classLabel.Font = Enum.Font.Code
		classLabel.Text = weapon.Class
		classLabel.TextSize = 11
		classLabel.TextColor3 = COLOR_NEON_CYAN
		classLabel.TextXAlignment = Enum.TextXAlignment.Left
		classLabel.Parent = card

		local statsLabel = Instance.new("TextLabel")
		statsLabel.BackgroundTransparency = 1
		statsLabel.Position = UDim2.fromOffset(16, 54)
		statsLabel.Size = UDim2.new(1, -32, 0, 18)
		statsLabel.Font = Enum.Font.Code
		statsLabel.Text = weapon.StatsText
		statsLabel.TextSize = 12
		statsLabel.TextColor3 = COLOR_OVERDRIVE_ORANGE
		statsLabel.TextXAlignment = Enum.TextXAlignment.Left
		statsLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.BackgroundTransparency = 1
		descLabel.Position = UDim2.fromOffset(16, 76)
		descLabel.Size = UDim2.new(1, -32, 0, 32)
		descLabel.Font = Enum.Font.Code
		descLabel.Text = weapon.Description
		descLabel.TextWrapped = true
		descLabel.TextSize = 11
		descLabel.TextColor3 = COLOR_TEXT_SUB
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Parent = card

		local selectBtn = Instance.new("TextButton")
		selectBtn.Name = "Select_" .. weapon.Id
		selectBtn.Size = UDim2.fromScale(1, 1)
		selectBtn.BackgroundTransparency = 1
		selectBtn.Text = ""
		selectBtn.Parent = card

		selectBtn.Activated:Connect(function()
			selectedWeaponId = weapon.Id
			updateWeaponSelectionVisuals()
		end)

		weaponCardRefs[weapon.Id] = {
			Card = card,
			Stroke = stroke,
			Badge = badge,
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
	recordsCard.Size = UDim2.fromOffset(300, 180)
	recordsCard.Parent = mainPanel
	styleGlassPanel(recordsCard, COLOR_BORDER_IDLE, 1)

	table.clear(recordRowLabels)
	for i = 1, 5 do
		local row = Instance.new("TextLabel")
		row.Name = string.format("RecordRow_%d", i)
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(14, 12 + (i - 1) * 31)
		row.Size = UDim2.new(1, -28, 0, 24)
		row.Font = Enum.Font.Code
		row.TextSize = 13
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Parent = recordsCard
		table.insert(recordRowLabels, row)
	end

	-- Competitive 240FPS Mode Toggle Button
	local fpsToggleBtn = Instance.new("TextButton")
	fpsToggleBtn.Name = "Competitive240Toggle"
	fpsToggleBtn.Position = UDim2.fromOffset(496, 294)
	fpsToggleBtn.Size = UDim2.fromOffset(300, 54)
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
	-- BOTTOM ACTION: DEPLOY TO ARENA BUTTON
	-- =========================================================================
	local deployBtn = Instance.new("TextButton")
	deployBtn.Name = "DeployToArenaButton"
	deployBtn.Position = UDim2.fromOffset(24, 376)
	deployBtn.Size = UDim2.fromOffset(772, 66)
	deployBtn.BackgroundColor3 = Color3.fromRGB(12, 28, 38)
	deployBtn.BackgroundTransparency = 0.15
	deployBtn.Font = Enum.Font.Code
	deployBtn.Text = "DEPLOY TO ARENA"
	deployBtn.TextSize = 22
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

	-- Initialize defaults & bind reactive listeners
	updateWeaponSelectionVisuals()
	applyCompetitiveMode(false)
	refreshSpeedRecords()

	LocalPlayer:GetAttributeChangedSignal("InArena"):Connect(syncLobbyState)
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