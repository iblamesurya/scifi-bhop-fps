--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StanceReplicator = {}

local stanceSyncEvent: UnreliableRemoteEvent

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

		local success = pcall(function()
			_ = buffer.readF32(packetBuffer, 0)
			_ = buffer.readU8(packetBuffer, 4)
		end)

		if not success then
			return
		end

		-- Broadcast stance buffer to all other clients
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= sender then
				stanceSyncEvent:FireClient(player, sender, packetBuffer)
			end
		end
	end)
end

return StanceReplicator