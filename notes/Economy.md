---
tags: [system, economy]
---
# Economy
Code: `src/server/economy/EconomyManager.luau`, `src/shared/configs/EconomyConfig.luau`, `src/shared/network/EconomyPacket.luau` (16-byte buffer state sync), `src/client/combat/EconomyClient.luau`.

- Authoritative server ledger per player: `MatchCredits`, `LossStreak`, `ArmorPoints/Tier`, primary/secondary weapon ids, `UtilityBitmask`, `BuyPhaseOpen`, `RoundPurchases` (full buy-phase refund), `DamageLedger` (assists), anti-spam `LastRequestTime` / `LastSequenceId`.
- Persistence: DataStore `SciFiBhopFPS_Economy_v1`, autosave every 120 s; Studio sessions without publish degrade gracefully.
- Default secondary: id 1 (K-14 Pulse Pistol).
- Velocity-scaled bhop kill bounties and Exo-Shield absorption integrate with `CombatValidator` ([[Combat & Networking]]).

Related: [[Lobby & Match Flow]] (lobby subtitle shows economy state)
