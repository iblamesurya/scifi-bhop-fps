--!strict
-- Spawns players into custom R6 rig and disables default Roblox state braking

local Players = game:GetService("Players")

local CharacterService = {}

function CharacterService.init(): ()
	Players.PlayerAdded:Connect(function(player: Player): ()
		CharacterService.onPlayerAdded(player)
	end)

	-- Handle players already in game (late server script load)
	for _, player: Player in Players:GetPlayers() do
		task.spawn(function(): ()
			CharacterService.onPlayerAdded(player)
		end)
	end
end

function CharacterService.onPlayerAdded(player: Player): ()
	player.CharacterAdded:Connect(function(character: Model): ()
		CharacterService.setupCharacter(player, character)
	end)

	-- Load initial character
	if not player.Character then
		player:LoadCharacter()
	else
		CharacterService.setupCharacter(player, player.Character)
	end
end

function CharacterService.setupCharacter(_player: Player, character: Model): ()
	local humanoid: Humanoid? = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	-- Disable default Roblox movement state machine (movement is 100% custom)
	humanoid.EvaluateStateMachine = false

	-- Zero out default WalkSpeed so Humanoid doesn't fight our custom velocity
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	-- Disable auto-rotation (camera-driven rotation is handled client-side)
	humanoid.AutoRotate = false

	-- Ensure the HumanoidRootPart isn't anchored
	local hrp: BasePart? = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = false
	end
end

return CharacterService
