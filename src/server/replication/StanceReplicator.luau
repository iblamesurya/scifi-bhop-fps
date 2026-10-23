--!strict
-- UnreliableRemoteEvent buffer sync for 3P look pitch and slide state

local Players = game:GetService("Players")

local StanceReplicator = {}

local STANCE_PACKET_SIZE: number = 5
local MAX_PACKETS_PER_SECOND: number = 60
local lastPacketTime: { [Player]: number } = {}

function StanceReplicator.init(stanceEvent: UnreliableRemoteEvent): ()
	stanceEvent.OnServerEvent:Connect(function(player: Player, packet: any): ()
		-- Validate buffer
		if typeof(packet) ~= "buffer" or buffer.len(packet) ~= STANCE_PACKET_SIZE then
			return
		end

		-- Rate limit: max 60 packets/sec per player
		local now: number = workspace:GetServerTimeNow()
		local lastTime: number? = lastPacketTime[player]
		if lastTime and (now - lastTime) < (1 / MAX_PACKETS_PER_SECOND) then
			return
		end
		lastPacketTime[player] = now

		-- Broadcast to all other players
		for _, otherPlayer: Player in Players:GetPlayers() do
			if otherPlayer ~= player then
				stanceEvent:FireClient(otherPlayer, player, packet)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player): ()
		lastPacketTime[player] = nil
	end)
end

return StanceReplicator
