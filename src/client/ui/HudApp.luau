--!strict
-- Minimalist sci-fi glassmorphic HUD and STUDS/S telemetry

local Players = game:GetService("Players")

local HudApp = {}

local NEON_CYAN: Color3 = Color3.fromHex("00F0FF")
local OVERDRIVE_ORANGE: Color3 = Color3.fromHex("FF6E00")
local BG_COLOR: Color3 = Color3.fromRGB(10, 14, 20)
local BG_TRANSPARENCY: number = 0.35
local OVERDRIVE_THRESHOLD: number = 45

local screenGui: ScreenGui? = nil
local speedLabel: TextLabel? = nil
local ammoLabel: TextLabel? = nil
local healthBar: Frame? = nil
local speedBar: Frame? = nil
local speedStroke: UIStroke? = nil

function HudApp.init(): ()
	local player: Player = Players.LocalPlayer
	local gui: ScreenGui = Instance.new("ScreenGui")
	gui.Name = "SciFiHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player.PlayerGui
	screenGui = gui

	-- Speed telemetry panel (bottom-center)
	local speedPanel: Frame = Instance.new("Frame")
	speedPanel.Name = "SpeedPanel"
	speedPanel.Size = UDim2.fromOffset(220, 50)
	speedPanel.Position = UDim2.new(0.5, -110, 1, -70)
	speedPanel.BackgroundColor3 = BG_COLOR
	speedPanel.BackgroundTransparency = BG_TRANSPARENCY
	speedPanel.BorderSizePixel = 0
	speedPanel.Parent = gui

	local panelCorner: UICorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 6)
	panelCorner.Parent = speedPanel

	local stroke: UIStroke = Instance.new("UIStroke")
	stroke.Color = NEON_CYAN
	stroke.Thickness = 1
	stroke.Transparency = 0.3
	stroke.Parent = speedPanel
	speedStroke = stroke

	local sLabel: TextLabel = Instance.new("TextLabel")
	sLabel.Name = "SpeedLabel"
	sLabel.Size = UDim2.fromScale(1, 1)
	sLabel.BackgroundTransparency = 1
	sLabel.Font = Enum.Font.Code
	sLabel.TextSize = 22
	sLabel.TextColor3 = NEON_CYAN
	sLabel.Text = "0.0 STUDS/S"
	sLabel.TextXAlignment = Enum.TextXAlignment.Center
	sLabel.Parent = speedPanel
	speedLabel = sLabel

	-- Speed fill bar
	local sBar: Frame = Instance.new("Frame")
	sBar.Name = "SpeedBar"
	sBar.Size = UDim2.new(0, 0, 0, 3)
	sBar.Position = UDim2.new(0, 0, 1, -3)
	sBar.BackgroundColor3 = NEON_CYAN
	sBar.BorderSizePixel = 0
	sBar.Parent = speedPanel
	speedBar = sBar

	-- Ammo counter (bottom-right)
	local ammoPanel: Frame = Instance.new("Frame")
	ammoPanel.Name = "AmmoPanel"
	ammoPanel.Size = UDim2.fromOffset(140, 50)
	ammoPanel.Position = UDim2.new(1, -160, 1, -70)
	ammoPanel.BackgroundColor3 = BG_COLOR
	ammoPanel.BackgroundTransparency = BG_TRANSPARENCY
	ammoPanel.BorderSizePixel = 0
	ammoPanel.Parent = gui

	local ammoCorner: UICorner = Instance.new("UICorner")
	ammoCorner.CornerRadius = UDim.new(0, 6)
	ammoCorner.Parent = ammoPanel

	local ammoStroke: UIStroke = Instance.new("UIStroke")
	ammoStroke.Color = NEON_CYAN
	ammoStroke.Thickness = 1
	ammoStroke.Transparency = 0.3
	ammoStroke.Parent = ammoPanel

	local aLabel: TextLabel = Instance.new("TextLabel")
	aLabel.Name = "AmmoLabel"
	aLabel.Size = UDim2.fromScale(1, 1)
	aLabel.BackgroundTransparency = 1
	aLabel.Font = Enum.Font.Code
	aLabel.TextSize = 26
	aLabel.TextColor3 = NEON_CYAN
	aLabel.Text = "30"
	aLabel.TextXAlignment = Enum.TextXAlignment.Center
	aLabel.Parent = ammoPanel
	ammoLabel = aLabel

	-- Health bar (bottom-left)
	local healthPanel: Frame = Instance.new("Frame")
	healthPanel.Name = "HealthPanel"
	healthPanel.Size = UDim2.fromOffset(200, 8)
	healthPanel.Position = UDim2.new(0, 20, 1, -40)
	healthPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	healthPanel.BackgroundTransparency = 0.4
	healthPanel.BorderSizePixel = 0
	healthPanel.Parent = gui

	local healthCorner: UICorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 4)
	healthCorner.Parent = healthPanel

	local hBar: Frame = Instance.new("Frame")
	hBar.Name = "HealthFill"
	hBar.Size = UDim2.fromScale(1, 1)
	hBar.BackgroundColor3 = NEON_CYAN
	hBar.BorderSizePixel = 0
	hBar.Parent = healthPanel
	healthBar = hBar

	local hCorner: UICorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 4)
	hCorner.Parent = hBar
end

function HudApp.update(speed: number, ammo: number, health: number, maxHealth: number): ()
	-- Speed display with overdrive color shift
	local isOverdrive: boolean = speed > OVERDRIVE_THRESHOLD
	local accentColor: Color3 = if isOverdrive then OVERDRIVE_ORANGE else NEON_CYAN

	if speedLabel then
		speedLabel.Text = string.format("%.1f STUDS/S", speed)
		speedLabel.TextColor3 = accentColor
	end

	if speedBar then
		local ratio: number = math.clamp(speed / 85, 0, 1)
		speedBar.Size = UDim2.new(ratio, 0, 0, 3)
		speedBar.BackgroundColor3 = accentColor
	end

	if speedStroke then
		speedStroke.Color = accentColor
	end

	-- Ammo
	if ammoLabel then
		ammoLabel.Text = tostring(ammo)
	end

	-- Health
	if healthBar then
		healthBar.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
	end
end

return HudApp
