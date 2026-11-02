--!strict

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
if localPlayer then
	localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
end

local function requireClientModule(moduleName: string, directPath: Instance?): any
	if directPath and directPath:IsA("ModuleScript") then
		return require(directPath)
	end

	local found = script:FindFirstChild(moduleName, true)
	if found and found:IsA("ModuleScript") then
		return require(found)
	end

	error(`[ClientBootstrap] Missing required client module: {moduleName}`)
end

local TracerPool = requireClientModule("TracerPool", script.combat:FindFirstChild("TracerPool"))
local SlideController = requireClientModule("SlideController", script.movement:FindFirstChild("SlideController"))
local MovementController = requireClientModule(
	"MovementController",
	script.movement:FindFirstChild("MovementController")
)
local ViewmodelController = requireClientModule(
	"ViewmodelController",
	script.viewmodel:FindFirstChild("ViewmodelController")
)
local WeaponController = requireClientModule("WeaponController", script.combat:FindFirstChild("WeaponController"))
local GraphicsController = requireClientModule(
	"GraphicsController",
	script.graphics:FindFirstChild("GraphicsController")
)
local VFXController = requireClientModule("VFXController", script.graphics:FindFirstChild("VFXController"))
local PhantomMidwayClient = requireClientModule(
	"PhantomMidway_ClientController",
	script.graphics:FindFirstChild("PhantomMidway_ClientController")
)
local AudioController = requireClientModule("AudioController", script.audio:FindFirstChild("AudioController"))
local EconomyClient = requireClientModule("EconomyClient", script.combat:FindFirstChild("EconomyClient"))
local HudApp = requireClientModule("HudApp", script.ui:FindFirstChild("HudApp"))
local LobbyApp = requireClientModule("LobbyApp", script.ui:FindFirstChild("LobbyApp"))

local function safeClientInit(name: string, mod: any)
	if type(mod) == "table" and type(mod.Init) == "function" then
		task.spawn(function()
			local ok, err = pcall(mod.Init)
			if not ok then
				warn(`[ClientBootstrap] {name}.Init() failed: {tostring(err)}`)
			end
		end)
	end
end

safeClientInit("TracerPool", TracerPool)
safeClientInit("SlideController", SlideController)
safeClientInit("MovementController", MovementController)
safeClientInit("GraphicsController", GraphicsController)
safeClientInit("VFXController", VFXController)
safeClientInit("PhantomMidway_ClientController", PhantomMidwayClient)
safeClientInit("AudioController", AudioController)
safeClientInit("ViewmodelController", ViewmodelController)
safeClientInit("WeaponController", WeaponController)
safeClientInit("EconomyClient", EconomyClient)
safeClientInit("HudApp", HudApp)
safeClientInit("LobbyApp", LobbyApp)
