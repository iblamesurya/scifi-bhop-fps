--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local StanceReplicator = {}

local stanceSyncEvent: UnreliableRemoteEvent
local lastSyncTimes: { [Player]: number } = {}
local RATE_LIMIT_INTERVAL = 1 / 30 -- 30Hz rate limit

function StanceReplicator.Init()
	stanceSyncEvent = ReplicatedStorage:FindFirstChild("StanceSyncBuffer") :: UnreliableRemoteEvent
	if not stanceSyncEvent then
		stanceSyncEvent = Instance.new("UnreliableRemoteEvent")
		stanceSyncEvent.Name = "StanceSyncBuffer"
		stanceSyncEvent.Parent = ReplicatedStorage
	end

	stanceSyncEvent.OnServerEvent:Connect(function(sender: Player, packetBuffer: buffer)
		if typeof(packetBuffer) ~= "buffer" then
			return
		end

		if buffer.len(packetBuffer) < 5 then
			return
		end

		local now = Workspace:GetServerTimeNow()
		local lastTime = lastSyncTimes[sender] or 0
		if (now - lastTime) < RATE_LIMIT_INTERVAL then
			return
		end

		local success, pitch, isSliding = pcall(function()
			local p = buffer.readf32(packetBuffer, 0)
			local s = buffer.readu8(packetBuffer, 4)
			return p, s
		end)

		if not success or pitch == nil or isSliding == nil then
			return
		end

		-- Validate pitch is finite and within bounds
		if pitch ~= pitch or math.abs(pitch) == math.huge then
			return
		end
		if math.abs(pitch) > math.pi * 0.55 then
			return
		end

		lastSyncTimes[sender] = now

		-- Broadcast stance buffer to all other clients
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= sender then
				stanceSyncEvent:FireClient(player, sender, packetBuffer)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSyncTimes[player] = nil
	end)
end

return StanceReplicator
