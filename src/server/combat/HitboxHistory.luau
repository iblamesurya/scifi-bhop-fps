--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local HitboxHistory = {}

type Snapshot = {
	time: number,
	parts: { [BasePart]: { cf: CFrame, anchored: boolean } },
}

local playerHistories: { [Player]: { Snapshot } } = {}
local MAX_HISTORY_DURATION = 1.0 -- 1 second
local MAX_REWIND = 0.45 -- 450ms max rewind

function HitboxHistory.Init()
	RunService.Heartbeat:Connect(function(dt)
		local now = workspace:GetServerTimeNow()

		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				if not playerHistories[player] then
					playerHistories[player] = {}
				end

				local partsMap = {}
				for _, desc in ipairs(character:GetDescendants()) do
					if desc:IsA("BasePart") then
						partsMap[desc] = {
							cf = desc.CFrame,
							anchored = desc.Anchored,
						}
					end
				end

				local history = playerHistories[player]
				table.insert(history, {
					time = now,
					parts = partsMap,
				})

				-- Prune snapshots older than 1.0 second
				while #history > 0 and (now - history[1].time) > MAX_HISTORY_DURATION do
					table.remove(history, 1)
				end
			else
				playerHistories[player] = nil
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerHistories[player] = nil
	end)
end

function HitboxHistory.RewindToTimestamp(shooter: Player, targetTimestamp: number): () -> ()
	local now = workspace:GetServerTimeNow()
	local minAllowedTime = now - MAX_REWIND
	targetTimestamp = math.clamp(targetTimestamp, minAllowedTime, now)

	local originalStates: { [BasePart]: { cf: CFrame, anchored: boolean } } = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= shooter then
			local character = player.Character
			if character then
				local history = playerHistories[player]
				if history and #history > 0 then
					local s1, s2
					for i = 1, #history - 1 do
						if history[i].time <= targetTimestamp and history[i + 1].time >= targetTimestamp then
							s1 = history[i]
							s2 = history[i + 1]
							break
						end
					end

					local targetPartsState = nil
					if s1 and s2 then
						local alpha = 0
						if s2.time > s1.time then
							alpha = (targetTimestamp - s1.time) / (s2.time - s1.time)
						end
						targetPartsState = {}
						for part, data1 in pairs(s1.parts) do
							local data2 = s2.parts[part]
							if data2 and part.Parent then
								originalStates[part] = { cf = part.CFrame, anchored = part.Anchored }
								targetPartsState[part] = {
									cf = data1.cf:Lerp(data2.cf, alpha),
									anchored = true,
								}
							end
						end
					else
						-- Fallback to nearest snapshot
						local nearest = history[1]
						local minDiff = math.abs(nearest.time - targetTimestamp)
						for i = 2, #history do
							local diff = math.abs(history[i].time - targetTimestamp)
							if diff < minDiff then
								minDiff = diff
								nearest = history[i]
							end
						end
						if nearest then
							targetPartsState = nearest.parts
						end
					end

					if targetPartsState then
						for part, state in pairs(targetPartsState) do
							if part.Parent then
								if not originalStates[part] then
									originalStates[part] = { cf = part.CFrame, anchored = part.Anchored }
								end
								part.CFrame = state.cf
								part.Anchored = state.anchored
							end
						end
					end
				end
			end
		end
	end

	local restored = false
	local function restoreFn()
		if restored then
			return
		end
		restored = true
		for part, state in pairs(originalStates) do
			if part.Parent then
				part.CFrame = state.cf
				part.Anchored = state.anchored
			end
		end
	end

	return restoreFn
end

return HitboxHistory