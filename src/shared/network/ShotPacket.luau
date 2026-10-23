--!strict
--[[
	ShotPacket.luau
	28-byte binary buffer serializer and deserializer for client-to-server hitscan fire packets.

	Byte Layout (28 bytes total, little-endian):
	  [0..7]   f64 : timestamp (Workspace:GetServerTimeNow())
	  [8..11]  f32 : origin.X
	  [12..15] f32 : origin.Y
	  [16..19] f32 : origin.Z
	  [20..23] f32 : pitch (radians, clamped to [-pi/2, pi/2])
	  [24..27] f32 : yaw   (radians)
]]

local PACKET_SIZE = 28
local HALF_PI = math.pi * 0.5

export type ShotData = {
	Timestamp: number,
	Origin: Vector3,
	Pitch: number,
	Yaw: number,
}

local ShotPacket = {
	PACKET_SIZE = PACKET_SIZE,
}

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function ShotPacket.Encode(timestamp: number, origin: Vector3, pitch: number, yaw: number): buffer
	local buf = buffer.create(PACKET_SIZE)

	buffer.writef64(buf, 0, timestamp)
	buffer.writef32(buf, 8, origin.X)
	buffer.writef32(buf, 12, origin.Y)
	buffer.writef32(buf, 16, origin.Z)
	buffer.writef32(buf, 20, pitch)
	buffer.writef32(buf, 24, yaw)

	return buf
end

ShotPacket.write = ShotPacket.Encode

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

function ShotPacket.Decode(buf: buffer): (boolean, number, Vector3, Vector3)
	if typeof(buf) ~= "buffer" or buffer.len(buf) ~= PACKET_SIZE then
		return false, 0, Vector3.zero, Vector3.zAxis
	end

	local timestamp = buffer.readf64(buf, 0)
	local ox = buffer.readf32(buf, 8)
	local oy = buffer.readf32(buf, 12)
	local oz = buffer.readf32(buf, 16)
	local pitch = buffer.readf32(buf, 20)
	local yaw = buffer.readf32(buf, 24)

	if
		not isFinite(timestamp)
		or not isFinite(ox)
		or not isFinite(oy)
		or not isFinite(oz)
		or not isFinite(pitch)
		or not isFinite(yaw)
	then
		return false, 0, Vector3.zero, Vector3.zAxis
	end

	local clampedPitch = math.clamp(pitch, -HALF_PI, HALF_PI)
	local origin = Vector3.new(ox, oy, oz)

	-- Reconstruct unit LookVector from pitch (X-axis rotation) and yaw (Y-axis rotation)
	local cosPitch = math.cos(clampedPitch)
	local lookDir = Vector3.new(
		-math.sin(yaw) * cosPitch,
		math.sin(clampedPitch),
		-math.cos(yaw) * cosPitch
	)

	local lookVector = if lookDir.Magnitude > 1e-6 then lookDir.Unit else -Vector3.zAxis
	return true, timestamp, origin, lookVector
end

return table.freeze(ShotPacket)
