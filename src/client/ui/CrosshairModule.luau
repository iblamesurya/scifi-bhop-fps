--!strict
--[[
	CrosshairModule.luau
	Minimalist 4-bracket + center dot velocity-reactive sci-fi reticle.
	Dynamically expands with MovementController.CurrentPlanarSpeed, tightens during
	ViewmodelController.IsADS(), and flashes Neon Cyan (body) or Neon Orange/Red (headshot).
]]

local RunService = game:GetService("RunService")

local clientRoot = script.Parent.Parent
local MovementController = require(clientRoot:WaitForChild("movement"):WaitForChild("MovementController")) :: any
local ViewmodelController = require(clientRoot:WaitForChild("viewmodel"):WaitForChild("ViewmodelController")) :: any

local CrosshairModule = {}

-- Visual & Telemetry Constants
local BASE_GAP_PX = 8
local ADS_GAP_MULTIPLIER = 0.42
local SPEED_TO_GAP_FACTOR = 0.35
local MAX_SPEED_GAP_ADDITION = 28
local GAP_LERP_SPEED = 18

local BRACKET_LENGTH = 8
local BRACKET_THICKNESS = 2
local HIT_FLASH_DURATION = 0.18

local COLOR_DEFAULT = Color3.fromRGB(225, 248, 255)
local COLOR_ADS = Color3.fromRGB(0, 240, 255)
local COLOR_HIT_BODY = Color3.fromRGB(0, 240, 255) -- #00F0FF Neon Cyan
local COLOR_HIT_HEAD = Color3.fromRGB(255, 78, 0) -- #FF4E00 Neon Orange/Red
local COLOR_STROKE = Color3.fromRGB(10, 14, 20)

-- Internal State
local isInitialized = false
local rootFrame: Frame? = nil
local centerDot: Frame? = nil
local topBracket: Frame? = nil
local bottomBracket: Frame? = nil
local leftBracket: Frame? = nil
local rightBracket: Frame? = nil
local hitTicks: { Frame } = {}

local currentGap = BASE_GAP_PX
local hitFlashRemaining = 0
local lastHitHeadshot = false
local renderConnection: RBXScriptConnection? = nil

local function createBracket(name: string, parent: GuiObject, size: UDim2): Frame
	local bracket = Instance.new("Frame")
	bracket.Name = name
	bracket.AnchorPoint = Vector2.new(0.5, 0.5)
	bracket.Position = UDim2.fromScale(0.5, 0.5)
	bracket.Size = size
	bracket.BackgroundColor3 = COLOR_DEFAULT
	bracket.BorderSizePixel = 0
	bracket.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_STROKE
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = bracket

	return bracket
end

local function createHitTick(index: number, rotationDeg: number, parent: GuiObject): Frame
	local holder = Instance.new("Frame")
	holder.Name = string.format("HitTick_%d", index)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(2, 7)
	holder.Rotation = rotationDeg
	holder.BackgroundColor3 = COLOR_HIT_BODY
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Parent = parent

	return holder
end

local function readPlanarSpeed(): number
	if type(MovementController) == "table" then
		if type(MovementController.CurrentPlanarSpeed) == "number" then
			return MovementController.CurrentPlanarSpeed
		elseif type(MovementController.GetPlanarSpeed) == "function" then
			local ok, val = pcall(MovementController.GetPlanarSpeed)
			if ok and type(val) == "number" then
				return val
			end
		end
	end
	return 0
end

local function readIsADS(): boolean
	if type(ViewmodelController) == "table" then
		if type(ViewmodelController.IsADS) == "function" then
			local ok, result = pcall(ViewmodelController.IsADS)
			if ok and type(result) == "boolean" then
				return result
			end
		elseif type(ViewmodelController.IsADS) == "boolean" then
			return ViewmodelController.IsADS
		end
	end
	return false
end

