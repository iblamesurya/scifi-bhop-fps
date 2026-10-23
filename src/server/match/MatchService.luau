--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local WeaponData = require(Configs:WaitForChild("WeaponData")) :: any

local ServerRoot = script.Parent.Parent

local function resolveArenaGenerator(): any
	local moduleInstance = ServerRoot:FindFirstChild("ArenaGenerator", true)
	if moduleInstance and moduleInstance:IsA("ModuleScript") then
		local ok, result = pcall(require, moduleInstance)
		if ok and type(result) == "table" then
			return result
		end
	end

	return {
		Init = function() end,
		GetLobbySpawn = function(): CFrame
			return CFrame.new(0, 50, 0)
		end,
		GetRandomArenaSpawn = function(): CFrame
			return CFrame.new(0, 10, 0)
		end,
	}
end

local function resolveOptionalService(serviceName: string): any
	local moduleInstance = ServerRoot:FindFirstChild(serviceName, true)
	if moduleInstance and moduleInstance:IsA("ModuleScript") then
		local ok, result = pcall(require, moduleInstance)
		if ok and type(result) == "table" then
			return result
		end
	end
	return nil
end

local ArenaGenerator = resolveArenaGenerator()
local CharacterService = resolveOptionalService("CharacterService")
local LoadoutService = resolveOptionalService("LoadoutService")

local DEFAULT_WEAPON_ID = "VORTEX_SMG"
local RESPAWN_DELAY = 3.0
local REQUEST_DEPLOY_EVENT_NAME = "RequestDeploy"

local MatchService = {}

local isInitialized = false
local requestDeployEvent: RemoteEvent? = nil
local characterConnections: { [Player]: { RBXScriptConnection } } = {}
local respawnThreads: { [Player]: thread } = {}

local function isValidWeaponId(weaponId: unknown): boolean
	if type(weaponId) ~= "string" or weaponId == "" then
		return false
	end

	if type(WeaponData) == "table" then
		if type(WeaponData[weaponId]) == "table" then
			return true
		end
		if type(WeaponData.Weapons) == "table" and type(WeaponData.Weapons[weaponId]) == "table" then
			return true
		end
		if type(WeaponData.GetWeapon) == "function" then
			local ok, data = pcall(WeaponData.GetWeapon, weaponId)
			if ok and type(data) == "table" then
				return true
			end
		end
	end

	return weaponId == "VORTEX_SMG" or weaponId == "HELIOS_RAIL"
end

local function toSpawnCFrame(spawnTarget: any): CFrame
	if typeof(spawnTarget) == "CFrame" then
		return spawnTarget
	elseif typeof(spawnTarget) == "Vector3" then
		return CFrame.new(spawnTarget)
	elseif typeof(spawnTarget) == "Instance" and spawnTarget:IsA("BasePart") then
		return spawnTarget.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(0, 12, 0)
end

local function getLobbySpawnCFrame(): CFrame
	if type(ArenaGenerator) == "table" and type(ArenaGenerator.GetLobbySpawn) == "function" then
		local ok, result = pcall(ArenaGenerator.GetLobbySpawn)
		if ok and result ~= nil then
			return toSpawnCFrame(result)
		end
	end
	return CFrame.new(0, 50, 0)
end

local function getArenaSpawnCFrame(): CFrame
	if type(ArenaGenerator) == "table" and type(ArenaGenerator.GetRandomArenaSpawn) == "function" then
		local ok, result = pcall(ArenaGenerator.GetRandomArenaSpawn)
		if ok and result ~= nil then
			return toSpawnCFrame(result)
		end
	end
	return CFrame.new(0, 10, 0)
end

local function teleportCharacterTo(character: Model, targetCFrame: CFrame)
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.CFrame = targetCFrame
	else
		character:PivotTo(targetCFrame)
	end
end

local function cleanupPlayerConnections(player: Player)
	local conns = characterConnections[player]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		characterConnections[player] = nil
	end
end

local function cancelPendingRespawn(player: Player)
	local activeThread = respawnThreads[player]
	if activeThread then
		pcall(task.cancel, activeThread)
		respawnThreads[player] = nil
	end
end

