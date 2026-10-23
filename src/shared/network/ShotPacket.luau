--!strict
-- 28-byte binary buffer serializer/deserializer for shot packets

local ShotPacket = {}

export type ShotData = {
	Timestamp: number,
	Origin: Vector3,
	Pitch: number,
	Yaw: number,
}

local PACKET_SIZE: number = 28

function ShotPacket.write(timestamp: number, origin: Vector3, pitch: number, yaw: number): buffer
	local buf: buffer = buffer.create(PACKET_SIZE)
	buffer.writef64(buf, 0, timestamp)
	buffer.writef32(buf, 8, origin.X)
	buffer.writef32(buf, 12, origin.Y)
	buffer.writef32(buf, 16, origin.Z)
	buffer.writef32(buf, 20, pitch)
	buffer.writef32(buf, 24, yaw)
	return buf
end

function ShotPacket.read(buf: buffer): ShotData
	assert(buffer.len(buf) == PACKET_SIZE, "ShotPacket: invalid buffer length")
	local timestamp: number = buffer.readf64(buf, 0)
	local ox: number = buffer.readf32(buf, 8)
	local oy: number = buffer.readf32(buf, 12)
	local oz: number = buffer.readf32(buf, 16)
	local pitch: number = buffer.readf32(buf, 20)
	local yaw: number = buffer.readf32(buf, 24)
	return {
		Timestamp = timestamp,
		Origin = Vector3.new(ox, oy, oz),
		Pitch = pitch,
		Yaw = yaw,
	}
end

function ShotPacket.validate(buf: buffer): boolean
	return typeof(buf) == "buffer" and buffer.len(buf) == PACKET_SIZE
end

return ShotPacket
