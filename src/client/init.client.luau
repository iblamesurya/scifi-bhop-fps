--!strict

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
local AudioController = requireClientModule("AudioController", script.audio:FindFirstChild("AudioController"))
local HudApp = requireClientModule("HudApp", script.ui:FindFirstChild("HudApp"))
local LobbyApp = requireClientModule("LobbyApp", script.ui:FindFirstChild("LobbyApp"))

TracerPool.Init()
SlideController.Init()
MovementController.Init()
ViewmodelController.Init()
WeaponController.Init()
GraphicsController.Init()
VFXController.Init()
AudioController.Init()
HudApp.Init()
LobbyApp.Init()
