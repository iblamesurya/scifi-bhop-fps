--!strict
-- Velocity-reactive dynamic crosshair reticle

local Players = game:GetService("Players")

local CrosshairModule = {}

local NEON_CYAN: Color3 = Color3.fromHex("00F0FF")
local OVERDRIVE_ORANGE: Color3 = Color3.fromHex("FF6E00")
local OVERDRIVE_THRESHOLD: number = 45

local LINE_LENGTH: number = 12
local LINE_THICKNESS: number = 2
local BASE_GAP: number = 6
local MAX_GAP: number = 28
local GAP_SPEED_SCALE: number = 0.3

local container: Frame? = nil
local lines: { Frame } = {}

function CrosshairModule.init(): ()
	local player: Player = Players.LocalPlayer
	local gui: ScreenGui = Instance.new("ScreenGui")
	gui.Name = "CrosshairGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player.PlayerGui

	local frame: Frame = Instance.new("Frame")
	frame.Name = "Crosshair"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	container = frame

	-- Create 4 crosshair lines: top, bottom, left, right
	local directions: { { number } } = {
		{ 0, -1 },  -- top
		{ 0, 1 },   -- bottom
		{ -1, 0 },  -- left
		{ 1, 0 },   -- right
	}

	for i, dir: { number } in directions do
		local line: Frame = Instance.new("Frame")
		line.Name = `Line_{i}`
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = NEON_CYAN
		line.BorderSizePixel = 0
		line.Parent = frame

		if dir[1] == 0 then
			-- Vertical line (top/bottom)
			line.Size = UDim2.fromOffset(LINE_THICKNESS, LINE_LENGTH)
		else
			-- Horizontal line (left/right)
			line.Size = UDim2.fromOffset(LINE_LENGTH, LINE_THICKNESS)
		end

		lines[i] = line
	end
end

function CrosshairModule.update(speed: number, isFiring: boolean, isADS: boolean): ()
	if not container then
		return
	end

	-- Hide during ADS
	container.Visible = not isADS

	-- Calculate dynamic gap
	local speedGap: number = speed * GAP_SPEED_SCALE
	local fireGap: number = if isFiring then 8 else 0
	local gap: number = math.clamp(BASE_GAP + speedGap + fireGap, BASE_GAP, MAX_GAP)

	-- Color shift
	local isOverdrive: boolean = speed > OVERDRIVE_THRESHOLD
	local color: Color3 = if isOverdrive then OVERDRIVE_ORANGE else NEON_CYAN

	local directions: { { number } } = {
		{ 0, -1 },
		{ 0, 1 },
		{ -1, 0 },
		{ 1, 0 },
	}

	for i, dir: { number } in directions do
		local line: Frame? = lines[i]
		if line then
			local offset: number = gap + LINE_LENGTH / 2
			line.Position = UDim2.new(0.5, dir[1] * offset, 0.5, dir[2] * offset)
			line.BackgroundColor3 = color
		end
	end
end

return CrosshairModule
