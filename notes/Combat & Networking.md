---
tags: [system, combat, networking]
---
# Combat & Networking
Code: `src/client/combat/WeaponController.luau`, `src/shared/network/ShotPacket.luau`, `src/server/combat/{CombatValidator,HitboxHistory}.luau`.

## 28-byte shot packet (`buffer`)
| Offset | Type | Field |
|---|---|---|
| 00–07 | f64 | client timestamp (`workspace:GetServerTimeNow()`) |
| 08–19 | f32 ×3 | ray origin |
| 20–27 | f32 ×2 | pitch, yaw (radians) |

## Server validation pipeline
1. `typeof(packet) == "buffer"` and `buffer.len == 28`
2. Fire-rate check: `(60 / RPM) * 0.88`
3. Origin within 14 studs of shooter head
4. Clamp rewind time to `[serverNow - 0.45, serverNow]`
5. Rewind enemy parts from the 60 Hz ring buffer → `workspace:Raycast()` → restore CFrames → apply damage

Other: `TracerPool` (50 pre-allocated beams, zero GC), `VFXController`, `StanceReplicator` (UnreliableRemoteEvent buffer for 3P pitch/slide), economy hooks (kill bounties, armor) → [[Economy]].

Related: [[Movement]], [[Rules & Guardrails]]
