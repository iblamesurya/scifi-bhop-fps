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
local EconomyManager = requireServerModule(
	"EconomyManager",
	if script:FindFirstChild("economy") then script.economy:FindFirstChild("EconomyManager") else nil
)

local function safeInit(name: string, mod: any)
	if type(mod) == "table" and type(mod.Init) == "function" then
		task.spawn(function()
			local ok, err = pcall(mod.Init)
			if not ok then
				warn(`[ServerBootstrap] {name}.Init() failed: {tostring(err)}`)
			end
		end)
	end
end

-- Initialize network remotes & combat/match services first so client WaitForChilds never hang
safeInit("HitboxHistory", HitboxHistory)
safeInit("CombatValidator", CombatValidator)
safeInit("StanceReplicator", StanceReplicator)
safeInit("EconomyManager", EconomyManager)
safeInit("ArenaGenerator", ArenaGenerator)
safeInit("MatchService", MatchService)
