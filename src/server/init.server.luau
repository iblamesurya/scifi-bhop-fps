--!strict

local function requireServerModule(moduleName: string, directPath: Instance?): any
	if directPath and directPath:IsA("ModuleScript") then
		return require(directPath)
	end

	local found = script:FindFirstChild(moduleName, true)
	if found and found:IsA("ModuleScript") then
		return require(found)
	end

	error(`[ServerBootstrap] Missing required server module: {moduleName}`)
end

local ArenaGenerator = requireServerModule("ArenaGenerator")
local HitboxHistory = requireServerModule(
	"HitboxHistory",
	if script:FindFirstChild("combat") then script.combat:FindFirstChild("HitboxHistory") else nil
)
local CombatValidator = requireServerModule(
	"CombatValidator",
	if script:FindFirstChild("combat") then script.combat:FindFirstChild("CombatValidator") else nil
)
local StanceReplicator = requireServerModule(
	"StanceReplicator",
	if script:FindFirstChild("replication") then script.replication:FindFirstChild("StanceReplicator") else nil
)
local MatchService = requireServerModule(
	"MatchService",
	if script:FindFirstChild("match") then script.match:FindFirstChild("MatchService") else nil
)

ArenaGenerator.Init()
HitboxHistory.Init()
CombatValidator.Init()
StanceReplicator.Init()
MatchService.Init()