local function updateReticle(dt: number)
	local root = rootFrame
	local dot = centerDot
	local topB = topBracket
	local bottomB = bottomBracket
	local leftB = leftBracket
	local rightB = rightBracket

	if not (root and dot and topB and bottomB and leftB and rightB) then
		return
	end

	local speed = readPlanarSpeed()
	local isAds = readIsADS()

	local speedSpread = math.clamp(speed * SPEED_TO_GAP_FACTOR, 0, MAX_SPEED_GAP_ADDITION)
	local targetGap = BASE_GAP_PX + speedSpread
	if isAds then
		targetGap = math.max(3, targetGap * ADS_GAP_MULTIPLIER)
	end

	local alpha = math.clamp(dt * GAP_LERP_SPEED, 0, 1)
	currentGap = currentGap + (targetGap - currentGap) * alpha

	local activeColor = if isAds then COLOR_ADS else COLOR_DEFAULT
	local hitExpand = 0

	if hitFlashRemaining > 0 then
		hitFlashRemaining = math.max(0, hitFlashRemaining - dt)
		local flashRatio = hitFlashRemaining / HIT_FLASH_DURATION
		local flashColor = if lastHitHeadshot then COLOR_HIT_HEAD else COLOR_HIT_BODY
		activeColor = activeColor:Lerp(flashColor, flashRatio)
		hitExpand = flashRatio * (if lastHitHeadshot then 5 else 3)

		local tickDist = 10 + flashRatio * 4
		for i, tick in ipairs(hitTicks) do
			local angleRad = math.rad((i - 1) * 90 + 45)
			local ox = math.cos(angleRad) * tickDist
			local oy = math.sin(angleRad) * tickDist
			tick.Position = UDim2.new(0.5, math.round(ox), 0.5, math.round(oy))
			tick.BackgroundColor3 = flashColor
			tick.BackgroundTransparency = 1 - flashRatio
		end
	else
		for _, tick in ipairs(hitTicks) do
			tick.BackgroundTransparency = 1
		end
	end

	local finalGap = math.round(currentGap + hitExpand)

	dot.BackgroundColor3 = activeColor
	topB.BackgroundColor3 = activeColor
	bottomB.BackgroundColor3 = activeColor
	leftB.BackgroundColor3 = activeColor
	rightB.BackgroundColor3 = activeColor

	topB.Position = UDim2.new(0.5, 0, 0.5, -(finalGap + BRACKET_LENGTH * 0.5))
	bottomB.Position = UDim2.new(0.5, 0, 0.5, finalGap + BRACKET_LENGTH * 0.5)
	leftB.Position = UDim2.new(0.5, -(finalGap + BRACKET_LENGTH * 0.5), 0.5, 0)
	rightB.Position = UDim2.new(0.5, finalGap + BRACKET_LENGTH * 0.5, 0.5, 0)
end

function CrosshairModule.Init(parentGui: ScreenGui)
	if isInitialized then
		if rootFrame and parentGui then
			rootFrame.Parent = parentGui
		end
		return
	end
	isInitialized = true

	local container = Instance.new("Frame")
	container.Name = "CrosshairContainer"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.fromOffset(120, 120)
	container.BackgroundTransparency = 1
	container.Parent = parentGui
	rootFrame = container

	-- Center Dot (2x2 px)
	local dot = Instance.new("Frame")
	dot.Name = "CenterDot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(2, 2)
	dot.BackgroundColor3 = COLOR_DEFAULT
	dot.BorderSizePixel = 0
	dot.Parent = container

	local dotStroke = Instance.new("UIStroke")
	dotStroke.Color = COLOR_STROKE
	dotStroke.Thickness = 1
	dotStroke.Transparency = 0.35
	dotStroke.Parent = dot
	centerDot = dot

	-- 4 Minimalist Sci-Fi Brackets
	topBracket = createBracket("TopBracket", container, UDim2.fromOffset(BRACKET_THICKNESS, BRACKET_LENGTH))
	bottomBracket = createBracket("BottomBracket", container, UDim2.fromOffset(BRACKET_THICKNESS, BRACKET_LENGTH))
	leftBracket = createBracket("LeftBracket", container, UDim2.fromOffset(BRACKET_LENGTH, BRACKET_THICKNESS))
	rightBracket = createBracket("RightBracket", container, UDim2.fromOffset(BRACKET_LENGTH, BRACKET_THICKNESS))

	-- 4 Diagonal Hitmarker Ticks
	table.clear(hitTicks)
	for i = 1, 4 do
		local rot = (i - 1) * 90 + 45
		table.insert(hitTicks, createHitTick(i, rot, container))
	end

	if renderConnection then
		renderConnection:Disconnect()
	end
	renderConnection = RunService.RenderStepped:Connect(updateReticle)
end

function CrosshairModule.TriggerHitmarker(isHeadshot: boolean)
	lastHitHeadshot = isHeadshot == true
	hitFlashRemaining = HIT_FLASH_DURATION
	currentGap = currentGap + (if lastHitHeadshot then 4 else 2)
end

return CrosshairModule
