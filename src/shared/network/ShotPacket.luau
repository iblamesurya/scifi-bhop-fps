--!strict
--[[
	ShotPacket.luau
	28-byte binary buffer serializer and deserializer for client-to-server hitscan fire packets.

	Byte Layout (28 bytes total, little-endian):
	  [0..7]   f64 : timestamp (workspace:GetServerTimeNow())
	  [8..11]  f32 : origin.X
	  [12..15] f32 : origin.Y
	  [16..19] f32 : origin.Z
	  [20..23] f32 : pitch (radians, clamped to [-pi/2, pi/2])
	  [24..27] f32 : yaw   (radians)
]]

local Workspace = game:GetService("Workspace")

local PACKET_SIZE = 28
local HALF_PI = math.pi * 0.5

export type DecodedShotPacket = {
	Timestamp: number,
	Origin: Vector3,
	Direction: Vector3,
	Pitch: number,
	Yaw: number,
}

local ShotPacket = {
	PACKET_SIZE = PACKET_SIZE,
}

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function ShotPacket.DirectionToPitchYaw(dir: Vector3): (number, number)
	local unitDir = if dir.Magnitude > 1e-6 then dir.Unit else -Vector3.zAxis
	local pitch = math.asin(math.clamp(unitDir.Y, -1, 1))
	local yaw = math.atan2(-unitDir.X, -unitDir.Z)
	return pitch, yaw
end

--[[
	Supports both calling conventions without throwing:
	1. ShotPacket.Encode(timestamp: number, origin: Vector3, pitch: number, yaw: number): buffer
	2. Overload for table or (origin: Vector3, direction: Vector3, timestamp: number?, weaponId: number?)
]]
function ShotPacket.Encode(a: any, b: any?, c: any?, d: any?): buffer
	local timestamp: number = 0
	local origin: Vector3 = Vector3.zero
	local pitch: number = 0
	local yaw: number = 0

	if type(a) == "table" then
		local tbl = a :: { [string]: any }
		timestamp = if type(tbl.Timestamp) == "number"
			then tbl.Timestamp
			elseif type(tbl.timestamp) == "number" then tbl.timestamp
			else Workspace:GetServerTimeNow()

		origin = if typeof(tbl.Origin) == "Vector3"
			then tbl.Origin
			elseif typeof(tbl.origin) == "Vector3" then tbl.origin
			else Vector3.zero

		local dir = tbl.Direction or tbl.direction or tbl.LookVector or tbl.lookVector
		if typeof(dir) == "Vector3" then
			pitch, yaw = ShotPacket.DirectionToPitchYaw(dir)
		else
			pitch = tonumber(tbl.Pitch or tbl.pitch) or 0
			yaw = tonumber(tbl.Yaw or tbl.yaw) or 0
		end
	elseif typeof(a) == "Vector3" then
		-- Overload: (origin: Vector3, direction: Vector3, timestamp: number?, weaponId: number?)
		origin = a
		if typeof(b) == "Vector3" then
			pitch, yaw = ShotPacket.DirectionToPitchYaw(b)
		else
			pitch = if type(b) == "number" then b else 0
			yaw = if type(c) == "number" then c else 0
		end
		timestamp = if type(c) == "number" then c else Workspace:GetServerTimeNow()
	else
		-- Standard: (timestamp: number, origin: Vector3, pitch: number, yaw: number)
		timestamp = if type(a) == "number" then a else Workspace:GetServerTimeNow()
		origin = if typeof(b) == "Vector3" then b else Vector3.zero
		if typeof(c) == "Vector3" then
			pitch, yaw = ShotPacket.DirectionToPitchYaw(c)
		else
			pitch = if type(c) == "number" then c else 0
			yaw = if type(d) == "number" then d else 0
		end
	end

	pitch = math.clamp(pitch, -HALF_PI, HALF_PI)

	local buf = buffer.create(PACKET_SIZE)
	buffer.writef64(buf, 0, timestamp)
	buffer.writef32(buf, 8, origin.X)
	buffer.writef32(buf, 12, origin.Y)
	buffer.writef32(buf, 16, origin.Z)
	buffer.writef32(buf, 20, pitch)
	buffer.writef32(buf, 24, yaw)

	return buf
end

function ShotPacket.Decode(buf: buffer): (boolean, number, Vector3, Vector3)
	if typeof(buf) ~= "buffer" or buffer.len(buf) ~= PACKET_SIZE then
		return false, 0, Vector3.zero, -Vector3.zAxis
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
		return false, 0, Vector3.zero, -Vector3.zAxis
	end

	local clampedPitch = math.clamp(pitch, -HALF_PI, HALF_PI)
	local origin = Vector3.new(ox, oy, oz)

	local cosPitch = math.cos(clampedPitch)
	local lookDir = Vector3.new(
		-math.sin(yaw) * cosPitch,
		math.sin(clampedPitch),
		-math.cos(yaw) * cosPitch
	)

	local lookVector = if lookDir.Magnitude > 1e-6 then lookDir.Unit else -Vector3.zAxis
	return true, timestamp, origin, lookVector
end

function ShotPacket.DecodeTable(buf: buffer): DecodedShotPacket?
	local isValid, timestamp, origin, lookVector = ShotPacket.Decode(buf)
	if not isValid then
		return nil
	end

	local rawPitch = math.clamp(buffer.readf32(buf, 20), -HALF_PI, HALF_PI)
	local rawYaw = buffer.readf32(buf, 24)

	return {
		Timestamp = timestamp,
		Origin = origin,
		Direction = lookVector,
		Pitch = rawPitch,
		Yaw = rawYaw,
	}
end

return table.freeze(ShotPacket)
