--!strict
-- 60Hz 1-second circular buffer of player part CFrames for lag compensation

local Players = game:GetService("Players")

local BUFFER_SIZE: number = 60

export type PlayerCFrameMap = { [string]: CFrame }
export type Snapshot = {
	Timestamp: number,
	PlayerCFrames: { [Player]: PlayerCFrameMap },
}

local HitboxHistory = {}

local ringBuffer: { Snapshot } = table.create(BUFFER_SIZE)
local writeIndex: number = 1
local snapshotCount: number = 0

-- Temporary storage for restoring CFrames after rewind
local restoreCache: { [Player]: PlayerCFrameMap } = {}

function HitboxHistory.recordSnapshot(): ()
	local snapshot: Snapshot = {
		Timestamp = workspace:GetServerTimeNow(),
		PlayerCFrames = {},
	}

	for _, player: Player in Players:GetPlayers() do
		local character: Model? = player.Character
		if not character then
			continue
		end
		local cframes: PlayerCFrameMap = {}
		for _, part: Instance in character:GetChildren() do
			if part:IsA("BasePart") then
				cframes[part.Name] = part.CFrame
			end
		end
		snapshot.PlayerCFrames[player] = cframes
	end

	ringBuffer[writeIndex] = snapshot
	writeIndex = (writeIndex % BUFFER_SIZE) + 1
	if snapshotCount < BUFFER_SIZE then
		snapshotCount += 1
	end
end

function HitboxHistory.getSnapshot(timestamp: number): Snapshot?
	if snapshotCount == 0 then
		return nil
	end

	local bestSnapshot: Snapshot? = nil
	local bestDelta: number = math.huge

	for i = 1, snapshotCount do
		local snap: Snapshot = ringBuffer[i]
		local delta: number = math.abs(snap.Timestamp - timestamp)
		if delta < bestDelta then
			bestDelta = delta
			bestSnapshot = snap
		end
	end

	return bestSnapshot
end

function HitboxHistory.rewindPlayer(player: Player, snapshot: Snapshot): ()
	local character: Model? = player.Character
	if not character then
		return
	end

	local historicalCFrames: PlayerCFrameMap? = snapshot.PlayerCFrames[player]
	if not historicalCFrames then
		return
	end

	-- Save current CFrames for restoration
	local currentCFrames: PlayerCFrameMap = {}
	for _, part: Instance in character:GetChildren() do
		if part:IsA("BasePart") then
			currentCFrames[part.Name] = part.CFrame
		end
	end
	restoreCache[player] = currentCFrames

	-- Apply historical CFrames
	for _, part: Instance in character:GetChildren() do
		if part:IsA("BasePart") then
			local historicalCF: CFrame? = historicalCFrames[part.Name]
			if historicalCF then
				(part :: BasePart).CFrame = historicalCF
			end
		end
	end
end

function HitboxHistory.restorePlayer(player: Player): ()
	local character: Model? = player.Character
	if not character then
		restoreCache[player] = nil
		return
	end

	local savedCFrames: PlayerCFrameMap? = restoreCache[player]
	if not savedCFrames then
		return
	end

	for _, part: Instance in character:GetChildren() do
		if part:IsA("BasePart") then
			local savedCF: CFrame? = savedCFrames[part.Name]
			if savedCF then
				(part :: BasePart).CFrame = savedCF
			end
		end
	end

	restoreCache[player] = nil
end

return HitboxHistory
