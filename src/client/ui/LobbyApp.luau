--!strict
--[[
	LobbyApp.luau
	Minimalist sci-fi glassmorphic Lobby deployment UI.
	Allows weapon selection and arena deployment via RequestDeploy RemoteEvent.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local BG_COLOR = Color3.fromRGB(10, 14, 20)
local PANEL_BG = Color3.fromRGB(16, 22, 34)
local ACCENT_CYAN = Color3.fromHex("#00F0FF")
local ACCENT_ORANGE = Color3.fromHex("#FF6E00")
local TEXT_MUTED = Color3.fromRGB(160, 185, 215)

local AVAILABLE_WEAPONS = {
	{ Id = "VORTEX_SMG", Name = "VX-9 VORTEX SMG", Desc = "650 RPM • Full-Auto • High Mobility" },
	{ Id = "HELIOS_RAIL", Name = "HELIOS LINEAR RAILGUN", Desc = "55 RPM • 80 DMG • 2.0x Headshot" },
	{ Id = "PulseRifle", Name = "VX-9 PULSE RIFLE", Desc = "650 RPM • Automatic Energy Rifle" },
	{ Id = "PlasmaShotgun", Name = "NOVA SCATTERGUN", Desc = "9 Pellets • Close-Range Devastation" },
}

local LobbyApp = {}

local isInitialized = false
local lobbyGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local selectedWeaponId: string = "VORTEX_SMG"
local weaponButtons: { [string]: TextButton } = {}

local function getRequestDeployRemote(): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild("RequestDeploy")
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	return ReplicatedStorage:WaitForChild("RequestDeploy", 10) :: RemoteEvent
end

function LobbyApp.SetVisible(visible: boolean): ()
	if not mainFrame then
		return
	end
	mainFrame.Visible = visible
end

function LobbyApp.Init(): ()
	if isInitialized then
		return
	end
	isInitialized = true

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "SciFiLobbyUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Parent = playerGui
	lobbyGui = gui

	local container = Instance.new("Frame")
	container.Name = "LobbyContainer"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = gui
	mainFrame = container

	-- Center Deployment Modal
	local modal = Instance.new("Frame")
	modal.Name = "DeployModal"
	modal.Size = UDim2.fromOffset(460, 480)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = BG_COLOR
	modal.BackgroundTransparency = 0.25
	modal.BorderSizePixel = 0
	modal.Parent = container

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 10)
	modalCorner.Parent = modal

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = ACCENT_CYAN
	modalStroke.Thickness = 1.5
	modalStroke.Transparency = 0.2
	modalStroke.Parent = modal

	-- Header Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Position = UDim2.new(0, 0, 0, 16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.TextSize = 24
	title.TextColor3 = ACCENT_CYAN
	title.Text = "SCI-FI BHOP ARENA"
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = modal

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, 0, 0, 24)
	subtitle.Position = UDim2.new(0, 0, 0, 56)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Code
	subtitle.TextSize = 13
	subtitle.TextColor3 = TEXT_MUTED
	subtitle.Text = "SELECT LOADOUT & DEPLOY"
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.Parent = modal

	-- Loadout Container
	local loadoutList = Instance.new("Frame")
	loadoutList.Name = "LoadoutList"
	loadoutList.Size = UDim2.new(1, -48, 0, 260)
	loadoutList.Position = UDim2.new(0, 24, 0, 96)
	loadoutList.BackgroundTransparency = 1
	loadoutList.Parent = modal

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = loadoutList

	for index, weapon in ipairs(AVAILABLE_WEAPONS) do
		local btn = Instance.new("TextButton")
		btn.Name = `Weapon_{weapon.Id}`
		btn.Size = UDim2.new(1, 0, 0, 52)
		btn.BackgroundColor3 = PANEL_BG
		btn.BackgroundTransparency = 0.35
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.LayoutOrder = index
		btn.Parent = loadoutList

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = if weapon.Id == selectedWeaponId then ACCENT_ORANGE else ACCENT_CYAN
		btnStroke.Thickness = if weapon.Id == selectedWeaponId then 1.5 else 1
		btnStroke.Transparency = if weapon.Id == selectedWeaponId then 0.1 else 0.6
		btnStroke.Parent = btn

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "WeaponName"
		nameLabel.Size = UDim2.new(1, -20, 0, 22)
		nameLabel.Position = UDim2.new(0, 12, 0, 6)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.Code
		nameLabel.TextSize = 15
		nameLabel.TextColor3 = if weapon.Id == selectedWeaponId then ACCENT_ORANGE else Color3.new(1, 1, 1)
		nameLabel.Text = weapon.Name
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = btn

		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "WeaponDesc"
		descLabel.Size = UDim2.new(1, -20, 0, 16)
		descLabel.Position = UDim2.new(0, 12, 0, 28)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.Code
		descLabel.TextSize = 11
		descLabel.TextColor3 = TEXT_MUTED
		descLabel.Text = weapon.Desc
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = btn

		weaponButtons[weapon.Id] = btn

		btn.MouseButton1Click:Connect(function()
			selectedWeaponId = weapon.Id
			for wId, otherBtn in weaponButtons do
				local s = otherBtn:FindFirstChildOfClass("UIStroke")
				local n = otherBtn:FindFirstChild("WeaponName") :: TextLabel?
				if s then
					s.Color = if wId == selectedWeaponId then ACCENT_ORANGE else ACCENT_CYAN
					s.Thickness = if wId == selectedWeaponId then 1.5 else 1
					s.Transparency = if wId == selectedWeaponId then 0.1 else 0.6
				end
				if n then
					n.TextColor3 = if wId == selectedWeaponId then ACCENT_ORANGE else Color3.new(1, 1, 1)
				end
			end
		end)
	end

	-- Deploy Button
	local deployBtn = Instance.new("TextButton")
	deployBtn.Name = "DeployButton"
	deployBtn.Size = UDim2.new(1, -48, 0, 48)
	deployBtn.Position = UDim2.new(0, 24, 1, -72)
	deployBtn.BackgroundColor3 = ACCENT_CYAN
	deployBtn.BorderSizePixel = 0
	deployBtn.AutoButtonColor = true
	deployBtn.Font = Enum.Font.Code
	deployBtn.TextSize = 18
	deployBtn.TextColor3 = Color3.fromRGB(8, 12, 18)
	deployBtn.Text = "DEPLOY TO ARENA"
	deployBtn.Parent = modal

	local deployCorner = Instance.new("UICorner")
	deployCorner.CornerRadius = UDim.new(0, 6)
	deployCorner.Parent = deployBtn

	deployBtn.MouseButton1Click:Connect(function()
		local remote = getRequestDeployRemote()
		if remote then
			remote:FireServer(selectedWeaponId)
		end
		LocalPlayer:SetAttribute("SelectedWeapon", selectedWeaponId)
		LocalPlayer:SetAttribute("InArena", true)
		LobbyApp.SetVisible(false)
	end)

	local function updateVisibility()
		local inArena = LocalPlayer:GetAttribute("InArena") == true
		LobbyApp.SetVisible(not inArena)
	end

	LocalPlayer:GetAttributeChangedSignal("InArena"):Connect(updateVisibility)
	updateVisibility()
end

LobbyApp.init = LobbyApp.Init

return table.freeze(LobbyApp)
