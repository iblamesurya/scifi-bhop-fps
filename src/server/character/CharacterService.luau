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

	-- @yelik.dev Social Proof: Visible Overdrive Aura on character Torso/Root
	local torso: BasePart? = (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or hrp) :: BasePart?
	if torso and not torso:FindFirstChild("OverdriveSocialProofAura") then
		local auraAtt = Instance.new("Attachment")
		auraAtt.Name = "OverdriveSocialProofAura"
		auraAtt.Parent = torso

		local auraEmitter = Instance.new("ParticleEmitter")
		auraEmitter.Name = "OverdriveAuraParticles"
		auraEmitter.Color = ColorSequence.new(Color3.fromRGB(0, 240, 255), Color3.fromRGB(255, 110, 0))
		auraEmitter.LightEmission = 1
		auraEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28),
			NumberSequenceKeypoint.new(1, 0),
		})
		auraEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		auraEmitter.Lifetime = NumberRange.new(0.35, 0.65)
		auraEmitter.Rate = 14
		auraEmitter.Speed = NumberRange.new(1.5, 3.5)
		auraEmitter.SpreadAngle = Vector2.new(180, 180)
		auraEmitter.Parent = auraAtt
	end
end

return CharacterService