local function initPlayerAttributes(player: Player)
	if player:GetAttribute("InArena") == nil then
		player:SetAttribute("InArena", false)
	end
	if player:GetAttribute("SelectedWeapon") == nil then
		player:SetAttribute("SelectedWeapon", DEFAULT_WEAPON_ID)
	end
	if player:GetAttribute("Kills") == nil then
		player:SetAttribute("Kills", 0)
	end
	if player:GetAttribute("Deaths") == nil then
		player:SetAttribute("Deaths", 0)
	end
	if player:GetAttribute("TopBhopSpeed") == nil then
		player:SetAttribute("TopBhopSpeed", 0)
	end
end

local function applyLoadout(player: Player, weaponId: string)
	if type(LoadoutService) == "table" then
		local equipFn = LoadoutService.EquipWeapon or LoadoutService.GiveWeapon or LoadoutService.AssignLoadout
		if type(equipFn) == "function" then
			pcall(equipFn, player, weaponId)
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	cleanupPlayerConnections(player)
	local conns: { RBXScriptConnection } = {}
	characterConnections[player] = conns

	if type(CharacterService) == "table" then
		local setupFn = CharacterService.SetupCharacter or CharacterService.OnCharacterAdded
		if type(setupFn) == "function" then
			pcall(setupFn, player, character)
		end
	end

	task.defer(function()
		if not character.Parent then
			return
		end
		local inArena = player:GetAttribute("InArena") == true
		local targetCFrame = if inArena then getArenaSpawnCFrame() else getLobbySpawnCFrame()
		teleportCharacterTo(character, targetCFrame)

		if inArena then
			local weaponId = (player:GetAttribute("SelectedWeapon") :: string?) or DEFAULT_WEAPON_ID
			applyLoadout(player, weaponId)
		end
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		table.insert(
			conns,
			humanoid.Died:Connect(function()
				local currentDeaths = (player:GetAttribute("Deaths") :: number?) or 0
				player:SetAttribute("Deaths", currentDeaths + 1)

				cancelPendingRespawn(player)
				respawnThreads[player] = task.delay(RESPAWN_DELAY, function()
					respawnThreads[player] = nil
					if player.Parent ~= Players then
						return
					end

					player:LoadCharacter()
					local newCharacter = player.Character
					if newCharacter then
						local inArena = player:GetAttribute("InArena") == true
						local spawnCFrame = if inArena then getArenaSpawnCFrame() else getLobbySpawnCFrame()
						teleportCharacterTo(newCharacter, spawnCFrame)
					end
				end)
			end)
		)
	end
end

local function onPlayerAdded(player: Player)
	initPlayerAttributes(player)
	player:SetAttribute("InArena", false)

	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	else
		task.defer(function()
			if player.Parent == Players and not player.Character then
				player:LoadCharacter()
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	cancelPendingRespawn(player)
	cleanupPlayerConnections(player)
end

local function onRequestDeploy(player: Player, weaponId: unknown)
	if not isValidWeaponId(weaponId) then
		return
	end

	local validWeapon = weaponId :: string
	initPlayerAttributes(player)
	player:SetAttribute("SelectedWeapon", validWeapon)
	player:SetAttribute("InArena", true)

	cancelPendingRespawn(player)

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not humanoid or humanoid.Health <= 0 then
		player:LoadCharacter()
		character = player.Character
	end

	if character then
		teleportCharacterTo(character, getArenaSpawnCFrame())
		applyLoadout(player, validWeapon)
	end
end

local function updateTopBhopSpeeds()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if rootPart and rootPart:IsA("BasePart") then
			local velocity = rootPart.AssemblyLinearVelocity
			local horizontalSpeed = math.round(Vector3.new(velocity.X, 0, velocity.Z).Magnitude * 10) / 10
			local currentTop = (player:GetAttribute("TopBhopSpeed") :: number?) or 0
			if horizontalSpeed > currentTop then
				player:SetAttribute("TopBhopSpeed", horizontalSpeed)
			end
		end
	end
end

function MatchService.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	local existingRemote = ReplicatedStorage:FindFirstChild(REQUEST_DEPLOY_EVENT_NAME)
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		requestDeployEvent = existingRemote
	else
		local newRemote = Instance.new("RemoteEvent")
		newRemote.Name = REQUEST_DEPLOY_EVENT_NAME
		newRemote.Parent = ReplicatedStorage
		requestDeployEvent = newRemote
	end

	(requestDeployEvent :: RemoteEvent).OnServerEvent:Connect(onRequestDeploy)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	RunService.Heartbeat:Connect(updateTopBhopSpeeds)
end

return table.freeze(MatchService)
