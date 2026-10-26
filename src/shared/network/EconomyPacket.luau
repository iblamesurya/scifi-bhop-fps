--!strict
-- src/shared/network/EconomyPacket.luau
-- Pillar 4: Binary buffer serializer/deserializer for Economy networking.
-- Obeys Rule 2.5: NEVER send tables or strings over RemoteEvents; uses raw Luau buffers.

export type PurchaseRequestData = {
	ActionType: number, -- u8 (Offset 00)
	ItemId: number, -- u8 (Offset 01)
	SequenceId: number, -- u16 (Offset 02..03)
}

export type EconomyStateData = {
	MatchCredits: number, -- u16 (Offset 00..01)
	LossStreak: number, -- u8 (Offset 02)
	ArmorPoints: number, -- u8 (Offset 03)
	ArmorTier: number, -- u8 (Offset 04)
	PrimaryWeaponId: number, -- u8 (Offset 05)
	SecondaryWeaponId: number, -- u8 (Offset 06)
	UtilityBitmask: number, -- u8 (Offset 07)
	ReasonCode: number, -- u8 (Offset 08)
	CreditDelta: number, -- i16 (Offset 09..10)
	BuyPhaseOpen: boolean, -- u8 (Offset 11: 1 or 0)
	AccountFlux: number, -- u32 (Offset 12..15)
}

local REQUEST_PACKET_SIZE = 4
local STATE_PACKET_SIZE = 16

local EconomyPacket = {
	RequestPacketSize = REQUEST_PACKET_SIZE,
	StatePacketSize = STATE_PACKET_SIZE,
}

-- Encodes a 4-byte Client -> Server purchase/action packet
function EconomyPacket.encodePurchaseRequest(
	actionType: number,
	itemId: number,
	sequenceId: number
): buffer
	local buf = buffer.create(REQUEST_PACKET_SIZE)
	buffer.writeu8(buf, 0, math.clamp(actionType, 0, 255))
	buffer.writeu8(buf, 1, math.clamp(itemId, 0, 255))
	buffer.writeu16(buf, 2, math.clamp(sequenceId, 0, 65535))
	return buf
end

-- Decodes and validates a 4-byte Client -> Server purchase/action packet
function EconomyPacket.decodePurchaseRequest(packet: unknown): PurchaseRequestData?
	if typeof(packet) ~= "buffer" then
		return nil
	end
	local buf = packet :: buffer
	if buffer.len(buf) ~= REQUEST_PACKET_SIZE then
		return nil
	end

	return {
		ActionType = buffer.readu8(buf, 0),
		ItemId = buffer.readu8(buf, 1),
		SequenceId = buffer.readu16(buf, 2),
	}
end

-- Encodes a 16-byte Server -> Client economy state packet
function EconomyPacket.encodeEconomyState(state: EconomyStateData): buffer
	local buf = buffer.create(STATE_PACKET_SIZE)
	buffer.writeu16(buf, 0, math.clamp( math.floor(state.MatchCredits), 0, 65535 ))
	buffer.writeu8(buf, 2, math.clamp(math.floor(state.LossStreak), 0, 255))
	buffer.writeu8(buf, 3, math.clamp(math.floor(state.ArmorPoints), 0, 255))
	buffer.writeu8(buf, 4, math.clamp(math.floor(state.ArmorTier), 0, 255))
	buffer.writeu8(buf, 5, math.clamp(math.floor(state.PrimaryWeaponId), 0, 255))
	buffer.writeu8(buf, 6, math.clamp(math.floor(state.SecondaryWeaponId), 0, 255))
	buffer.writeu8(buf, 7, math.clamp(math.floor(state.UtilityBitmask), 0, 255))
	buffer.writeu8(buf, 8, math.clamp(math.floor(state.ReasonCode), 0, 255))
	buffer.writei16(buf, 9, math.clamp(math.floor(state.CreditDelta), -32768, 32767))
	buffer.writeu8(buf, 11, if state.BuyPhaseOpen then 1 else 0)
	buffer.writeu32(buf, 12, math.clamp(math.floor(state.AccountFlux), 0, 4294967295))
	return buf
end

-- Decodes and validates a 16-byte Server -> Client economy state packet
function EconomyPacket.decodeEconomyState(packet: unknown): EconomyStateData?
	if typeof(packet) ~= "buffer" then
		return nil
	end
	local buf = packet :: buffer
	if buffer.len(buf) ~= STATE_PACKET_SIZE then
		return nil
	end

	return {
		MatchCredits = buffer.readu16(buf, 0),
		LossStreak = buffer.readu8(buf, 2),
		ArmorPoints = buffer.readu8(buf, 3),
		ArmorTier = buffer.readu8(buf, 4),
		PrimaryWeaponId = buffer.readu8(buf, 5),
		SecondaryWeaponId = buffer.readu8(buf, 6),
		UtilityBitmask = buffer.readu8(buf, 7),
		ReasonCode = buffer.readu8(buf, 8),
		CreditDelta = buffer.readi16(buf, 9),
		BuyPhaseOpen = buffer.readu8(buf, 11) == 1,
		AccountFlux = buffer.readu32(buf, 12),
	}
end

return table.freeze(EconomyPacket)
